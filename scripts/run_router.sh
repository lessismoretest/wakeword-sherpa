#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(cd "$SCRIPT_DIR/.." && pwd)"
if [ ! -d .venv ]; then
  /usr/bin/python3 -m venv .venv
fi
source .venv/bin/activate
if ! python -c 'import fastapi, uvicorn' >/dev/null 2>&1; then
  pip install -q fastapi uvicorn
fi
exec ./.venv/bin/uvicorn server:app --host 0.0.0.0 --port 8787
