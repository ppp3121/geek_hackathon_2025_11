from sentence_transformers import SentenceTransformer, util
import torch
import json
import os
from typing import Dict, List, Tuple

DATA_PATH = "augmented_training_data.jsonl"
MODEL_NAME = "sonoisa/sentence-bert-base-ja-mean-tokens"

def load_label_texts(jsonl_path: str) -> Dict[str, List[str]]:
    if not os.path.exists(jsonl_path):
        raise FileNotFoundError(f"JSONLが見つかりません: {jsonl_path}")
    label_texts: Dict[str, List[str]] = {}
    with open(jsonl_path, "r", encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                print(f"警告: {i}行目がJSONとして不正のためスキップ")
                continue
            label = entry.get("label")
            text = entry.get("text")
            if not label or not text:
                print(f"警告: {i}行目にlabel/textが無いのでスキップ")
                continue
            label_texts.setdefault(label, []).append(text)
    if not label_texts:
        raise ValueError("学習データからラベルが1件も読み込めませんでした。")
    return label_texts

def build_label_embeddings(model: SentenceTransformer, label_texts: Dict[str, List[str]]) -> Dict[str, torch.Tensor]:
    label_embeddings: Dict[str, torch.Tensor] = {}
    for label, texts in label_texts.items():
        if not texts:
            continue
        emb = model.encode(texts, convert_to_tensor=True, batch_size=32, show_progress_bar=False)
        if isinstance(emb, list):
            emb = torch.stack(emb)
        centroid = emb.mean(dim=0)
        label_embeddings[label] = centroid
    if not label_embeddings:
        raise ValueError("ラベルの埋め込み計算に失敗しました。")
    return label_embeddings

def classify(model: SentenceTransformer, label_embeddings: Dict[str, torch.Tensor], text: str, topk: int = 5) -> List[Tuple[str, float]]:
    input_emb = model.encode(text, convert_to_tensor=True)
    scores = []
    for label, emb in label_embeddings.items():
        sim = util.cos_sim(input_emb, emb).item()
        scores.append((label, float(sim)))
    scores.sort(key=lambda x: x[1], reverse=True)
    return scores[:max(1, topk)]

def interactive_loop(model: SentenceTransformer, data_path: str = DATA_PATH):
    print("対話モード: テキストを入力して分類します。:help でヘルプ。")
    print(f"モデル: {MODEL_NAME} / データ: {data_path}")
    label_texts = load_label_texts(data_path)
    label_embeddings = build_label_embeddings(model, label_texts)
    topk = 5

    while True:
        try:
            text = input("> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n終了します。")
            break

        if not text:
            continue

        if text.lower() in (":quit", ":exit"):
            print("終了します。")
            break
        if text.lower() == ":help":
            print("コマンド:")
            print("  :quit | :exit   終了")
            print("  :reload         学習データと埋め込みを再読込")
            print("  :topk N         上位N件を表示（例: :topk 3）")
            print("  :labels         ラベル一覧を表示")
            continue
        if text.lower() == ":reload":
            try:
                label_texts = load_label_texts(data_path)
                label_embeddings = build_label_embeddings(model, label_texts)
                print("再読込しました。")
            except Exception as e:
                print(f"再読込失敗: {e}")
            continue
        if text.lower().startswith(":topk"):
            parts = text.split()
            if len(parts) == 2 and parts[1].isdigit():
                topk = max(1, int(parts[1]))
                print(f"topk={topk} に設定しました。")
            else:
                print("使い方: :topk 3")
            continue
        if text.lower() == ":labels":
            print(f"ラベル数: {len(label_embeddings)}")
            print(", ".join(sorted(label_embeddings.keys())))
            continue

        try:
            results = classify(model, label_embeddings, text, topk=topk)
            best_label, best_score = results[0]
            print(f"予測: {best_label} (score={best_score:.4f})")
            if topk > 1 and len(results) > 1:
                print("上位:")
                for lbl, sc in results:
                    print(f"  - {lbl}: {sc:.4f}")
        except Exception as e:
            print(f"分類中にエラー: {e}")

def main():
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Device: {device}")
    model = SentenceTransformer(MODEL_NAME, device=device)
    # 対話モード開始
    interactive_loop(model, DATA_PATH)

if __name__ == "__main__":
    main()
