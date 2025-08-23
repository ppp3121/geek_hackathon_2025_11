#!/usr/bin/env python3
"""簡易辞書モジュール（タグ付き）

このファイルは「日本語テキスト→OSMタグ(list[(key,value)])」の一次情報を持ちます。

構造:
- CANON_TAGS: 正規表現（正規語）→ OSM タグの配列
- SYNONYM_MAP: 正規語 → 同義語リスト
- KEYWORD_TO_TAGS: 最終的に照合で使う「キーワード（正規語+同義語）」→ OSM タグの配列
- AUG_SUFFIXES: テキスト拡張のためのサフィックス

他モジュールは `KEYWORD_TO_TAGS` を参照してください（dict_matcher がこれを取り込みます）。

注意: 将来的にはこの辞書を JSON/YAML に分離して外部ファイルから読み込むことも可能です。
"""

from typing import Dict, List, Tuple

# Minimal synonym map: canonical -> list of synonyms/abbrevs
SYNONYM_MAP: Dict[str, List[str]] = {}

# 正規語ごとの OSM タグ定義（ユーザー提供の CSV を反映）
# 例: "カフェ" -> [("amenity","cafe")]
CANON_TAGS: Dict[str, List[Tuple[str, str]]] = {
    "カフェ": [("amenity", "cafe")],
    "レストラン": [("amenity", "restaurant")],
    "コンビニ": [("amenity", "convenience")],
    "スーパーマーケット": [("shop", "supermarket")],
    "デパート": [("shop", "department_store")],
    # 修正: ramen は 2 タプルで表現
    "ラーメン": [("amenity", "restaurant"), ("cuisine", "ramen")],
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
    "パン屋": [("shop", "bakery")],
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
    "薬局": [("amenity", "pharmacy")],
    "病院": [("amenity", "hospital")],
    "クリニック": [("amenity", "clinic")],
    "歯科": [("amenity", "dentist")],
    "郵便局": [("amenity", "post_office")],
    "銀行": [("amenity", "bank")],
    "ATM": [("amenity", "atm")],
    "図書館": [("amenity", "library")],
    "市役所": [("amenity", "townhall")],
    "警察署": [("amenity", "police")],
    "消防署": [("amenity", "fire_station")],
    "駐車場": [("amenity", "parking")],
    "コインランドリー": [("shop", "laundry")],
    "クリーニング": [("shop", "dry_cleaning")],
    "レンタカー": [("amenity", "car_rental")],
    "美容院": [("shop", "hairdresser")],
    "理髪店": [("shop", "hairdresser")],
    "ネイルサロン": [("shop", "beauty")],
    "ホテル": [("tourism", "hotel")],
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

def _with_place_suffixes(terms: List[str]) -> List[str]:
    # 店舗系のゆれ: 屋/店/ショップ/専門店/食堂/家 など
    suf = ["屋", "店", "ショップ", "専門店"]
    out = set(terms)
    for t in terms:
        for s in suf:
            out.add(t + s)
    return sorted(out)

def _variants_explicit() -> Dict[str, List[str]]:
    """表記ゆれを明示的に拡充（中華そばなど）"""
    return {
        "ラーメン": [
            "ラーメン", "らーめん", "拉麺",
            "中華そば", "ちゅうかそば",
            "ラーメン屋", "ラーメン店", "ラーメンショップ",
            "らーめん屋", "中華そば屋", "中華そば店",
        ],
        "うどん": ["うどん", "饂飩", "うどん屋", "うどん店"],
        "そば": ["そば", "蕎麦", "蕎麦屋", "そば屋", "そば店"],
        "寿司": ["寿司", "すし", "鮨", "鮓", "寿司屋", "すし屋"],
        "焼肉": ["焼肉", "やきにく", "焼き肉", "焼肉店"],
        "焼き鳥": ["焼き鳥", "やきとり", "焼鳥", "焼き鳥屋"],
        "天ぷら": ["天ぷら", "てんぷら", "天婦羅", "天ぷら屋"],
        "とんかつ": ["とんかつ", "トンカツ", "豚カツ"],
        "丼物": ["丼物", "どんぶり", "丼", "どんもの"],
        "お好み焼き": ["お好み焼き", "おこのみやき"],
        "ピザ": ["ピザ", "ピッツァ", "ピザ屋"],
        "カレー": ["カレー", "カリー", "インドカレー"],
        "ハンバーガー": ["ハンバーガー", "バーガー", "バーガーショップ"],
        "中華料理": ["中華料理", "中華", "中華食堂"],
        "韓国料理": ["韓国料理", "韓国", "コリアン"],
        "タイ料理": ["タイ料理", "タイ", "タイフード"],
        "インド料理": ["インド料理", "インド", "インド食堂", "インドカレー"],
        "スペイン料理": ["スペイン料理", "スペイン", "スパニッシュ"],
        "メキシコ料理": ["メキシコ料理", "メキシコ", "メキシカン"],
        "カフェ": ["カフェ", "喫茶店", "コーヒー店", "コーヒーショップ"],
        "レストラン": ["レストラン", "食堂", "飯屋"],
        "居酒屋": ["居酒屋", "いざかや", "飲み屋"],
        "バー": ["バー", "BAR"],
        "パン屋": ["パン屋", "ベーカリー", "パン店"],
        "コンビニ": ["コンビニ", "コンビニエンスストア", "コンビニ店"],
        "ドラッグストア": ["ドラッグストア", "薬店", "ドラッグ", "ドラッグショップ"],
        "薬局": ["薬局", "調剤薬局"],
        "美容院": ["美容院", "美容室", "ヘアサロン"],
        "理髪店": ["理髪店", "床屋", "バーバー"],
        "携帯ショップ": ["携帯ショップ", "携帯電話ショップ", "スマホショップ"],
        "花屋": ["花屋", "フラワーショップ"],
        "ゲームセンター": ["ゲームセンター", "ゲーセン", "アミューズメント"],
    }

# 既定の簡易バリアント（既存）
def _variants(base: str):
    v = set()
    v.add(base)
    if base == "カフェ":
        v.update(["喫茶店", "コーヒー店", "コーヒーショップ", "カフェ"])
    if base == "コンビニ":
        v.update(["コンビニエンスストア", "コンビニ", "コンビニ店"])
    if base == "パン屋":
        v.update(["ベーカリー", "パン屋", "パン店"])
    v.add(base.lower())
    return sorted(v)

# Populate SYNONYM_MAP
canons = list(CANON_TAGS.keys())
for c in canons:
    SYNONYM_MAP[c] = _variants(c)

# 明示的表記ゆれを上書き・追加
for canon, terms in _variants_explicit().items():
    # 店舗接尾辞も自動追加
    SYNONYM_MAP[canon] = sorted(set(SYNONYM_MAP.get(canon, []) + _with_place_suffixes(terms)))

# 中華そば（別立ての要望にも対応）
SYNONYM_MAP.setdefault("中華そば", ["中華そば", "ちゅうかそば", "中華そば屋", "中華そば店", "らーめん", "ラーメン"])

# テキスト拡張で付与する丁寧語や文脈語のサフィックス
AUG_SUFFIXES = ["の近く", "近くの", "がある", "を探している", "の場所"]


def build_keyword_to_tags() -> Dict[str, List[Tuple[str, str]]]:
    """正規語と同義語から、キーワード→タグ配列の辞書を構築する。

    - 正規語そのものにタグをひもづけ
    - 同義語にも同じタグをひもづけ
    重複 (key,value) は呼び出し側で除去されるため、そのまま並べてよい。
    """
    out: Dict[str, List[Tuple[str, str]]] = {}
    for canon, tags in CANON_TAGS.items():
        out.setdefault(canon, [])
        out[canon].extend(tags)
        for syn in SYNONYM_MAP.get(canon, [canon]):
            out.setdefault(syn, [])
            out[syn].extend(tags)
    # 個別追加（正規語がないが同義として扱いたいなど）
    # 例: らーめん → ラーメン
    if "ラーメン" in CANON_TAGS:
        out.setdefault("らーめん", [])
        out["らーめん"].extend(CANON_TAGS["ラーメン"])
    return out


# dict_matcher で利用する最終辞書
KEYWORD_TO_TAGS: Dict[str, List[Tuple[str, str]]] = build_keyword_to_tags()
