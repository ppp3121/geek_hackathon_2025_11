#!/usr/bin/env python3
"""Generate augmented synonym dataset (表記揺れ含む) and train a simple normalizer.

Usage: run this script from `backend/functions` (or it will resolve paths relative to script).
It will load `backend/functions/ML/dictionary.py`, generate variants, save JSONL, train a small scikit-learn
pipeline and write `backend/functions/ML/synonym_normalizer.joblib`.
"""

from pathlib import Path
import json
import random
import unicodedata
import sys

OUT_JSONL = Path(__file__).resolve().parents[2] / "ML" / "synonym_training_augmented.jsonl"
OUT_MODEL = Path(__file__).resolve().parents[2] / "ML" / "synonym_normalizer.joblib"


def load_dictionary_module():
    # Load dictionary.py as a module without relying on package imports
    from importlib import util
    dict_path = Path(__file__).resolve().parents[2] / "ML" / "dictionary.py"
    spec = util.spec_from_file_location("ml_dictionary", str(dict_path))
    mod = util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.SYNONYM_MAP, getattr(mod, "AUG_SUFFIXES", [])


def mk_variants(base: str, aug_suffixes, n=10, seed=0):
    """Generate deterministic variants for a base synonym string.

    Variants include:
    - NFC/NFKC normalization
    - lowercasing (for ASCII)
    - suffix/prefix augmentations from aug_suffixes
    - simple typo edits: deletion, insertion, substitution (deterministic via seed)
    - elongated/dash variations (add/remove 'ー')
    """
    rng = random.Random(seed)
    variants = set()
    s = base
    variants.add(s)
    # normalization
    variants.add(unicodedata.normalize("NFKC", s))
    variants.add(s.lower())
    # add suffix variants
    for suf in aug_suffixes:
        variants.add(s + suf)
    # simple edits
    letters = list(s)
    if letters:
        # deletion
        i = rng.randrange(len(letters))
        variants.add("".join(letters[:i] + letters[i+1:]))
        # insertion of nearby character (simple vowel)
        i = rng.randrange(len(letters) + 1)
        variants.add("".join(letters[:i] + ["ー"] + letters[i:]))
        # substitution with 'n' or small kana approximations
        i = rng.randrange(len(letters))
        sub = letters.copy()
        sub[i] = "n" if letters[i] != "n" else "ん"
        variants.add("".join(sub))
    # elongated/dash variations
    variants.add(s.replace("ー", ""))
    variants.add(s + "ー")
    # limited ascii transformations
    variants.add(s.replace("Ａ", "A").replace("ａ", "a"))

    # Fill up with small random character edits deterministically until n
    attempts = 0
    while len(variants) < n and attempts < n * 5:
        attempts += 1
        t = list(s)
        if not t:
            break
        rng2 = random.Random(seed + attempts)
        op = rng2.choice(["del", "ins", "sub"])
        idx = rng2.randrange(len(t))
        if op == "del":
            t2 = t[:idx] + t[idx+1:]
        elif op == "ins":
            t2 = t[:idx] + [rng2.choice(["ー", "ん", "な"]) ] + t[idx:]
        else:
            t2 = t.copy()
            t2[idx] = rng2.choice(["ー", "ん", "な", "a"])
        variants.add("".join(t2))

    # cleanup
    variants = [v for v in variants if v and len(v) <= 80]
    return sorted(dict.fromkeys(variants))[:n]


def generate_dataset(syn_map, aug_suffixes, out_path: Path, n_per_canonical=200):
    out = []
    seed = 42
    for i, (canonical, syns) in enumerate(syn_map.items()):
        for s in syns:
            # generate variants per synonym (表記揺れのみ; サフィックスは付与しない)
            vars = mk_variants(s, [], n=12, seed=seed + i)
            for v in vars:
                out.append({"text": v, "label": canonical})
        # also include canonical itself without suffixes
        vars = mk_variants(canonical, [], n=12, seed=seed + i + 1000)
        for v in vars:
            out.append({"text": v, "label": canonical})

    # Ensure at least n_per_canonical per class by repeating randomly
    from collections import defaultdict
    grouped = defaultdict(list)
    for ex in out:
        grouped[ex["label"]].append(ex["text"])

    final = []
    for label, texts in grouped.items():
        # deterministic shuffling
        rnd = random.Random(hash(label) & 0xFFFFFFFF)
        while len(texts) < n_per_canonical:
            texts.extend(texts[:])
        texts = texts[:n_per_canonical]
        for t in texts:
            final.append({"text": t, "label": label})

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        for ex in final:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")
    return len(final)


def train_and_save(jsonl_path: Path, out_model: Path):
    # lightweight scikit-learn pipeline
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.pipeline import make_pipeline
    import joblib

    texts = []
    labels = []
    with jsonl_path.open("r", encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            ex = json.loads(line)
            texts.append(ex["text"])
            labels.append(ex["label"])

    vect = TfidfVectorizer(analyzer="char_wb", ngram_range=(2,4))
    clf = LogisticRegression(max_iter=1000)
    pipe = make_pipeline(vect, clf)
    pipe.fit(texts, labels)
    joblib.dump(pipe, out_model)
    return out_model


def main():
    syn_map, aug_suffixes = load_dictionary_module()
    print(f"Loaded {len(syn_map)} canonical labels")
    n = generate_dataset(syn_map, aug_suffixes, OUT_JSONL, n_per_canonical=200)
    print(f"Wrote {n} training examples to {OUT_JSONL}")
    model_path = train_and_save(OUT_JSONL, OUT_MODEL)
    print(f"Saved trained model to {model_path}")


if __name__ == "__main__":
    main()
