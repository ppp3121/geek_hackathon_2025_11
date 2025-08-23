#!/usr/bin/env python3
"""辞書ベースの簡易マッチャー: 入力クエリを OSM の (key,value) にマップする。

このモジュールは以下を提供します:
- `DEFAULT_DIC`: キーワード (日本語) -> list of (key, value)
- `normalize_text(s)`: 照合用の正規化関数
- `match_query(query, top_k)`: スコア付き候補を返す
- `match_query_or_none(query, top_k, min_score)`: 信頼度閾値で辞書優先判定を行う

設計上、辞書に確信あるマッチがあればその結果を返し、なければ呼び出し側は
ML 正規化器を試す（フォールバック）ことを想定しています。
"""

from typing import List, Dict, Tuple, Optional
import re


# 大量のエントリはここに展開（重複は上書きされる）
DEFAULT_DIC: Dict[str, List[Tuple[str, str]]] = {
    "ラーメン": [("amenity", "restaurant"), ("cuisine", "ramen")],
    "らーめん": [("amenity", "restaurant"), ("cuisine", "ramen")],
    "カフェ": [("amenity", "cafe"), ("shop", "tea")],
    "コーヒー": [("amenity", "cafe"), ("shop", "tea")],
    "コンビニ": [("amenity", "convenience"), ("shop", "variety_store")],
    "ATM": [("amenity", "atm")],
    "病院": [("amenity", "hospital")],
    "ホテル": [("tourism", "hotel")],
    # 追加
    "パン屋": [("shop", "bakery")],
    "ベーカリー": [("shop", "bakery")],
    "トイレ": [("amenity", "toilets")],
    "駅": [("railway", "station")],
    "図書館": [("amenity", "library")],
    "郵便局": [("amenity", "post_office")],
    "銀行": [("amenity", "bank")],
    "バス停": [("highway", "bus_stop")],
    "コインランドリー": [("shop", "laundry")],
    "薬局": [("amenity", "pharmacy")],
    "bakery": [("shop", "bakery")],
    "atm": [("amenity", "atm")],
    # CSV additions (merged)
    "レストラン": [("amenity", "restaurant")],
    "スーパーマーケット": [("shop", "supermarket")],
    "デパート": [("shop", "department_store")],
    "うどん": [("amenity", "restaurant"), ("cuisine", "udon")],
    "そば": [("amenity", "restaurant"), ("cuisine", "soba")],
    "寿司": [("amenity", "restaurant"), ("cuisine", "sushi")],
    "焼肉": [("amenity", "restaurant"), ("cuisine", "yakiniku")],
    "焼き鳥": [("amenity", "restaurant"), ("cuisine", "yakitori")],
    "天ぷら": [("amenity", "restaurant"), ("cuisine", "tempura")],
    "とんかつ": [("amenity", "restaurant"), ("cuisine", "tonkatsu")],
    "丼物": [("amenity", "restaurant"), ("cuisine", "donburi")],
    "お好み焼き": [("amenity", "restaurant"), ("cuisine", "okonomiyaki")],
    "ピザ": [("amenity", "restaurant"), ("cuisine", "pizza")],
    "カレー": [("amenity", "restaurant"), ("cuisine", "curry")],
    "ハンバーガー": [("amenity", "fast_food"), ("cuisine", "burger")],
    "中華料理": [("amenity", "restaurant"), ("cuisine", "chinese")],
    "韓国料理": [("amenity", "restaurant"), ("cuisine", "korean")],
    "タイ料理": [("amenity", "restaurant"), ("cuisine", "thai")],
    "ベトナム料理": [("amenity", "restaurant"), ("cuisine", "vietnamese")],
    "インド料理": [("amenity", "restaurant"), ("cuisine", "indian")],
    "スペイン料理": [("amenity", "restaurant"), ("cuisine", "spanish")],
    "メキシコ料理": [("amenity", "restaurant"), ("cuisine", "mexican")],
    "居酒屋": [("amenity", "bar")],
    "バー": [("amenity", "bar")],
    "パブ": [("amenity", "pub")],
    "ケーキ屋": [("shop", "pastry")],
    "和菓子屋": [("shop", "confectionery")],
    "酒店": [("shop", "alcohol")],
    "お茶屋": [("shop", "tea")],
    "精肉店": [("shop", "butcher")],
    "鮮魚店": [("shop", "seafood")],
    "八百屋": [("shop", "greengrocer")],
    "本屋": [("shop", "books")],
    "文房具店": [("shop", "stationery")],
    "服屋": [("shop", "clothes")],
    "靴屋": [("shop", "shoes")],
    "鞄屋": [("shop", "bag")],
    "宝飾店": [("shop", "jewelry")],
    "メガネ屋": [("shop", "optician")],
    "時計屋": [("shop", "watches")],
    "家具屋": [("shop", "furniture")],
    "雑貨屋": [("shop", "variety_store")],
    "花屋": [("shop", "florist")],
    "園芸店": [("shop", "garden_centre")],
    "ホームセンター": [("shop", "doityourself")],
    "金物屋": [("shop", "hardware")],
    "家電量販店": [("shop", "electronics")],
    "携帯ショップ": [("shop", "mobile_phone")],
    "ドラッグストア": [("shop", "chemist")],
    "化粧品店": [("shop", "cosmetics")],
    "おもちゃ屋": [("shop", "toys")],
    "ゲームセンター": [("leisure", "amusement_arcade")],
    "スポーツ用品店": [("shop", "sports")],
    "自転車屋": [("shop", "bicycle")],
    "ペットショップ": [("shop", "pet")],
    "楽器店": [("shop", "musical_instrument")],
    "クリニック": [("amenity", "clinic")],
    "歯科": [("amenity", "dentist")],
    "市役所": [("amenity", "townhall")],
    "警察署": [("amenity", "police")],
    "消防署": [("amenity", "fire_station")],
    "駐車場": [("amenity", "parking")],
    "クリーニング": [("shop", "dry_cleaning")],
    "レンタカー": [("amenity", "car_rental")],
    "美容院": [("shop", "hairdresser")],
    "理髪店": [("shop", "hairdresser")],
    "ネイルサロン": [("shop", "beauty")],
    "旅館": [("tourism", "guest_house")],
    "ホステル": [("tourism", "hostel")],
    "公園": [("leisure", "park")],
    "映画館": [("amenity", "cinema")],
    "美術館": [("tourism", "museum")],
    "博物館": [("tourism", "museum")],
    "水族館": [("tourism", "aquarium")],
    "動物園": [("tourism", "zoo")],
    "ボウリング場": [("leisure", "bowling_alley")],
    "フィットネスジム": [("leisure", "fitness_centre")],
    "プール": [("leisure", "swimming_pool")],
    "ゴルフ場": [("leisure", "golf_course")],
    "ガソリンスタンド": [("amenity", "fuel")],
}


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
