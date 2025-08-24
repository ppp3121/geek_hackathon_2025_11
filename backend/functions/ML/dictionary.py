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

from __future__ import annotations
from pathlib import Path
import csv, json

# 同ディレクトリに置く CSV（UTF-8/BOM 可）
DICT_CSV_PATH = Path(__file__).with_name("osm_dictionary.csv")

def load_keyword_to_tags(csv_path: Path = DICT_CSV_PATH) -> dict[str, list[dict]]:
    """
    CSV 形式:
      text,tags
      カフェ,"[{""key"": ""amenity"", ""value"": ""cafe""}]"
    """
    mapping: dict[str, list[dict]] = {}
    if not csv_path.exists():
        return mapping
    with csv_path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            text = (row.get("text") or "").strip()
            tags_str = row.get("tags") or "[]"
            if not text:
                continue
            try:
                tags = json.loads(tags_str)
            except Exception:
                tags = []
            # 正規化: {"key","value"} のみ
            tags = [
                {"key": t.get("key"), "value": t.get("value")}
                for t in tags
                if isinstance(t, dict) and "key" in t and "value" in t
            ]
            # ramen の補正（amenity=ramen は存在しない）
            if len(tags) == 1 and tags[0] == {"key": "amenity", "value": "ramen"}:
                tags = [{"key": "amenity", "value": "restaurant"}, {"key": "cuisine", "value": "ramen"}]
            if tags:
                mapping[text] = tags
    return mapping

# 公開マップ
KEYWORD_TO_TAGS: dict[str, list[dict]] = load_keyword_to_tags()
