#!/usr/bin/env python3
"""辞書ベースの簡易マッチャー: 入力クエリを OSM の (key, value) にマップする。

このモジュールは以下を提供します:
- `normalize_text(s)`: 照合用の正規化関数
- `match_query(query, top_k)`: スコア付き候補を返す
- `match_query_or_none(query, top_k, min_score)`: 信頼度閾値で辞書優先判定を行う

辞書データは ML/dictionary.py の `KEYWORD_TO_TAGS` を参照します。
"""

from typing import List, Dict, Tuple, Optional
import re
from .dictionary import KEYWORD_TO_TAGS


DEFAULT_DIC: Dict[str, List[Tuple[str, str]]] = KEYWORD_TO_TAGS


def normalize_text(s: str) -> str:
    """テキストを小文字化・記号除去して正規化する。照合用に使用。"""
    if s is None:
        return ""
    s = s.lower()
    s = re.sub(r"[^\w\u3040-\u30ff\u4e00-\u9fff]+", " ", s)
    return s.strip()


def match_query(query: str, top_k: int = 2, dic: Optional[Dict[str, List[Tuple[str, str]]]] = None):
    """
    query に対して辞書照合を行い、スコア付きの候補を最大 top_k 件返す。
    スコア基準（簡易）: 完全一致=1.0, token 部分一致=0.8, 文字部分一致=0.3
    戻り値: list of {"key":..., "value":..., "score":...}, 必要なら None パディングで長さを揃える
    """
    dic = dic or DEFAULT_DIC
    q = normalize_text(query)
    results = []
    for keyword, pairs in dic.items():
        nk = normalize_text(keyword)
        if not nk:
            continue
        if nk == q or nk in q.split():
            score = 1.0
        elif nk in q:
            score = 0.8
        else:
            score = 0.0
            for ch in nk:
                if ch and ch in q:
                    score = max(score, 0.3)
        if score > 0:
            for k, v in pairs:
                results.append({"key": k, "value": v, "score": score})

    # スコア降順、重複除去（key,value 単位）、長さ調整
    results = sorted(results, key=lambda x: x["score"], reverse=True)
    seen = set()
    uniq = []
    for r in results:
        tup = (r["key"], r["value"])
        if tup in seen:
            continue
        seen.add(tup)
        uniq.append(r)

    while len(uniq) < top_k:
        uniq.append({"key": None, "value": None, "score": 0.0})
    return uniq[:top_k]


def match_query_or_none(query: str, top_k: int = 2, min_score: float = 0.8, dic: Optional[Dict[str, List[Tuple[str, str]]]] = None):
    """
    match_query を呼び出し、少なくとも1件が min_score 以上なら結果を返す。
    それ以外は None を返し、呼び出元は ML 正規化器へフォールバックする。
    """
    results = match_query(query, top_k=top_k, dic=dic)
    if not results:
        return None
    if any(r.get("score", 0.0) >= min_score for r in results if r.get("key") is not None):
        return results
    return None


# Note: this module is intended to be imported; use `match_query()` / `match_query_or_none()` from other scripts.
