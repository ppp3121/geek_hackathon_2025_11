# 1. ベースイメージをPython 3.11のスリムバージョンに指定
FROM python:3.11-slim

# 2. 環境変数を設定
#    - PYTHONUNBUFFERED: ログがコンテナの標準出力に直接送られ、Cloud Runのログ機能で確認しやすくなります。
#    - PORT: Cloud Runがリクエストを待つポート番号。Cloud Runのデフォルトは8080です。
ENV PYTHONUNBUFFERED True
ENV PORT 8080

# 3. 作業ディレクトリを作成し、移動
WORKDIR /app

# 4. 依存関係ファイルをコピー
#    backend/functions/requirements.txt を requirements.txt としてコピーします。
COPY backend/functions/requirements.txt ./

# 5. 依存関係をインストール
#    --no-cache-dir オプションで不要なキャッシュを残さず、イメージサイズを削減します。
RUN pip install --no-cache-dir -r requirements.txt

# 6. アプリケーションコードをコピー
#    backend/functions/ML/ 以下のすべてのファイルをコンテナの /app ディレクトリにコピーします。
COPY backend/functions/ML/ ./

# 7. コンテナ起動時に実行するコマンド
#    gunicornを使ってFastAPIアプリを起動します。Cloud Runのベストプラクティスです。
#    -w 4: 4つのワーカープロセスで起動（CPUコア数に応じて調整）
#    -k uvicorn.workers.UvicornWorker: Uvicornをワーカーとして使用
#    -b 0.0.0.0:${PORT}: すべてのIPアドレスの指定ポートで待機
CMD gunicorn -w 4 -k uvicorn.workers.UvicornWorker api:app --bind "0.0.0.0:$PORT"