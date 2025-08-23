#!/usr/bin/env python3
"""簡易辞書モジュール

このファイルには簡易的な同義語辞書とテキスト拡張のサフィックスをまとめています。
他モジュールはここから `SYNONYM_MAP` と `AUG_SUFFIXES` をインポートして利用してください。

注意: 将来的にはこの辞書を JSON/YAML に分離して読み込む実装に置き換えることができます。
"""

from typing import Dict, List

# Minimal synonym map: canonical -> list of synonyms/abbrevs
SYNONYM_MAP: Dict[str, List[str]] = {}

# Helper to add simple variants (hiragana, small kana, ascii lower)
def _variants(base: str):
    v = set()
    v.add(base)
    # hiragana rough conversion for common kana (limited)
    # for simplicity, add a hiragana form if base contains kanji for food names
    if base == "カフェ":
        v.update(["喫茶店", "コーヒー店", "コーヒーショップ", "カフェ"])
    if base == "コンビニ":
        v.update(["コンビニエンスストア", "コンビニ", "コンビニ店"])
    if base == "パン屋":
        v.update(["ベーカリー", "パン屋", "パン店"])
    # ascii/latin variants
    v.add(base.lower())
    return sorted(v)

# Populate SYNONYM_MAP with the user's canonical list (no suffixes)
canons = [
    "カフェ",
    "レストラン",
    "コンビニ",
    "スーパーマーケット",
    "デパート",
    "ラーメン",
    "うどん",
    "そば",
    "寿司",
    "焼肉",
    "焼き鳥",
    "天ぷら",
    "とんかつ",
    "丼物",
    "お好み焼き",
    "ピザ",
    "カレー",
    "ハンバーガー",
    "中華料理",
    "韓国料理",
    "タイ料理",
    "ベトナム料理",
    "インド料理",
    "スペイン料理",
    "メキシコ料理",
    "居酒屋",
    "バー",
    "パブ",
    "パン屋",
    "ケーキ屋",
    "和菓子屋",
    "酒店",
    "お茶屋",
    "精肉店",
    "鮮魚店",
    "八百屋",
    "本屋",
    "文房具店",
    "服屋",
    "靴屋",
    "鞄屋",
    "宝飾店",
    "メガネ屋",
    "時計屋",
    "家具屋",
    "雑貨屋",
    "花屋",
    "園芸店",
    "ホームセンター",
    "金物屋",
    "家電量販店",
    "携帯ショップ",
    "ドラッグストア",
    "化粧品店",
    "おもちゃ屋",
    "ゲームセンター",
    "スポーツ用品店",
    "自転車屋",
    "ペットショップ",
    "楽器店",
    "薬局",
    "病院",
    "クリニック",
    "歯科",
    "郵便局",
    "銀行",
    "ATM",
    "図書館",
    "市役所",
    "警察署",
    "消防署",
    "駐車場",
    "コインランドリー",
    "クリーニング",
    "レンタカー",
    "美容院",
    "理髪店",
    "ネイルサロン",
    "ホテル",
    "旅館",
    "ホステル",
    "公園",
    "映画館",
    "美術館",
    "博物館",
    "水族館",
    "動物園",
    "ボウリング場",
    "フィットネスジム",
    "プール",
    "ゴルフ場",
    "ガソリンスタンド",
]

for c in canons:
    SYNONYM_MAP[c] = _variants(c)

# Keep previously added 中華そば
SYNONYM_MAP["中華そば"] = ["中華そば", "ちゅうかそば", "中華そば屋", "中華そば店", "ちゅうかそば屋"]

# テキスト拡張で付与する丁寧語や文脈語のサフィックス
AUG_SUFFIXES = ["の近く", "近くの", "がある", "を探している", "の場所"]
