#!/usr/bin/env python3
"""辞書ベースの簡易マッチャー: 入力クエリを OSM の (key, value) にマップする。

このモジュールは以下を提供します:
- `normalize_text(s)`: 照合用の正規化関数
- `match_query(query, top_k)`: スコア付き候補を返す
- `match_query_or_none(query, top_k, min_score)`: 信頼度閾値で辞書優先判定を行う

辞書データは ML/dictionary.py の `KEYWORD_TO_TAGS` を参照します。
"""

from __future__ import annotations
from typing import Optional, List, Dict
from dictionary import KEYWORD_TO_TAGS
from query_normalizer import extract_query_entities, normalize_text as normalize_query_text


def normalize_text(s: str) -> str:
    """テキストを小文字化・記号除去して正規化する。照合用に使用。"""
    return normalize_query_text(s)


def _strip_common_suffixes(s: str) -> str:
    base = s
    for suf in ("屋", "店", "ショップ", "専門店", "を探して", "を探している", "どこ", "ありますか"):
        if base.endswith(suf):
            base = base[:-len(suf)]
    return base


def match_query(query: str, top_k: int = 2) -> List[Dict]:
    ent = extract_query_entities(query)
    candidates = []

    raw = (query or "").strip()
    if raw:
        candidates.append(raw)
        raw_stripped = _strip_common_suffixes(raw)
        if raw_stripped and raw_stripped not in candidates:
            candidates.append(raw_stripped)

    # 1) ブランドを除いたカテゴリ文字列を優先
    if ent.category_query:
        candidates.append(ent.category_query)

    # 2) 正規化済み全文
    if ent.normalized_query and ent.normalized_query not in candidates:
        candidates.append(ent.normalized_query)

    # 3) 接尾語除去
    stripped = _strip_common_suffixes(ent.category_query or ent.normalized_query)
    if stripped and stripped not in candidates:
        candidates.append(stripped)

    tags = None
    for c in candidates:
        tags = KEYWORD_TO_TAGS.get(c)
        if tags:
            break

    # ヒットしたら、ブランド由来の補助タグも付与
    if tags and ent.brand_tags:
        merged = list(tags)
        seen = {(t.get("key"), t.get("value")) for t in merged}
        for bt in ent.brand_tags:
            kv = (bt.get("key"), bt.get("value"))
            if kv not in seen and all(kv):
                merged.append(bt)
                seen.add(kv)
        tags = merged

    # カテゴリ辞書に未ヒットでも、ブランドのみ判定できた場合はブランド既定タグで返す
    if not tags and ent.brand_tags:
        tags = ent.brand_tags

    if not tags:
        return []
    return [{"tags": tags}]


def match_query_or_none(query: str, top_k: int = 2) -> Optional[List[Dict]]:
    r = match_query(query, top_k=top_k)
    return r or None


# Note: this module is intended to be imported; use `match_query()` / `match_query_or_none()` from other scripts.
