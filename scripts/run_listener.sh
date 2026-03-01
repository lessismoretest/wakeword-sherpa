#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
BASE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$BASE_DIR/logs/wake_listener.log"
mkdir -p "$BASE_DIR/logs"
exec >> "$LOG_FILE" 2>&1

echo "==== run_listener start $(date '+%F %T') ===="
echo "PWD(before)=$(pwd) HOME=${HOME:-} PATH=${PATH:-}"

MODEL_DIR="$BASE_DIR/models/sherpa-onnx-kws-zipformer-zh-en-3M-2025-12-20"
KEYWORDS_FILE="$BASE_DIR/models/keywords_current.txt"

DOUBAO_PHRASES="${DOUBAO_PHRASES:-豆包豆包,嘿豆包,嘿，豆包}"
GROK_PHRASES="${GROK_PHRASES:-hey grok,嘿 grok}"
JARVIS_PHRASES="${JARVIS_PHRASES:-Jarvis,Javis,hey jarvis,嘿Jarvis,贾维斯,杰维斯}"
CHATGPT_PHRASES="${CHATGPT_PHRASES:-hey chatgpt,chatgpt,chat gpt,hey gpt,gpt,嘿，ChatGPT,嘿chatgpt,嘿 gpt,嘿gpt,鸡皮提,嘿鸡皮提,嘿 吉皮提}"
GEMINI_PHRASES="${GEMINI_PHRASES:-hey gemini}"
INPUT_DEVICE="${INPUT_DEVICE:-MacBook Pro麦克风}"
BEEP_CMD="${BEEP_CMD:-}"
TRIGGER_CMD="${TRIGGER_CMD:-$BASE_DIR/scripts/on_detect.sh}"
KW_SCORE="${KW_SCORE:-1.2}"
KW_THRESHOLD="${KW_THRESHOLD:-0.04}"
KW_TRAILING_BLANKS="${KW_TRAILING_BLANKS:-1}"
AUDIO_LOG_INTERVAL="${AUDIO_LOG_INTERVAL:-3.0}"

cd "$BASE_DIR"
echo "PWD(after)=$(pwd)"

PYTHON_BIN="${PYTHON_BIN:-}"
if [ -z "$PYTHON_BIN" ]; then
  if [ -x /opt/homebrew/bin/python3 ]; then
    PYTHON_BIN="/opt/homebrew/bin/python3"
  else
    PYTHON_BIN="$(command -v python3)"
  fi
fi
echo "python_bin=$PYTHON_BIN"

RECREATE_VENV=0
if [ ! -d .venv ]; then
  RECREATE_VENV=1
elif [ ! -x .venv/bin/python ]; then
  RECREATE_VENV=1
else
  VENV_PY_INFO="$(./.venv/bin/python - <<'PY'
import sys
base = getattr(sys, "_base_executable", "")
print(f"{sys.version_info.major}.{sys.version_info.minor}|{base}")
PY
)"
  VENV_PY_VER="${VENV_PY_INFO%%|*}"
  VENV_BASE_EXE="${VENV_PY_INFO#*|}"
  if [[ "$VENV_BASE_EXE" == *"/Xcode.app/"* ]] || [[ "$VENV_PY_VER" == "3.9" ]]; then
    RECREATE_VENV=1
  fi
fi

if [ "$RECREATE_VENV" -eq 1 ]; then
  echo "creating venv with $PYTHON_BIN"
  rm -rf .venv
  "$PYTHON_BIN" -m venv .venv
fi

source .venv/bin/activate
python -V || true
python -m pip --version || true
python -m pip install -q sherpa-onnx sounddevice pypinyin numpy

if [ ! -d "$MODEL_DIR" ]; then
  "$BASE_DIR/scripts/bootstrap_model.sh"
fi

rm -f "$KEYWORDS_FILE"
for phrase in ${(s:,:)DOUBAO_PHRASES}; do
  python scripts/build_keywords.py --phrase "$phrase" --label "DOUBAO" --out "$KEYWORDS_FILE" --append
done
for phrase in ${(s:,:)GROK_PHRASES}; do
  python scripts/build_keywords.py --phrase "$phrase" --label "GROK" --out "$KEYWORDS_FILE" --append
done
for phrase in ${(s:,:)JARVIS_PHRASES}; do
  python scripts/build_keywords.py --phrase "$phrase" --label "JARVIS" --out "$KEYWORDS_FILE" --append
done
for phrase in ${(s:,:)CHATGPT_PHRASES}; do
  python scripts/build_keywords.py --phrase "$phrase" --label "CHATGPT" --out "$KEYWORDS_FILE" --append
done
for phrase in ${(s:,:)GEMINI_PHRASES}; do
  python scripts/build_keywords.py --phrase "$phrase" --label "GEMINI" --out "$KEYWORDS_FILE" --append
done

# OpenClaw Telegram wakewords (use dedicated labels so we can send original wake text).
python scripts/build_keywords.py --phrase "嘿 小龙虾" --label "OC_XIAOLONGXIA" --out "$KEYWORDS_FILE" --append
python scripts/build_keywords.py --phrase "嘿 龙虾" --label "OC_LONGXIA" --out "$KEYWORDS_FILE" --append
python scripts/build_keywords.py --phrase "嘿 大龙虾" --label "OC_DALONGXIA" --out "$KEYWORDS_FILE" --append
python scripts/build_keywords.py --phrase "嘿 openclaw" --label "OC_OPENCLAW" --out "$KEYWORDS_FILE" --append
python scripts/build_keywords.py --phrase "嘿，兄弟" --label "OC_XIONGDI" --out "$KEYWORDS_FILE" --append

cmd=(
  python scripts/wake_listener.py
  --tokens "$MODEL_DIR/tokens.txt"
  --encoder "$MODEL_DIR/encoder-epoch-13-avg-2-chunk-16-left-64.onnx"
  --decoder "$MODEL_DIR/decoder-epoch-13-avg-2-chunk-16-left-64.onnx"
  --joiner "$MODEL_DIR/joiner-epoch-13-avg-2-chunk-16-left-64.onnx"
  --keywords-file "$KEYWORDS_FILE"
  --keywords-score "$KW_SCORE"
  --keywords-threshold "$KW_THRESHOLD"
  --num-trailing-blanks "$KW_TRAILING_BLANKS"
  --cooldown-seconds 2.5
  --trigger-cmd "$TRIGGER_CMD"
  --input-device "$INPUT_DEVICE"
  --audio-log-interval "$AUDIO_LOG_INTERVAL"
)

if [ -n "${BEEP_CMD}" ]; then
  cmd+=(--beep-cmd "$BEEP_CMD")
fi

echo "starting listener with trigger=$TRIGGER_CMD input_device=$INPUT_DEVICE kw_score=$KW_SCORE kw_threshold=$KW_THRESHOLD"
exec "${cmd[@]}"
