#!/bin/zsh
set -euo pipefail

QUERY="${1:-给豆包打电话}"
JSON_PAYLOAD="$(python3 -c 'import json,sys; print(json.dumps({"query": sys.argv[1]}, ensure_ascii=False))' "$QUERY")"
curl -sS -X POST http://127.0.0.1:8787/route \
  -H 'Content-Type: application/json' \
  -d "$JSON_PAYLOAD" >/dev/null 2>&1 || true
