#!/bin/zsh
set -euo pipefail

QUERY="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$BASE_DIR/logs/assistant.log"
TRIGGER_LOG="$BASE_DIR/logs/trigger.log"

mkdir -p "$BASE_DIR/logs"

echo "$(date '+%Y-%m-%d %H:%M:%S') [grok] $QUERY" >> "$LOG_FILE"

open -a "Google Chrome" "https://grok.com/" || open "https://grok.com/" || true

set +e
RESULT="$(osascript <<'APPLESCRIPT' 2>&1
tell application "Google Chrome" to activate
delay 0.3
tell application "Google Chrome"
  if (count of windows) is 0 then
    return "no-window"
  end if

  set startedAt to (current date)
  set maxSeconds to 12
  set lastState to "init"

  repeat 30 times
    set js to "
(() => {
  const host = location.hostname || '';
  const href = location.href || '';
  if (!/grok\\.com$/i.test(host) && !/grok\\.com/i.test(href)) return 'waiting-url:' + href.slice(0, 120);
  if (document.readyState !== 'complete' && document.readyState !== 'interactive') return 'waiting-ready:' + document.readyState;

  const textOf = (el) =>
    ((el.innerText || el.textContent || '') + ' ' + (el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('title') || '')).toLowerCase();
  const isVoice = (s) => /(^|\\b)(voice|start voice|microphone|mic|record|talk|speak|audio)(\\b|$)|语音|麦克风|说话|通话|语音对话/.test(s);
  const isNoise = (s) => /搜索|历史|deepsearch|imagine|侧边栏|private mode|私密模式|search|history/.test(s);
  const visible = (el) => {
    const r = el.getBoundingClientRect();
    const st = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && st.visibility !== 'hidden' && st.display !== 'none';
  };

  const selectors = [
    'button[aria-label*=\"voice\" i]',
    'button[aria-label*=\"microphone\" i]',
    'button[title*=\"voice\" i]',
    'button[title*=\"microphone\" i]',
    'button[data-testid*=\"voice\" i]',
    'button[data-testid*=\"mic\" i]'
  ];
  for (const sel of selectors) {
    const el = document.querySelector(sel);
    if (el && visible(el)) {
      el.click();
      return 'clicked-selector:' + sel;
    }
  }

  const candidates = Array.from(document.querySelectorAll('button,[role=\"button\"]'));
  for (const el of candidates) {
    if (!visible(el)) continue;
    const s = textOf(el).replace(/\\s+/g, ' ').trim();
    if (!s || s.length > 80) continue;
    if (isNoise(s)) continue;
    if (isVoice(s)) {
      el.click();
      return 'clicked-text:' + s.slice(0, 100);
    }
  }
  return 'waiting-button';
})();
"
    set lastState to (execute active tab of front window javascript js)
    if lastState starts with "clicked-" then
      return lastState
    end if
    if ((current date) - startedAt) > maxSeconds then
      exit repeat
    end if
    delay 0.4
  end repeat
  return "timeout:" & lastState
end tell
APPLESCRIPT
)"
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [grok-trigger] ${RESULT}" >> "$TRIGGER_LOG"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [grok-trigger] failed: ${RESULT}" >> "$TRIGGER_LOG"
fi
