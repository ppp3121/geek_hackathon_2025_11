#!/usr/bin/env python3
"""Fine-tune a Japanese BERT (cl-tohoku/bert-base-japanese-whole-word-masking)

This script fine-tunes a pretrained Japanese BERT on the generated JSONL training
data (`backend/functions/ML/synonym_training_augmented.jsonl`). It uses the
Hugging Face `transformers` Trainer for simplicity.

Usage (from `backend/functions`):
  & .\venv\Scripts\python.exe tools\train\finetune_transformer.py \
      --data-file ML/synonym_training_augmented.jsonl \
      --output-dir ML/transformer_model \
      --epochs 3 --per-device-train-batch-size 8

Note: This will download the base model and may be slow / require GPU to be practical.
"""

from pathlib import Path
import argparse
import os
import json


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--data-file", type=str, default="ML/synonym_training_augmented.jsonl")
    p.add_argument("--model-name", type=str, default="cl-tohoku/bert-base-japanese-whole-word-masking")
    p.add_argument("--output-dir", type=str, default="ML/transformer_model")
    p.add_argument("--epochs", type=int, default=3)
    p.add_argument("--per-device-train-batch-size", type=int, default=8)
    p.add_argument("--per-device-eval-batch-size", type=int, default=16)
    p.add_argument("--lr", type=float, default=2e-5)
    p.add_argument("--seed", type=int, default=42)
    return p.parse_args()


def load_jsonl_labels(data_file: str):
    labels = []
    with open(data_file, "r", encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            ex = json.loads(line)
            labels.append(ex["label"])
    # keep order stable
    uniq = sorted(list(dict.fromkeys(labels)))
    return uniq


def main():
    args = parse_args()
    from datasets import load_dataset, ClassLabel
    from transformers import AutoTokenizer, AutoModelForSequenceClassification, TrainingArguments, Trainer
    import torch

    data_path = Path(args.data_file)
    if not data_path.exists():
        raise SystemExit(f"data file not found: {data_path}")

    labels = load_jsonl_labels(str(data_path))
    num_labels = len(labels)
    print(f"Found {num_labels} labels")

    # 1) load dataset
    ds = load_dataset("json", data_files={"train": str(data_path)})["train"]
    # convert label string to ClassLabel
    class_label = ClassLabel(names=labels)

    def label_map(example):
        example["label"] = class_label.str2int(example["label"])
        return example

    ds = ds.map(label_map)

    # small validation split
    ds = ds.train_test_split(test_size=0.05, seed=args.seed)

    # 2) tokenizer + model
    tokenizer = AutoTokenizer.from_pretrained(args.model_name, use_fast=True)
    model = AutoModelForSequenceClassification.from_pretrained(args.model_name, num_labels=num_labels)

    def preprocess(examples):
        return tokenizer(examples["text"], truncation=True, padding="max_length", max_length=128)

    tokenized = ds.map(preprocess, batched=True)

    # 3) training arguments
    # Use a minimal, widely-compatible set of TrainingArguments to avoid
    # unexpected keyword issues across transformer versions.
    training_args = TrainingArguments(
        output_dir=args.output_dir,
        num_train_epochs=args.epochs,
        per_device_train_batch_size=args.per_device_train_batch_size,
        per_device_eval_batch_size=args.per_device_eval_batch_size,
        learning_rate=args.lr,
        weight_decay=0.01,
        logging_steps=100,
        save_total_limit=2,
        fp16=torch.cuda.is_available(),
    )

    # 4) Trainer
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=tokenized["train"],
        eval_dataset=tokenized["test"],
        tokenizer=tokenizer,
    )

    trainer.train()
    trainer.save_model(args.output_dir)
    print(f"Saved transformer model to {args.output_dir}")


if __name__ == "__main__":
    main()
