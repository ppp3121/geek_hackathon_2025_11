from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, Any, List
import os

# 変更点: 相対インポートに
from .dict_matcher import match_query_or_none

app = FastAPI(title="OSM Tagging API with HF model")

# HF: 遅延ロード用キャッシュ
_HF_PIPE = None
_HF_REPO = None
_HF_ID2LABEL = None  # int -> str
_HF_LABEL_MAP = {}   # "LABEL_0" -> "正規名" など

class AnalyzeReq(BaseModel):
    query: str
    top_k: Optional[int] = 3

def _load_hf_pipeline():
    global _HF_PIPE, _HF_REPO, _HF_ID2LABEL, _HF_LABEL_MAP
    if _HF_PIPE is not None:
        return _HF_PIPE
    repo = os.environ.get("MODEL_HF_REPO", "uniuni23/my-text-classifier")
    token = os.environ.get("HF_TOKEN")  # private repo の場合のみ必要

    try:
        from transformers import AutoTokenizer, AutoModelForSequenceClassification, AutoConfig, pipeline
        cfg = AutoConfig.from_pretrained(repo, token=token, trust_remote_code=False)
        tok = AutoTokenizer.from_pretrained(repo, token=token, trust_remote_code=False)
        mdl = AutoModelForSequenceClassification.from_pretrained(repo, token=token, trust_remote_code=False)
        _HF_PIPE = pipeline("text-classification", model=mdl, tokenizer=tok, device=-1)
        _HF_REPO = repo
        # id2label を "LABEL_i" へも張る
        _HF_ID2LABEL = getattr(cfg, "id2label", None)
        _HF_LABEL_MAP = {}
        if isinstance(_HF_ID2LABEL, dict):
            for i, name in _HF_ID2LABEL.items():
                _HF_LABEL_MAP[f"LABEL_{i}"] = name
        return _HF_PIPE
    except Exception as e:
        print(f"[HF] load failed: {e}")
        _HF_PIPE = None
        return None

@app.get("/api/v1/status")
def status():
    repo = _HF_REPO or os.environ.get("MODEL_HF_REPO", "uniuni23/my-text-classifier")
    return {"hf_repo": repo, "hf_loaded": _HF_PIPE is not None}

@app.post("/api/v1/analyze-keywords")
def analyze(req: AnalyzeReq):
    q = (req.query or "").strip()
    if not q:
        return JSONResponse(status_code=400, content={"error": {"code": 400, "message": "解析不能なキーワードです。"}})

    # 1) 辞書優先
    hit = match_query_or_none(q, top_k=2)
    if hit:
        return {"searchTerms": hit}

    # 2) HF（正規化器の代替）
    pipe = _load_hf_pipeline()
    if pipe is None:
        return JSONResponse(status_code=500, content={"error": {"code": 500, "message": "HFモデルのロードに失敗しました。"}})

    try:
        preds: Any = pipe(q, top_k=max(1, req.top_k or 3))
        if isinstance(preds, dict):
            preds = [preds]

        # 予測ラベル候補を順に辞書照合
        for p in preds:
            raw_label = p.get("label") if isinstance(p, dict) else str(p)
            score = p.get("score") if isinstance(p, dict) else None
            if not raw_label:
                continue
            candidates: List[str] = [raw_label]

            # LABEL_i → 正規名（id2label）に変換
            mapped = _HF_LABEL_MAP.get(raw_label)
            if mapped and mapped not in candidates:
                candidates.append(mapped)

            # よくある表記ゆれ対策（小文字化・空白除去）
            candidates.extend({raw_label.lower().strip(), (mapped or "").lower().strip()})

            # 重複排除
            candidates = [c for c in dict.fromkeys([c for c in candidates if c])]

            for term in candidates:
                hit2 = match_query_or_none(term, top_k=2)
                if hit2:
                    return {"searchTerms": hit2, "predicted_label": raw_label, "score": score, "matched_term": term}

        # デバッグ用に予測だけ返したい場合（本番は 400 のまま）
        if os.environ.get("DEBUG_HF") == "1":
            return JSONResponse(status_code=400, content={"error": {"code": 400, "message": "辞書未ヒット"}, "predictions": preds})
    except Exception as e:
        print(f"[HF] inference failed: {e}")
        return JSONResponse(status_code=500, content={"error": {"code": 500, "message": "HFモデル推論に失敗しました。"}})

    return JSONResponse(status_code=400, content={"error": {"code": 400, "message": "解析不能なキーワードです。"}})

