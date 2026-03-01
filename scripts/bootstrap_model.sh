#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODEL_DIR="$BASE_DIR/models"
MODEL_NAME="sherpa-onnx-kws-zipformer-zh-en-3M-2025-12-20"
MODEL_TAR="$MODEL_NAME.tar.bz2"
MODEL_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/kws-models/$MODEL_TAR"

mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"

if [ ! -f "$MODEL_TAR" ]; then
  echo "[bootstrap] downloading $MODEL_TAR"
  curl -L --fail -o "$MODEL_TAR" "$MODEL_URL"
fi

if [ ! -d "$MODEL_NAME" ]; then
  echo "[bootstrap] extracting $MODEL_TAR"
  tar -xjf "$MODEL_TAR"
fi

echo "[bootstrap] model ready: $MODEL_DIR/$MODEL_NAME"
