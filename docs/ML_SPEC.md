# ML Keyword Analysis API Specification v1.0

## 概要

ユーザーが入力した自然言語の検索クエリを解析し、Overpass APIで利用可能なタグの配列を返すためのAPI。

---

## 1. エンドポイント

- **URL:** `https://<MLサービスのドメイン>/api/v1/analyze-keywords`
- **Method:** `POST`

---

## 2. リクエスト

### ヘッダー

| Key             | Value           |
| --------------- | --------------- |
| `Content-Type`  | `application/json` |

### ボディ

```json:request_example.json
{
  "query": "ラーメン"
}
```

だったり

```json:request_example.json
{
  "query": "らーめん"
}
```

**フィールド詳細:**

| フィールド | 型       | 必須 | 説明                         |
| :------- | :------- | :--- | :--------------------------- |
| `query`  | `String` | Yes  | ユーザーが入力した検索キーワード |

---

## 3. レスポンス

### 成功時 (Success)

- **Status Code:** `200 OK`

**レスポンス例:**

```json
{
  "searchTerms": [
    {
      "key": "amenity",
      "value": "restaurant"
    },
    {
      "key": "cuisine",
      "value": "ramen"
    }
  ]
}
```

**フィールド詳細:**

| フィールド            | 型                  | 説明                                                                 |
| :-------------------- | :------------------ | :------------------------------------------------------------------- |
| `searchTerms`         | `Array<SearchTerm>` | 解析された検索条件の配列。 キーワードによって配列に含まれるオブジェクトの数は変動します。         |
| `SearchTerm.key`      | `String`            | Overpass APIのタグのキー (例: `amenity`)                               |
| `SearchTerm.value`    | `String`            | Overpass APIのタグの値 (例: `ramen`)                                   |

---

### 失敗時 (Error)

- **Status Code:** `400 Bad Request`

**レスポンス例:**

```json
{
  "error": {
    "code": 400,
    "message": "解析不能なキーワードです。"
  }
}
```

**フィールド詳細:**

| フィールド          | 型       | 説明                           |
| :---------------- | :------- | :----------------------------- |
| `error`           | `Object` | エラー情報を含むオブジェクト   |
| `error.code`      | `Number` | HTTPステータスコード           |
| `error.message`   | `String` | エラーメッセージ               |

---
