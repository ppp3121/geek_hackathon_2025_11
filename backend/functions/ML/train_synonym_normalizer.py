"""Neutralized: training script moved to backend/functions/tools/train/train_synonym_normalizer.py

This placeholder keeps the importable API but avoids carrying training code in the
runtime directory.
"""

from pathlib import Path

DATA_PATH = Path("../data/synonym_training.jsonl")
OUT_MODEL = Path("synonym_normalizer.joblib")

def train_and_save(*a, **k):
    raise RuntimeError("Training moved to backend/functions/tools/train. Use that script.")
