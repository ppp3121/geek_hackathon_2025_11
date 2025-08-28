from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Any, Optional
import os

from dict_matcher import match_query_or_none
from dictionary import KEYWORD_TO_TAGS
from embeddings import (
    load_label_texts,
    build_label_embeddings,
    classify,
    MODEL_NAME as DEFAULT_SENTENCE_MODEL,
)
from sentence_transformers import SentenceTransformer  # ←残す場合も embeddings.py の MODEL_NAME を使う


app = FastAPI(title="OSM Tagging API")

# Embeddings classifier cache
_EMB_MODEL: Optional[SentenceTransformer] = None
_EMB_LABEL_EMBS = None  # Dict[str, torch.Tensor] だが torch を直接参照せず保持のみ
_EMB_DATA_PATH: Optional[str] = None
_EMB_MODEL_NAME: Optional[str] = None

class AnalyzeReq(BaseModel):
    query: str

def _load_embeddings():
    global _EMB_MODEL, _EMB_LABEL_EMBS, _EMB_DATA_PATH, _EMB_MODEL_NAME
    if _EMB_MODEL is not None and _EMB_LABEL_EMBS is not None:
        return _EMB_MODEL, _EMB_LABEL_EMBS

    data_path = os.environ.get("EMBED_DATA_PATH") or "augmented_training_data.jsonl"
    model_name = DEFAULT_SENTENCE_MODEL   # ← 環境変数を無視して常に embeddings.py のモデルを使う

    if not os.path.isabs(data_path):
        base_dir = os.path.dirname(__file__)
        data_path = os.path.join(base_dir, data_path)

    try:
        import torch
        device = "cuda" if torch.cuda.is_available() else "cpu"
        model = SentenceTransformer(model_name, device=device)   # ← ここで embeddings.py の MODEL_NAME を利用
        label_texts = load_label_texts(data_path)
        label_embs = build_label_embeddings(model, label_texts)
        _EMB_MODEL = model
        _EMB_LABEL_EMBS = label_embs
        _EMB_DATA_PATH = data_path
        _EMB_MODEL_NAME = model_name
        return _EMB_MODEL, _EMB_LABEL_EMBS
    except Exception as e:
        print("[EMB] load failed:", e)
        _EMB_MODEL = None
        _EMB_LABEL_EMBS = None
        return None, None



def _cuda_available() -> bool:
    try:
        import torch
        return torch.cuda.is_available()
    except Exception:
        return False

@app.get("/api/v1/status")
def status():
    loaded = _EMB_MODEL is not None and _EMB_LABEL_EMBS is not None
    return {
        "embeddings_loaded": loaded,
        "model_name": _EMB_MODEL_NAME,
        "data_path": _EMB_DATA_PATH,
        "dict_entries": len(KEYWORD_TO_TAGS),
    }


@app.post("/api/v1/reload-embeddings")
def reload_embeddings():
    global _EMB_MODEL, _EMB_LABEL_EMBS
    _EMB_MODEL = None
    _EMB_LABEL_EMBS = None
    model, label_embs = _load_embeddings()
    if model is None or label_embs is None:
        return JSONResponse(status_code=500, content={"error": {"code": 500, "message": "埋め込みモデルの再読み込みに失敗しました。"}})
    return {"embeddings_loaded": True, "model_name": _EMB_MODEL_NAME, "data_path": _EMB_DATA_PATH}

@app.post("/api/v1/analyze-keywords")
async def analyze(req: AnalyzeReq): # ◆修正点1: (request: Request) から (req: AnalyzeReq) に戻す
    """キーワードを解析して、検索クエリとカテゴリを返す"""
    # body = await request.json() # この行は不要になる
    print("--- 受信したリクエストボディ ---")
    print(req)
    query = req.query # ◆修正点2: body.get("query") から req.query に変更

    if not query:
        return JSONResponse(status_code=400, content={"error":{"code":400,"message":"解析不能なキーワードです。"}})

    # 1) 辞書優先 (top_k=2 に固定)
    hit = match_query_or_none(query, top_k=2)
    if hit:
        return {"searchTerms": hit}

    # 2) Embeddings 分類器
    model, label_embs = _load_embeddings()
    if model is None or label_embs is None:
        return JSONResponse(status_code=400, content={"error":{"code":400,"message":"解析不能なキーワードです。"}})

    try:
        # 類似度上位2件を取得
        preds = classify(model, label_embs, query, topk=2)
        for raw_label, score in preds:
            for term in (raw_label,):
                hit2 = match_query_or_none(term, top_k=2)
                if hit2:
                    return {"searchTerms": hit2, "predicted_label": raw_label, "matched_term": term, "score": score}
    except Exception as e:
        print("[EMB] inference failed:", e)

    return JSONResponse(status_code=400, content={"error":{"code":400,"message":"解析不能なキーワードです。"}})