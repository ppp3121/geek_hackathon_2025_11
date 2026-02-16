#!/usr/bin/env python3
"""NER extractor (Transformer + lexicon fallback).

- TransformerのTokenClassificationモデルが存在すればNERで固有表現抽出
- 利用不可ならブランド辞書ベースへ自動フォールバック
"""

from __future__ import annotations

from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple
import os


_NER_PIPELINE = None
_NER_LOAD_FAILED = False
_NER_SOURCE = "lexicon"


def _load_ner_pipeline():
    global _NER_PIPELINE, _NER_LOAD_FAILED, _NER_SOURCE

    if _NER_PIPELINE is not None:
        return _NER_PIPELINE
    if _NER_LOAD_FAILED:
        return None

    enable = os.environ.get("NER_ENABLE_TRANSFORMER", "1").lower()
    if enable in ("0", "false", "off", "no"):
        _NER_LOAD_FAILED = True
        return None

    # 優先順位: 明示指定 -> ローカル既定
    model_dir = os.environ.get("NER_MODEL_DIR")
    if not model_dir:
        local_default = Path(__file__).with_name("ner_model")
        if local_default.exists():
            model_dir = str(local_default)

    if not model_dir:
        _NER_LOAD_FAILED = True
        return None

    try:
        import torch
        from transformers import pipeline

        device = 0 if torch.cuda.is_available() else -1
        ner_pipe = pipeline(
            "token-classification",
            model=model_dir,
            tokenizer=model_dir,
            aggregation_strategy="simple",
            device=device,
        )
        _NER_PIPELINE = ner_pipe
        _NER_SOURCE = f"transformer:{model_dir}"
        return _NER_PIPELINE
    except Exception as e:
        print("[NER] transformer load failed:", e)
        _NER_LOAD_FAILED = True
        return None


def _extract_brands_by_lexicon(
    normalized_query: str,
    brand_lexicon: Dict[str, Dict],
    normalize_fn: Callable[[str], str],
) -> List[str]:
    found: List[str] = []
    for brand, spec in brand_lexicon.items():
        aliases = spec.get("aliases", [])
        for alias in aliases:
            a = normalize_fn(alias)
            if a and a in normalized_query:
                found.append(brand)
                break
    return sorted(dict.fromkeys(found))


def _map_entity_group_to_type(group: str) -> Optional[str]:
    g = (group or "").upper()
    if g in {"ORG", "BRAND", "COMPANY", "B-BRAND", "I-BRAND"}:
        return "BRAND"
    if g in {"CATEGORY", "B-CATEGORY", "I-CATEGORY"}:
        return "CATEGORY"
    return None


def _extract_by_transformer(query: str) -> List[Tuple[str, str, float]]:
    """Return list of (entity_type, text, score)."""
    ner_pipe = _load_ner_pipeline()
    if ner_pipe is None:
        return []

    try:
        raw = ner_pipe(query)
    except Exception as e:
        print("[NER] inference failed:", e)
        return []

    out: List[Tuple[str, str, float]] = []
    for ent in raw:
        group = ent.get("entity_group") or ent.get("entity")
        etype = _map_entity_group_to_type(group)
        if not etype:
            continue
        text = (ent.get("word") or "").strip()
        score = float(ent.get("score") or 0.0)
        if text:
            out.append((etype, text, score))
    return out


def extract_brands_and_categories(
    query: str,
    brand_lexicon: Dict[str, Dict],
    normalize_fn: Callable[[str], str],
) -> Tuple[List[str], List[str], str]:
    """Extract BRAND/CATEGORY from query.

    Returns:
      brands, category_terms, source
      source: "transformer:*" or "lexicon"
    """
    normalized_query = normalize_fn(query)

    # 1) Transformer NER
    entities = _extract_by_transformer(query)
    source = _NER_SOURCE if entities else "lexicon"

    brands: List[str] = []
    categories: List[str] = []

    # Transformer結果をブランド辞書に正規化
    if entities:
        for etype, text, score in entities:
            if score < float(os.environ.get("NER_MIN_CONF", "0.45")):
                continue
            nt = normalize_fn(text)
            if etype == "BRAND":
                # 既存ブランド辞書に寄せる
                for brand, spec in brand_lexicon.items():
                    aliases = spec.get("aliases", [])
                    for alias in aliases:
                        if normalize_fn(alias) == nt:
                            brands.append(brand)
                            break
                # 辞書にないブランドはそのまま保持（将来拡張用）
                if nt and not any(normalize_fn(b) == nt for b in brands):
                    brands.append(text)
            elif etype == "CATEGORY":
                categories.append(nt)

    # 2) Lexicon fallback / merge
    lex_brands = _extract_brands_by_lexicon(normalized_query, brand_lexicon, normalize_fn)
    brands.extend(lex_brands)

    # unique
    brands = sorted(dict.fromkeys([b for b in brands if b]))
    categories = sorted(dict.fromkeys([c for c in categories if c]))

    return brands, categories, source
