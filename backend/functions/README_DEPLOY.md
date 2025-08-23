デプロイ手順（短縮版）

目的
- 他の開発者がリポジトリを pull して、Cloud Functions / Cloud Run にデプロイするだけで API が動くようにする。

前提（最小ランタイム）
- 以下ファイルが含まれていること（必須）:
  - `src/api.py`, `src/index.ts`
  - `ML/synonym_normalizer.py`, `ML/dict_matcher.py`, `ML/train_synonym_normalizer.py`（プレースホルダ可）
  - `ML/synonym_normalizer.joblib`（学習済みの軽量 normalizer）
  - `requirements.txt`（ランタイム用、重い training deps は `requirements-train.txt` に分離済み）

環境変数（任意）
- `MODEL_GCS_URI` : GCS の gs:// バケットパス（例: gs://my-bucket/path/synonym_normalizer.joblib）。設定すると起動時に GCS からモデルをダウンロードします。
- `MODEL_PATH` : コンテナー内のモデル保存先を直接指定する場合に使用（`OUT_MODEL` と同等）。
- `MIN_CONFIDENCE` : normalize_query の確信度閾値（例: 0.5）。設定がないと閾値は無効（モデルの予測をそのまま採用）。

ローカルでの簡易テスト
1. 仮想環境を有効化
```powershell
& .\venv\Scripts\Activate.ps1
```
2. ランタイム依存をインストール
```powershell
pip install -r backend\functions\requirements.txt
```
3. FastAPI を起動して動作確認
```powershell
cd backend\functions
uvicorn src.api:app --host 0.0.0.0 --port 8080
```
- 起動後、`http://localhost:8080/api/v1/status` にアクセスして `normalizer_loaded` を確認してください。

Cloud Functions (Python) へのデプロイ（シンプル／推奨: ランタイムが軽い場合）
1. GCP プロジェクトが設定済みであること。gcloud が認証済みであること。
2. 必要に応じて `MODEL_GCS_URI` を設定する（デプロイ後に環境変数として渡すことを推奨）。
3. デプロイ例（HTTP トリガー）:
```powershell
# Cloud Functions (Python 3.11 例)
gcloud functions deploy osm-tag-api \
  --runtime python311 \
  --entry-point app \
  --trigger-http \
  --allow-unauthenticated \
  --region=asia-northeast1 \
  --set-env-vars "MIN_CONFIDENCE=0.5,MODEL_GCS_URI=gs://..."
```
注意: Cloud Functions のイメージビルドは依存が多いと遅くなるため、`requirements.txt` は最小化してあります。

Cloud Run（推奨: FastAPI を長時間稼働させる場合）
- コンテナ化してデプロイする手順（簡易）:
```powershell
cd backend\functions
# Dockerfile がある場合はそれを使う。無い場合は簡易 Dockerfile を作成してビルド
docker build -t gcr.io/PROJECT_ID/osm-tag-api:latest .
docker push gcr.io/PROJECT_ID/osm-tag-api:latest
# Cloud Run デプロイ
gcloud run deploy osm-tag-api --image gcr.io/PROJECT_ID/osm-tag-api:latest --region=asia-northeast1 --platform=managed --allow-unauthenticated --set-env-vars "MIN_CONFIDENCE=0.5,MODEL_GCS_URI=gs://..."
```
利点: cold-start が小さく、起動時間が安定する。重い依存がある場合はこちらが実運用向き。

トレーニング（開発者向け）
- トレーニング環境では `requirements-train.txt` を使って依存を入れてください（GPU 環境推奨）。
```powershell
pip install -r backend\functions\requirements-train.txt
python backend\functions\tools\train\generate_and_train_normalizer.py
```
- 学習後は生成される `ML/synonym_normalizer.joblib` をコミットするか、クラウドにアップロードして `MODEL_GCS_URI` で参照してください。

注意事項
- 大きな transformer モデルをリポジトリにコミットしないでください。Git LFS か GCS/S3 等のクラウドに保存し、ダウンロードスクリプトを提供してください。
- `requirements.txt` を軽量化することで Cloud Functions のデプロイ・起動が速くなります。

補足: もし私に代行して "collab-ready" ブランチを作成して push してよければ教えてください（過去に大きなファイルが含まれて push が失敗したため、まずは新しいブランチで小さなコミットを作るのが安全です）。
