MVP API（日本語ドキュメント）

## 実行方法（PowerShell）

```powershell
# 仮想環境を有効化（未実行の場合）
.\venv\Scripts\Activate.ps1
# API サーバ起動
uvicorn api:app --host 0.0.0.0 --port 8080 --log-level info
```

## 主要エンドポイント
- POST /api/v1/analyze-keywords
  - ボディ例: {"query": "ラーメン", "top_k": 3}
  - 説明: 入力クエリに対して候補となる OSM タグを返します（辞書優先 → 正規化器フォールバック）。
- POST /api/v1/reload
  - ボディ例: {"model_dir":"./osmtag-classifier"}
  - 説明: 学習済みモデルを再読み込みします。現在は `synonym_normalizer.joblib` の再読み込みに主に使われます。
- POST /api/v1/train
  - ボディ例（旧フロー）: {"model_dir":"./osmtag-classifier","data_path":"training_data.jsonl","max_count":20,"epochs":3}
  - 説明: 旧来の Transformer ベースの学習用エンドポイントです（現在は無効・非推奨）。正規化器の学習は `train_synonym_normalizer.py` を使用してください。
- GET /api/v1/status


## 現在の処理フロー（簡潔）
1. 辞書優先
   - `DEFAULT_DIC`（手作業で作った高信頼辞書）にまず照合します。
2. 同義語正規化（ML フォールバック）
   - 辞書で自信のある候補が得られないとき、学習済みの `synonym_normalizer.joblib`（scikit-learn パイプライン）で入力を正規形に変換し、その正規形を辞書で再照合します。
3. 最終扱い
   - 上記いずれでもヒットしなければ「未検出（no match）」として扱います。必要であれば 400 エラー等へ変更可能です。

## エンドポイント備考
- `/api/v1/analyze-keywords` : 辞書優先 → 正規化器フォールバック → no-match
- `/api/v1/reload` : `synonym_normalizer.joblib` の再読み込みを行います（以前の Transformer 再読み込みは使われません）
- `/api/v1/train` : 旧来 Transformer 用であり、現状は非推奨です。正規化器は `train_synonym_normalizer.py` を使ってください。

## 同義語正規化器（synonym_normalizer）の再学習手順
1. データ生成
   - `synonym_normalizer.generate_synonym_dataset()` を使うか、`run_synonym_demo.py` で `synonym_training.jsonl` を作成します。
2. 学習
   - `train_synonym_normalizer.py` を実行すると `synonym_normalizer.joblib` が生成されます。
3. 再読み込み
   - API に新しいモデルを反映するために POST /api/v1/reload を呼びます。

## 運用上の注意
- 本番環境ではプロセスマネージャ（例: systemd, pm2）で監視起動し、認証・レート制限・入力検証を追加してください。
