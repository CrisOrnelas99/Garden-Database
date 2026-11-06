#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3.9 or newer is required. Install Python, then run this script again." >&2
  exit 1
fi

if [[ ! -x ".venv/bin/python" ]]; then
  python3 -m venv .venv
fi

.venv/bin/python -m pip install -r requirements.txt

read -r -s -p "Paste the Supabase Session pooler URI (input is hidden): " DATABASE_URL
echo
if [[ -z "$DATABASE_URL" ]]; then
  echo "No database URI entered." >&2
  exit 1
fi
export DATABASE_URL
trap 'unset DATABASE_URL' EXIT

if command -v open >/dev/null 2>&1; then
  open http://localhost:8000
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open http://localhost:8000 >/dev/null 2>&1 &
fi

.venv/bin/python app.py
