#!/bin/zsh
set -euo pipefail

LABEL="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
JARVIS_AUDIO="${JARVIS_AUDIO:-$BASE_DIR/Jarvis 声音.mp3}"
JARVIS_ASSISTANT="${JARVIS_ASSISTANT:-grok}"

case "${LABEL}" in
  GROK*)
    "$SCRIPT_DIR/call_grok.sh" "唤醒触发Grok"
    ;;
  JARVIS*)
    if [ -f "$JARVIS_AUDIO" ]; then
      afplay "$JARVIS_AUDIO" >/dev/null 2>&1 &
    fi

    case "${JARVIS_ASSISTANT:l}" in
      doubao)
        "$SCRIPT_DIR/call_doubao.sh" "Jarvis唤醒触发豆包"
        ;;
      gemini)
        "$SCRIPT_DIR/call_gemini.sh" "Jarvis唤醒触发Gemini"
        ;;
      chatgpt)
        "$SCRIPT_DIR/call_chatgpt.sh" "Jarvis唤醒触发ChatGPT"
        ;;
      grok|*)
        "$SCRIPT_DIR/call_grok.sh" "Jarvis唤醒触发Grok"
        ;;
    esac
    ;;
  DOUBAO*)
    "$SCRIPT_DIR/call_doubao.sh" "唤醒触发豆包"
    ;;
  CHATGPT*)
    "$SCRIPT_DIR/call_chatgpt.sh" "唤醒触发ChatGPT"
    ;;
  GEMINI*)
    "$SCRIPT_DIR/call_gemini.sh" "唤醒触发Gemini"
    ;;
  OC_XIAOLONGXIA*)
    "$SCRIPT_DIR/call_openclaw.sh" "嘿 小龙虾"
    ;;
  OC_LONGXIA*)
    "$SCRIPT_DIR/call_openclaw.sh" "嘿 龙虾"
    ;;
  OC_DALONGXIA*)
    "$SCRIPT_DIR/call_openclaw.sh" "嘿 大龙虾"
    ;;
  OC_OPENCLAW*)
    "$SCRIPT_DIR/call_openclaw.sh" "嘿 openclaw"
    ;;
  OC_XIONGDI*)
    "$SCRIPT_DIR/call_openclaw.sh" "嘿，兄弟"
    ;;
  *)
    # Fallback to doubao on unknown label.
    "$SCRIPT_DIR/call_doubao.sh" "唤醒触发豆包"
    ;;
esac
