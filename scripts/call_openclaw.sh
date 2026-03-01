#!/bin/zsh
set -euo pipefail

WAKE_TEXT="${1:-唤醒词触发}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$BASE_DIR/logs/assistant.log"
TRIGGER_LOG="$BASE_DIR/logs/trigger.log"
OPENCLAW_TARGET="${OPENCLAW_TARGET:-@xiaolin_clawdbot}"
WHISPER_CLI_BIN="${WHISPER_CLI_BIN:-/opt/homebrew/bin/whisper-cli}"
WHISPER_MODEL="${WHISPER_MODEL:-}"
CAPTURE_SECONDS="${OPENCLAW_CAPTURE_SECONDS:-4.5}"
CAPTURE_DELAY_SECONDS="${OPENCLAW_CAPTURE_DELAY_SECONDS:-0.15}"
TMP_WAV="${TMPDIR:-/tmp}/openclaw_tail_$$.wav"
PREP_LOG="${TMPDIR:-/tmp}/openclaw_prep_$$.log"

mkdir -p "$BASE_DIR/logs"
echo "$(date '+%Y-%m-%d %H:%M:%S') [telegram] $WAKE_TEXT" >> "$LOG_FILE"

select_python() {
  if [ -x "$BASE_DIR/.venv/bin/python3" ]; then
    echo "$BASE_DIR/.venv/bin/python3"
    return
  fi
  if command -v python3 >/dev/null 2>&1; then
    command -v python3
    return
  fi
  echo ""
}

resolve_model() {
  if [ -n "$WHISPER_MODEL" ] && [ -f "$WHISPER_MODEL" ]; then
    echo "$WHISPER_MODEL"
    return
  fi

  local candidates=(
    "/Users/lessismore/Library/Application Support/MacWhisper/models/ggml-model-whisper-turbo.bin"
    "/Users/lessismore/Library/Group Containers/CUR5DR6HMG.com.theoasis.TalkTastic/Whisper/ggml-large-distil.bin"
  )

  local c
  for c in "${candidates[@]}"; do
    if [ -f "$c" ]; then
      echo "$c"
      return
    fi
  done

  echo ""
}

capture_tail_audio() {
  local py="$1"
  [ -n "$py" ] || return 1

  "$py" - "$TMP_WAV" "$CAPTURE_SECONDS" "$CAPTURE_DELAY_SECONDS" <<'PY' >/dev/null 2>&1
import sys
import time
import wave

import numpy as np
import sounddevice as sd

wav_path = sys.argv[1]
duration = float(sys.argv[2])
delay = float(sys.argv[3])
sample_rate = 16000

time.sleep(max(delay, 0.0))
audio = sd.rec(int(sample_rate * max(duration, 0.5)), samplerate=sample_rate, channels=1, dtype="float32")
sd.wait()
pcm = np.clip(audio * 32767.0, -32768, 32767).astype(np.int16)

with wave.open(wav_path, "wb") as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(sample_rate)
    wf.writeframes(pcm.tobytes())
PY
}

extract_tail_text() {
  local py="$1"
  local wake="$2"
  local raw="$3"
  [ -n "$py" ] || return 1

  "$py" - "$wake" "$raw" <<'PY'
import re
import sys

wake = sys.argv[1].strip()
text = sys.argv[2].strip()

if not text:
    print("")
    raise SystemExit(0)

# Remove leading timestamps or metadata if any.
text = re.sub(r"^\[[^\]]+\]\s*", "", text).strip()

head_patterns = [
    r"^[\s,，。.!！？?、]*嘿[\s,，。.!！？?、]*小龙虾[\s,，。.!！？?、]*",
    r"^[\s,，。.!！？?、]*嘿[\s,，。.!！？?、]*龙虾[\s,，。.!！？?、]*",
    r"^[\s,，。.!！？?、]*嘿[\s,，。.!！？?、]*大龙虾[\s,，。.!！？?、]*",
    r"^[\s,，。.!！？?、]*嘿[\s,，。.!！？?、]*open\s*claw[\s,，。.!！？?、]*",
    r"^[\s,，。.!！？?、]*嘿[\s,，。.!！？?、]*兄弟[\s,，。.!！？?、]*",
]

tail = text
for p in head_patterns:
    new_tail = re.sub(p, "", tail, flags=re.IGNORECASE)
    if new_tail != tail:
        tail = new_tail
        break

tail = tail.strip()
if not tail and wake:
    # If ASR only got wake phrase, keep empty and let caller fallback.
    tail = ""

print(tail)
PY
}

