#!/bin/zsh
set -euo pipefail

QUERY="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$BASE_DIR/logs/assistant.log"

echo "$(date '+%Y-%m-%d %H:%M:%S') [doubao] $QUERY" >> "$LOG_FILE"
osascript <<'APPLESCRIPT'
tell application "System Events"
    -- Global shortcut: Cmd + Period
    key code 47 using {command down}
end tell
APPLESCRIPT
