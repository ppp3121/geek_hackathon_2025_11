from fastapi import FastAPI, BackgroundTasks, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional
from pathlib import Path
import threading
import os
import joblib
from google.cloud import storage
from dict_matcher import match_query_or_none
from train_synonym_normalizer import OUT_MODEL
from synonym_normalizer import normalize_query

app = FastAPI(title="OSM Tagging ML API (MVP)")

# State: only keep normalizer model (joblib)
STATE = {
    "normalizer": None,
}


class Query(BaseModel):
    query: str
    top_k: Optional[int] = 3


class ReloadReq(BaseModel):
    model_dir: Optional[str] = None
    data_path: Optional[str] = None


class TrainReq(BaseModel):
    model_dir: Optional[str] = None
    data_path: Optional[str] = None
    max_count: int = 20
    epochs: int = 3


def load_pipeline(model_dir: Optional[str] = None):
    # Transformer pipeline はこの API のフローから外したため未実装
    raise NotImplementedError("Transformer pipeline removed from this API")

@app.on_event("startup")
def startup():
    # 同義語正規化モデル（joblib）をロードしておく（あれば）。
    # 環境変数 MODEL_GCS_URI が設定されていれば GCS からダウンロードしてからロードする。
    def download_model_from_gcs(gcs_uri: str, dest_path: str):
        if not gcs_uri.startswith("gs://"):
            raise ValueError("MODEL_GCS_URI must be a gs:// URI")
        rest = gcs_uri[len("gs://"):]
        parts = rest.split('/', 1)
        bucket_name = parts[0]
        blob_path = parts[1] if len(parts) > 1 else ''
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_path)
        blob.download_to_filename(dest_path)

    try:
        model_gcs = os.environ.get('MODEL_GCS_URI')
        model_path_env = os.environ.get('MODEL_PATH')
        target = Path(model_path_env) if model_path_env else OUT_MODEL

        if model_gcs:
            try:
                print("Downloading model from", model_gcs, "to", target)
                download_model_from_gcs(model_gcs, str(target))
            except Exception as e:
                print("Failed to download model from GCS:", e)

        if target.exists():
            # keep previous behavior of loading a joblib model into STATE for backward compatibility
            try:
                STATE["normalizer"] = joblib.load(target)
                print("Loaded normalizer model from", target)
            except Exception as e:
                print("Failed to load normalizer model from", target, e)
                STATE["normalizer"] = None
        else:
            STATE["normalizer"] = None
    except Exception as e:
        print("Failed to load normalizer model:", e)
        STATE["normalizer"] = None


@app.get("/api/v1/status")
def status():
    """ステータス。normalizer がロードされているかを返す。
    """
    return {"normalizer_loaded": STATE.get("normalizer") is not None}


@app.post("/api/v1/analyze-keywords")
def analyze(req: Query):
    """
    辞書優先 → 同義語正規化器（normalizer）で正規化 → 正規形で辞書検索
    どれもヒットしなければ ML_SPEC.md に合わせて 400 を返す
    """
    q = (req.query or "").strip()
    if not q:
        return JSONResponse(status_code=400, content={"error": {"code": 400, "message": "解析不能なキーワードです。"}})

    # 1) 辞書優先
    dict_res = match_query_or_none(q.query, top_k=2)
    if dict_res:
        return {"searchTerms": dict_res}

    # 2) 同義語正規化モジュールを使う（辞書優先のあと）
    # optional min_confidence can be set by env var MIN_CONFIDENCE
    min_conf = os.environ.get("MIN_CONFIDENCE")
    min_conf_val = float(min_conf) if min_conf is not None else None
    try:
        normalized = normalize_query(q.query, min_confidence=min_conf_val)
    except Exception:
        normalized = None

    if normalized:
        dict_res2 = match_query_or_none(normalized, top_k=2)
        if dict_res2:
            return {"searchTerms": dict_res2}

    # 3) どれもヒットしなかった -> ML_SPEC.md に合わせて 400 を返す
    return JSONResponse(status_code=400, content={"error": {"code": 400, "message": "解析不能なキーワードです。"}})


@app.post("/api/v1/reload")
def reload(req: ReloadReq):
    # reload は同義語正規化モデルをロードする。data_path が指定されれば学習も試みる。
    try:
        if req.data_path:
            # attempt to train normalizer from provided data
            from train_synonym_normalizer import train_and_save
            out = train_and_save(Path(req.data_path), out_model=Path("synonym_normalizer.joblib"))
            STATE["normalizer"] = joblib.load(out)
            return {"status": "trained", "out": str(out)}

        # otherwise try to load existing normalizer
        if OUT_MODEL.exists():
            STATE["normalizer"] = joblib.load(OUT_MODEL)
            return {"status": "loaded", "out": str(OUT_MODEL)}

        return {"status": "no_model"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/train")
def train(req: TrainReq, background_tasks: BackgroundTasks):
    # Train endpoint retrains the synonym normalizer only (background)
    data_path = req.data_path or "synonym_training.jsonl"

    def run_training():
        try:
            from synonym_normalizer import generate_synonym_dataset
            from train_synonym_normalizer import train_and_save

            dp = Path(data_path)
            if not dp.exists():
                generate_synonym_dataset(dp, n_per_canonical=30)

            out = train_and_save(dp, out_model=Path("synonym_normalizer.joblib"))
            try:
                STATE["normalizer"] = joblib.load(out)
            except Exception as e:
                print("Failed to load trained normalizer:", e)
        except Exception as e:
            print("Training (normalizer) failed:", e)

    background_tasks.add_task(run_training)
    return {"status": "started", "data_path": data_path}

