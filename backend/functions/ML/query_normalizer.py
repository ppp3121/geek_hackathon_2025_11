#!/usr/bin/env python3
"""Query normalization + lightweight NER (brand/category split) helpers.

目的:
- 表記揺れを減らす正規化
- クエリ中のブランド名を抽出し、カテゴリ語との分離に使う

このモジュールは軽量ルールベースで、外部依存なしで動作します。
"""

from __future__ import annotations

from dataclasses import dataclass
import re
import unicodedata
from typing import Dict, List, Optional
from ner_extractor import extract_brands_and_categories

# 近傍検索で頻出の機能語
_SEARCH_NOISE = [
    "近くの",
    "周辺の",
    "周辺",
    "付近",
    "を探して",
    "を探している",
    "を検索",
    "どこ",
    "ありますか",
    "ある",
    "探す",
]

# ブランド辞書（最小セット）
# key: canonical brand name, values: aliases + default OSM tag hints
BRAND_LEXICON: Dict[str, Dict] = {
    "7-Eleven": {
        "aliases": ["セブン", "セブンイレブン", "7-11", "7eleven", "seven eleven"],
        "default_tags": [{"key": "shop", "value": "convenience"}],
    },
    "FamilyMart": {
        "aliases": ["ファミマ", "ファミリーマート", "familymart"],
        "default_tags": [{"key": "shop", "value": "convenience"}],
    },
    "Lawson": {
        "aliases": ["ローソン", "lawson"],
        "default_tags": [{"key": "shop", "value": "convenience"}],
    },
    "Starbucks": {
        "aliases": ["スタバ", "スターバックス", "starbucks"],
        "default_tags": [{"key": "amenity", "value": "cafe"}],
    },
    "McDonald's": {
        "aliases": ["マック", "マクド", "マクドナルド", "mcdonald", "mcdonalds"],
        "default_tags": [{"key": "amenity", "value": "fast_food"}],
    },
    "Doutor": {
        "aliases": ["ドトール", "doutor"],
        "default_tags": [{"key": "amenity", "value": "cafe"}],
    },
}


@dataclass
class QueryEntities:
    raw_query: str
    normalized_query: str
    category_query: str
    brands: List[str]
    brand_tags: List[Dict[str, str]]
    ner_source: str = "lexicon"


def normalize_text(text: str) -> str:
    """照合向けの軽量正規化。

    - NFKC
    - 小文字化（英数）
    - 空白/句読点除去
    - 検索ノイズ語除去
    """
    s = unicodedata.normalize("NFKC", (text or "")).strip().lower()

    # ひらがな -> カタカナ（語彙揺れ吸収）
    chars = []
    for ch in s:
        code = ord(ch)
        if 0x3041 <= code <= 0x3096:
            chars.append(chr(code + 0x60))
        else:
            chars.append(ch)
    s = "".join(chars)
    s = re.sub(r"[\s\u3000]+", "", s)
    s = re.sub(r"[!！?？,、。\.・/\\\-]+", "", s)

    for w in _SEARCH_NOISE:
        s = s.replace(w, "")
    return s


def _remove_brand_aliases(normalized_query: str, brands: List[str]) -> str:
    s = normalized_query
    for brand in brands:
        for alias in BRAND_LEXICON.get(brand, {}).get("aliases", []):
            a = normalize_text(alias)
            if a:
                s = s.replace(a, "")
    return s


def extract_query_entities(query: str) -> QueryEntities:
    nq = normalize_text(query)
    brands, categories, ner_source = extract_brands_and_categories(
        query=query,
        brand_lexicon=BRAND_LEXICON,
        normalize_fn=normalize_text,
    )
    category_query = _remove_brand_aliases(nq, brands)
    if not category_query and categories:
        category_query = categories[0]
    if not category_query:
        category_query = nq

    brand_tags: List[Dict[str, str]] = []
    for b in brands:
        for t in BRAND_LEXICON.get(b, {}).get("default_tags", []):
            brand_tags.append({"key": t.get("key"), "value": t.get("value")})

    # 重複排除
    uniq = []
    seen = set()
    for t in brand_tags:
        k = (t.get("key"), t.get("value"))
        if k not in seen and all(k):
            seen.add(k)
            uniq.append(t)

    return QueryEntities(
        raw_query=query,
        normalized_query=nq,
        category_query=category_query,
        brands=brands,
        brand_tags=uniq,
        ner_source=ner_source,
    )
