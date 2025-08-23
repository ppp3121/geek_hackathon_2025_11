#!/usr/bin/env python3
"""同義語正規化ユーティリティ (moved to ML package)"""
from pathlib import Path
import json
import random
from typing import Dict, List, Optional

import joblib

# Minimal synonym map: canonical -> list of synonyms/abbrevs
SYNONYM_MAP: Dict[str, List[str]] = {
    "ラーメン": ["らーめん", "ramen", "ラーメン屋", "ラーメン店"],
    "カフェ": ["喫茶店", "コーヒー店", "コーヒーショップ", "カフェ"],
    "コンビニ": ["コンビニエンスストア", "コンビニ", "コンビニ店"],
    "ATM": ["atm", "現金自動預払機", "ＡＴＭ"],
    "ホテル": ["旅館", "ホテル", "ホステル"],
    "病院": ["クリニック", "病院", "医院"],
    "パン屋": ["ベーカリー", "パン屋", "パン店"],
}

AUG_SUFFIXES = ["の近く", "近くの", "がある", "を探している", "の場所"]


def generate_synonym_dataset(
    out_path: Path = Path("synonym_training.jsonl"),
    n_per_canonical: int = 20,
    seed: int = 42,
):
    random.seed(seed)
    out = []
    for canonical, syns in SYNONYM_MAP.items():
        variants = []
        for s in syns:
            variants.append(s)
            for suf in AUG_SUFFIXES:
                variants.append(s + suf)

        seen = set()
        uniq = []
        for v in variants:
            if v not in seen:
                seen.add(v)
                uniq.append(v)

        i = 0
        max_attempts = max(1000, n_per_canonical * 10)
        attempts = 0
        while len(uniq) < n_per_canonical and attempts < max_attempts:
            base = syns[i % len(syns)]
            suf = AUG_SUFFIXES[i % len(AUG_SUFFIXES)] if AUG_SUFFIXES else ""
            cand = base + suf
            if cand not in seen:
                seen.add(cand)
                uniq.append(cand)
            i += 1
            attempts += 1

        if len(uniq) < n_per_canonical:
            j = 0
            while len(uniq) < n_per_canonical:
                uniq.append(uniq[j % len(uniq)])
                j += 1

        for v in uniq[:n_per_canonical]:
            out.append({"text": v, "label": canonical})

    out_path = Path(out_path)
    with out_path.open("w", encoding="utf-8") as f:
        for ex in out:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")
    return len(out)


MODEL_FILENAME = Path(__file__).with_name("synonym_normalizer.joblib")
DEFAULT_MIN_CONFIDENCE: Optional[float] = None


def _dict_match(text: str) -> Optional[str]:
    if not text:
        return None
    t = text.strip().lower()
    for canonical, syns in SYNONYM_MAP.items():
        if t == canonical.lower():
            return canonical
        for s in syns:
            if t == s.lower():
                return canonical
    for canonical in SYNONYM_MAP:
        if canonical in text:
            return canonical
    return None


class _LazyModel:
    def __init__(self, path: Path):
        self.path = path
        self._model = None

    def load(self):
        if self._model is None:
            try:
                self._model = joblib.load(self.path)
            except Exception:
                self._model = None
        return self._model


_MODEL = _LazyModel(MODEL_FILENAME)


def normalize_query(
    text: str, min_confidence: Optional[float] = DEFAULT_MIN_CONFIDENCE
) -> Optional[str]:
    if not text:
        return None
    d = _dict_match(text)
    if d:
        return d

    model = _MODEL.load()
    if model is None:
        return None
    try:
        if min_confidence is not None and hasattr(model, "predict_proba"):
            probs = model.predict_proba([text])
            probs0 = list(probs[0])
            max_idx = int(max(range(len(probs0)), key=lambda i: probs0[i]))
            max_prob = float(probs0[max_idx])
            pred = model.classes_[max_idx]
            if max_prob >= min_confidence:
                return pred
            else:
                return None
        else:
            pred = model.predict([text])
            if len(pred) > 0:
                return pred[0]
    except Exception:
        return None
    return None


def demo():
    examples = [
        "らーめん",
        "ラーメン屋の近く",
        "喫茶店",
        "ベーカリー",
        "atm",
        "知らない語",
    ]
    print("=== default (no min_confidence) ===")
    for e in examples:
        print(f"{e} -> {normalize_query(e)}")
    print("=== with min_confidence=0.6 (probability threshold) ===")
    for e in examples:
        print(f"{e} -> {normalize_query(e, min_confidence=0.6)}")


if __name__ == "__main__":
    demo()
