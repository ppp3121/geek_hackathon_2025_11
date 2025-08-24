from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, Any
import os

from .dict_matcher import match_query_or_none
from .dictionary import KEYWORD_TO_TAGS

app = FastAPI(title="OSM Tagging API")

# HF fallback cache
_HF_PIPE = None
_HF_LABEL_MAP = {}
_HF_REPO = None

class AnalyzeReq(BaseModel):
    query: str


def _load_hf():
    global _HF_PIPE, _HF_LABEL_MAP, _HF_REPO
    if _HF_PIPE is not None:
        return _HF_PIPE
    repo = os.environ.get("MODEL_HF_REPO", "uniuni23/my-text-classifier")
    token = os.environ.get("HF_TOKEN")
    try:
        from transformers import AutoConfig, AutoTokenizer, AutoModelForSequenceClassification, pipeline
        cfg = AutoConfig.from_pretrained(repo, token=token, trust_remote_code=False)
        tok = AutoTokenizer.from_pretrained(repo, token=token, trust_remote_code=False)
        mdl = AutoModelForSequenceClassification.from_pretrained(repo, token=token, trust_remote_code=False)
        _HF_PIPE = pipeline("text-classification", model=mdl, tokenizer=tok, device=-1)
        _HF_REPO = repo
        _HF_LABEL_MAP = {}
        id2label = getattr(cfg, "id2label", None)
        if isinstance(id2label, dict):
            for k, v in id2label.items():
                _HF_LABEL_MAP[f"LABEL_{k}"] = v
        return _HF_PIPE
    except Exception as e:
        print("[HF] load failed:", e)
        _HF_PIPE = None
        return None

@app.get("/api/v1/status")
def status():
    return {"hf_loaded": _HF_PIPE is not None, "hf_repo": _HF_REPO, "dict_entries": len(KEYWORD_TO_TAGS)}

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

    # 2) HF（正規化器の代替）
    pipe = _load_hf()
    if pipe is None:
        return JSONResponse(status_code=400, content={"error":{"code":400,"message":"解析不能なキーワードです。"}})

    try:
        # ◆ 修正点: 'q' を 'query' に修正し、top_k=2 を直接指定
        preds: Any = pipe(query, top_k=2)
        if isinstance(preds, dict):
            preds = [preds]
        for p in preds:
            raw = p.get("label") if isinstance(p, dict) else str(p)
            mapped = _HF_LABEL_MAP.get(raw) or raw
            for term in (mapped, raw):
                # ◆ 修正点: top_k=2 を直接指定
                hit2 = match_query_or_none(term, top_k=2)
                if hit2:
                    return {"searchTerms": hit2, "predicted_label": raw, "matched_term": term, "score": p.get("score")}
    except Exception as e:
        print("[HF] inference failed:", e)

    return JSONResponse(status_code=400, content={"error":{"code":400,"message":"解析不能なキーワードです。"}})