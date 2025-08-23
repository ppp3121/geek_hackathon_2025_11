#!/usr/bin/env python3
from pathlib import Path
import json
import random

IN = Path("training_data.jsonl")
BACKUP = Path("training_data.jsonl.bak")
AUG_SUFFIXES = ["はどこ", "を探している", "の近く", "付近の", "の場所", "ありますか", "周辺", "近くの"]
AUG_PREFIXES = ["近くの", "周辺の"]


def load_examples(p: Path):
    with p.open("r", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def augment_example(ex, n=3):
    text = ex.get("text", "")
    out = set([text])
    # add suffix variations
    for suf in random.sample(AUG_SUFFIXES, min(n, len(AUG_SUFFIXES))):
        out.add(text + suf)
    # prefix variants
    for pre in random.sample(AUG_PREFIXES, 1):
        out.add(pre + text)
    # short form
    if len(text) > 2:
        out.add(text[:3])
    return sorted(out)
