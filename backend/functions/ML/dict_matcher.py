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


def normalize_text(s: str) -> str:
    """テキストを小文字化・記号除去して正規化する。照合用に使用。"""
    return (s or "").strip()


def _strip_common_suffixes(s: str) -> str:
    for suf in ("屋", "店", "ショップ", "専門店"):
        if s.endswith(suf):
            return s[:-len(suf)]
    return s


def match_query(query: str, top_k: int = 2) -> List[Dict]:
    qn = normalize_text(query)
    tags = KEYWORD_TO_TAGS.get(qn)
    if not tags:
        qn2 = _strip_common_suffixes(qn)
        if qn2 != qn:
            tags = KEYWORD_TO_TAGS.get(qn2)
    if not tags:
        return []
    return [{"tags": tags}]


def match_query_or_none(query: str, top_k: int = 2) -> Optional[List[Dict]]:
    r = match_query(query, top_k=top_k)
    return r or None


# Note: this module is intended to be imported; use `match_query()` / `match_query_or_none()` from other scripts.
