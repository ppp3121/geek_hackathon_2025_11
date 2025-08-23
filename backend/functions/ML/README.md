## 同義語正規化モジュール（概要）

このディレクトリには、ユーザークエリの表記揺れ（同義語・誤字・略称など）を辞書優先 + 学習器で正規化して OSM 相当のカテゴリ（canonical ラベル）を返す簡易パイプラインが含まれます。

### 目的
- 日本語ユーザークエリを受け取り、内部で定義した canonical ラベル（例: `ラーメン`, `カフェ` など）に正規化する。
- 辞書で確実にマッチする場合は辞書優先で即時返却。辞書にない場合は学習済みの軽量モデルで推定する。

### 主要ファイル
- `dictionary.py` - 簡易辞書（`SYNONYM_MAP`）とサフィックス（`AUG_SUFFIXES`）。ここに canonical と表記揺れを追加する。
- `synonym_normalizer.py` - 公開 API `normalize_query(text, min_confidence=None)` とデモ。辞書優先 → 遅延ロードしたモデルによるフォールバックの実装。
- `synonym_normalizer.joblib` - 学習済みの scikit-learn パイプライン（TF-IDF + LogisticRegression）。
- `synonym_training_augmented.jsonl` - 辞書から生成した表記揺れを含む学習データ（JSONL）。
- `tools/train/generate_and_train_normalizer.py` - 学習データの生成とモデル学習を行うスクリプト。

### 依存ライブラリ
- Python 3.8+（プロジェクトは venv を推奨）
- scikit-learn (適合性のため推奨: `==1.6.1`)
- joblib
- numpy (scikit-learn 依存で自動的に必要)

ランタイムで参照される追加ライブラリ（API 層）: `fastapi`, `uvicorn`（API 実行時のみ）

### 処理の流れ（高レベル）
1. `normalize_query(text, min_confidence=None)` が呼ばれる。
2. `_dict_match` で `dictionary.SYNONYM_MAP` を使い完全一致 / 同義語一致 / 部分一致を試す。ヒットすればその canonical を返す。
3. 辞書でヒットしなければ、遅延ロードされた学習済みモデル（`synonym_normalizer.joblib`）で推定する。
   - モデルが `predict_proba` を持ち `min_confidence` が指定されている場合は、最大確率が閾値以上ならそのクラスを返す。閾値未満なら `None` を返す。
   - 閾値が `None`、またはモデルが確率出力に対応していない場合は `predict()` の結果を受け入れる。
4. どちらもヒットしない場合は `None` を返す。呼び出し側で 400 や候補提示の処理を行ってください。

### 入力 / 出力
- 入力: 任意の文字列（ユーザークエリ）
- 出力: canonical ラベル文字列（例: `"ラーメン"`）または `None`
- オプション: `min_confidence`（float 0.0-1.0）。モードにより低確信度を `None` として扱う。

使用例（Python スニペット）
```python
from ML.synonym_normalizer import normalize_query
print(normalize_query('らーめん'))
print(normalize_query('中華そば', min_confidence=0.6))
```

### 学習データの再生成 / モデル再学習
1. `dictionary.py` に新しい canonical と同義語を追加する。
2. プロジェクトルートから（`backend/functions` をカレントにして）次のスクリプトを実行:
```powershell
& .\venv\Scripts\python.exe tools\train\generate_and_train_normalizer.py
```
3. 実行により `ML/synonym_training_augmented.jsonl` と `ML/synonym_normalizer.joblib` が更新されます。変更をコミットしてデプロイしてください。

### Transformer を使った追加学習（オプション）
小規模ながら事前学習済みの日本語 BERT (`cl-tohoku/bert-base-japanese-whole-word-masking`) を用いて分類器を追加学習できます。手順:

1. `backend/functions` をカレントにして依存をインストール:
```powershell
& .\venv\Scripts\pip.exe install -r requirements.txt
```
2. ファインチューニングを実行:
```powershell
& .\venv\Scripts\python.exe tools\train\finetune_transformer.py --data-file ML/synonym_training_augmented.jsonl --output-dir ML/transformer_model --epochs 3 --per-device-train-batch-size 8
```
3. 学習後、`ML/transformer_model` に transformer ベースのモデルが保存されます。必要に応じて API からこのモデルを使うラッパーを用意してください。

注意: Transformer のファインチューニングは計算資源を消費します。GPU がない場合は非常に時間がかかります。

### 運用上の注意 / 改善案
- 学習データのバランスにより誤分類が起きやすいラベルが存在するため、新ラベルを追加した場合は必ず再学習してください。
- 軽微な誤字に強くするには:
  - 辞書側でより多くの表記揺れを列挙する、または
  - Levenshtein（編集距離）や symspell などの辞書補正を `normalize_query` の前段に追加する。
- 低確信度を `None` にする運用（`min_confidence` を使う）を行うと未知語誤分類を抑えられます。

### 連絡 / 変更履歴
- このファイルは `backend/functions/ML` 下の正規化ロジックの簡易ドキュメントです。
- 実際の変更は git のコミット履歴を参照してください（モデルや学習データは大きいので LFS の導入を検討しても良いです）。

---
（補足）将来的には辞書を外部 JSON/YAML に分離し、CI で自動的に再学習・バージョン管理するワークフローが望ましいです。