prepare_message_text() {
  local py
  py="$(select_python)"
  local model_path
  model_path="$(resolve_model)"

  if [ -z "$py" ] || [ ! -x "$WHISPER_CLI_BIN" ] || [ -z "$model_path" ]; then
    echo "$WAKE_TEXT"
    return
  fi

  if ! capture_tail_audio "$py"; then
    echo "$WAKE_TEXT"
    return
  fi

  if [ ! -s "$TMP_WAV" ]; then
    echo "$WAKE_TEXT"
    return
  fi

  local raw_text
  raw_text="$("$WHISPER_CLI_BIN" -m "$model_path" -l zh -f "$TMP_WAV" -nt -np 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
  if [ -z "$raw_text" ]; then
    echo "$WAKE_TEXT"
    return
  fi

  local tail_text
  tail_text="$(extract_tail_text "$py" "$WAKE_TEXT" "$raw_text" 2>/dev/null || true)"
  if [ -n "$tail_text" ]; then
    echo "$tail_text"
  else
    echo "$WAKE_TEXT"
  fi
}

previous_clipboard="$(pbpaste 2>/dev/null || true)"

open -a "Telegram" >/dev/null 2>&1 || true

# Prepare Telegram target chat immediately while we are still transcribing.
(
  osascript - "$OPENCLAW_TARGET" <<'APPLESCRIPT'
on run argv
  set targetName to item 1 of argv
  tell application "Telegram" to activate
  delay 0.25
  tell application "System Events"
    tell process "Telegram"
      set frontmost to true
    end tell
    keystroke "k" using {command down}
    delay 0.15
    keystroke targetName
    delay 0.2
    key code 36
  end tell
  return "ready:" & targetName
end run
APPLESCRIPT
) >"$PREP_LOG" 2>&1 &
PREP_PID=$!

MESSAGE_TEXT="$(prepare_message_text)"
printf '%s' "$MESSAGE_TEXT" | pbcopy

wait "$PREP_PID"
PREP_STATUS=$?
PREP_RESULT="$(cat "$PREP_LOG" 2>/dev/null || true)"

set +e
if [ "$PREP_STATUS" -eq 0 ]; then
  RESULT="$(osascript <<'APPLESCRIPT' 2>&1
tell application "Telegram" to activate
delay 0.12
tell application "System Events"
  tell process "Telegram"
    set frontmost to true
  end tell
  keystroke "v" using {command down}
  delay 0.08
  key code 36
end tell
return "sent"
APPLESCRIPT
)"
  STATUS=$?
else
  RESULT="$(osascript - "$OPENCLAW_TARGET" <<'APPLESCRIPT' 2>&1
on run argv
  set targetName to item 1 of argv
  tell application "Telegram" to activate
  delay 0.3
  tell application "System Events"
    tell process "Telegram"
      set frontmost to true
    end tell
    keystroke "k" using {command down}
    delay 0.15
    keystroke targetName
    delay 0.2
    key code 36
    delay 0.2
    keystroke "v" using {command down}
    delay 0.08
    key code 36
  end tell
  return "sent:" & targetName
end run
APPLESCRIPT
)"
  STATUS=$?
fi
set -e

if [ "$STATUS" -eq 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [telegram-trigger] ${RESULT} prep=${PREP_STATUS} wake=${WAKE_TEXT} sent=${MESSAGE_TEXT}" >> "$TRIGGER_LOG"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [telegram-trigger] failed: ${RESULT} prep=${PREP_STATUS} prep_result=${PREP_RESULT}" >> "$TRIGGER_LOG"
fi

sleep 0.2
printf '%s' "$previous_clipboard" | pbcopy
rm -f "$TMP_WAV" >/dev/null 2>&1 || true
rm -f "$PREP_LOG" >/dev/null 2>&1 || true
