from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, List, Tuple
import os
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification

from dict_matcher import match_query_or_none
from dictionary import KEYWORD_TO_TAGS
from query_normalizer import extract_query_entities, normalize_text


app = FastAPI(title="OSM Tagging API")

# Transformer classifier cache
_TR_MODEL = None
_TR_TOKENIZER = None
_TR_MODEL_DIR: Optional[str] = None
_TR_DEVICE: Optional[str] = None

class AnalyzeReq(BaseModel):
    query: str

def _load_transformer():
    global _TR_MODEL, _TR_TOKENIZER, _TR_MODEL_DIR, _TR_DEVICE
    if _TR_MODEL is not None and _TR_TOKENIZER is not None:
        return _TR_MODEL, _TR_TOKENIZER

    model_dir = os.environ.get("TRANSFORMER_MODEL_DIR") or "transformer_model_ft"
    if not os.path.isabs(model_dir):
        base_dir = os.path.dirname(__file__)
        model_dir = os.path.join(base_dir, model_dir)

    try:
        device = "cuda" if torch.cuda.is_available() else "cpu"
        tokenizer = AutoTokenizer.from_pretrained(model_dir, use_fast=True)
        model = AutoModelForSequenceClassification.from_pretrained(model_dir)
        model.to(device)
        model.eval()

        _TR_TOKENIZER = tokenizer
        _TR_MODEL = model
        _TR_MODEL_DIR = model_dir
        _TR_DEVICE = device
        return _TR_MODEL, _TR_TOKENIZER
    except Exception as e:
        print("[TR] load failed:", e)
        _TR_MODEL = None
        _TR_TOKENIZER = None
        return None, None



def _cuda_available() -> bool:
    try:
        return torch.cuda.is_available()
    except Exception:
        return False


def _preprocess_query_for_transformer(query: str) -> str:
    ent = extract_query_entities(query)
    return ent.category_query or ent.normalized_query or normalize_text(query)


def _predict_labels(query: str, top_k: int = 2) -> List[Tuple[str, float]]:
    model, tokenizer = _load_transformer()
    if model is None or tokenizer is None:
        return []

    text = _preprocess_query_for_transformer(query)
    if not text:
        return []

    device = _TR_DEVICE or ("cuda" if torch.cuda.is_available() else "cpu")
    with torch.no_grad():
        encoded = tokenizer(text, truncation=True, padding=True, max_length=128, return_tensors="pt")
        encoded = {k: v.to(device) for k, v in encoded.items()}
        logits = model(**encoded).logits
        probs = torch.softmax(logits, dim=-1).squeeze(0)

        k = min(max(1, top_k), probs.shape[-1])
        values, indices = torch.topk(probs, k=k)

        id2label = getattr(model.config, "id2label", {}) or {}
        out: List[Tuple[str, float]] = []
        for score, idx in zip(values.tolist(), indices.tolist()):
            label = id2label.get(idx)
            if label is None:
                label = id2label.get(str(idx), str(idx))
            out.append((str(label), float(score)))
        return out


def _filter_top_predictions(preds: List[Tuple[str, float]]) -> List[Tuple[str, float]]:
    """Top-k予測を運用向けに間引く。

    環境変数:
    - TRANSFORMER_MIN_CONF: 候補全体の最小確信度（既存）
        - TRANSFORMER_SECOND_MIN_CONF: 2位候補の絶対閾値（default=0.20）
        - TRANSFORMER_SECOND_REL_MIN: 2位候補の相対閾値（1位比, default=0.70）
      例: 0.7 なら「2位 >= 1位 * 0.7」を満たす場合だけ2位を残す
    """
    if not preds:
        return []

    min_conf = float(os.environ.get("TRANSFORMER_MIN_CONF", "0.30"))
    second_min_conf = float(os.environ.get("TRANSFORMER_SECOND_MIN_CONF", "0.20"))
    second_rel_min = float(os.environ.get("TRANSFORMER_SECOND_REL_MIN", "0.70"))

    filtered = [(label, score) for label, score in preds if score >= min_conf]
    if len(filtered) <= 1:
        return filtered

    first_label, first_score = filtered[0]
    second_label, second_score = filtered[1]

    keep_second_abs = second_score >= second_min_conf
    keep_second_rel = second_score >= (first_score * second_rel_min)

    if keep_second_abs and keep_second_rel:
        return [
            (first_label, first_score),
            (second_label, second_score),
        ]
    return [(first_label, first_score)]

@app.get("/api/v1/status")
def status():
    loaded = _TR_MODEL is not None and _TR_TOKENIZER is not None
    return {
        "transformer_loaded": loaded,
        "transformer_model_dir": _TR_MODEL_DIR,
        "transformer_device": _TR_DEVICE,
        "cuda_available": _cuda_available(),
        "min_conf": float(os.environ.get("TRANSFORMER_MIN_CONF", "0.30")),
        "second_min_conf": float(os.environ.get("TRANSFORMER_SECOND_MIN_CONF", "0.20")),
        "second_rel_min": float(os.environ.get("TRANSFORMER_SECOND_REL_MIN", "0.70")),
        "dict_entries": len(KEYWORD_TO_TAGS),
    }


@app.post("/api/v1/reload-transformer")
def reload_transformer():
    global _TR_MODEL, _TR_TOKENIZER
    _TR_MODEL = None
    _TR_TOKENIZER = None
    model, tokenizer = _load_transformer()
    if model is None or tokenizer is None:
        return JSONResponse(status_code=500, content={"error": {"code": 500, "message": "Transformerモデルの再読み込みに失敗しました。"}})
    return {
        "transformer_loaded": True,
        "transformer_model_dir": _TR_MODEL_DIR,
        "transformer_device": _TR_DEVICE,
    }


# backward compatibility
@app.post("/api/v1/reload-embeddings")
def reload_embeddings_compat():
    return reload_transformer()

@app.post("/api/v1/analyze-keywords")
async def analyze(req: AnalyzeReq):
    """キーワードを解析して、検索クエリとカテゴリを返す"""
    print("--- 受信したリクエストボディ ---")
    print(req)
    query = req.query

    if not query:
        return JSONResponse(status_code=400, content={"error":{"code":400,"message":"解析不能なキーワードです。"}})

    # 1) 辞書優先 (top_k=2 に固定)
    hit = match_query_or_none(query, top_k=2)
    if hit:
        return {"searchTerms": hit}

    # 2) Transformer 分類器
    preds = _predict_labels(query, top_k=2)
    preds = _filter_top_predictions(preds)
    if not preds:
        return JSONResponse(status_code=400, content={"error":{"code":400,"message":"解析不能なキーワードです。"}})

    try:
        for raw_label, score in preds:
            for term in (raw_label,):
                hit2 = match_query_or_none(term, top_k=2)
                if hit2:
                    return {
                        "searchTerms": hit2,
                        "predicted_label": raw_label,
                        "matched_term": term,
                        "score": score,
                        "model_type": "transformer",
                    }
    except Exception as e:
        print("[TR] inference failed:", e)

    return JSONResponse(status_code=400, content={"error":{"code":400,"message":"解析不能なキーワードです。"}})