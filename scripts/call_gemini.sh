#!/bin/zsh
set -euo pipefail

QUERY="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$BASE_DIR/logs/assistant.log"

echo "$(date '+%Y-%m-%d %H:%M:%S') [gemini] $QUERY" >> "$LOG_FILE"
open -a "Google Chrome" "https://gemini.google.com/" || open "https://gemini.google.com/" || true
