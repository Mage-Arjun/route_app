#!/bin/sh
set -eu

# Portable RouteOS launcher for Linux, macOS, WSL and Git Bash.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT"
VENV="$ROOT/.venv"

if command -v python3 >/dev/null 2>&1; then SYSTEM_PYTHON=$(command -v python3)
elif command -v python >/dev/null 2>&1; then SYSTEM_PYTHON=$(command -v python)
else echo "RouteOS requires Python 3.11 or newer (python3/python not found)." >&2; exit 1
fi

# Windows virtual environments use Scripts; Unix environments use bin.
if [ -x "$VENV/bin/python" ]; then PYTHON="$VENV/bin/python"; VENV_BIN="$VENV/bin"
elif [ -x "$VENV/Scripts/python.exe" ]; then PYTHON="$VENV/Scripts/python.exe"; VENV_BIN="$VENV/Scripts"
elif [ -x "$VENV/Scripts/python" ]; then PYTHON="$VENV/Scripts/python"; VENV_BIN="$VENV/Scripts"
else
  "$SYSTEM_PYTHON" -m venv "$VENV"
  if [ -x "$VENV/bin/python" ]; then PYTHON="$VENV/bin/python"; VENV_BIN="$VENV/bin"
  elif [ -x "$VENV/Scripts/python.exe" ]; then PYTHON="$VENV/Scripts/python.exe"; VENV_BIN="$VENV/Scripts"
  else echo "Could not locate the Python virtual environment executable." >&2; exit 1; fi
fi

if [ ! -f "$VENV/.routeos_requirements_ready" ] || [ requirements.txt -nt "$VENV/.routeos_requirements_ready" ]; then
  "$PYTHON" -m pip install -q -r requirements.txt
  : > "$VENV/.routeos_requirements_ready"
fi

mkdir -p data
[ -f .env ] || { [ -f .env.example ] && cp .env.example .env || true; }
HOST=${HOST:-0.0.0.0}; PORT=${PORT:-8000}
TUI_BACKEND_URL=${TUI_BACKEND_URL:-http://127.0.0.1:$PORT}
PYTHONPATH="$ROOT${PYTHONPATH:+:$PYTHONPATH}"
export HOST PORT TUI_BACKEND_URL PYTHONPATH

# Best-effort cleanup; tools are optional and only RouteOS processes are matched.
stop_existing() {
  if command -v pgrep >/dev/null 2>&1; then
    PIDS=$(pgrep -f "$ROOT/.venv.*\(uvicorn main:app\|python.*tui.app\)" 2>/dev/null || true)
    [ -z "$PIDS" ] || { echo "Stopping existing RouteOS process(es): $PIDS" >&2; kill $PIDS 2>/dev/null || true; }
  fi
  PIDS=""
  if command -v fuser >/dev/null 2>&1; then PIDS=$(fuser -n tcp "$PORT" 2>/dev/null || true)
  elif command -v lsof >/dev/null 2>&1; then PIDS=$(lsof -t -n -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true); fi
  [ -z "$PIDS" ] || { echo "Stopping listener(s) on TCP $PORT: $PIDS" >&2; kill $PIDS 2>/dev/null || true; }
}
stop_existing

"$PYTHON" -m alembic upgrade head
if "$PYTHON" -c 'from config import settings; raise SystemExit(0 if settings.SEED_DEMO_DATA else 1)'; then "$PYTHON" seed.py; fi

# Optional import: configure BUILD1_DB explicitly or use the historical sibling path.
BUILD1_DB=${BUILD1_DB:-}
[ -n "$BUILD1_DB" ] || { [ -f "$ROOT/../Build 1/backend/route_app.db" ] && BUILD1_DB="$ROOT/../Build 1/backend/route_app.db" || true; }
if [ -n "$BUILD1_DB" ] && [ -f "$BUILD1_DB" ]; then "$PYTHON" import_build1.py "$BUILD1_DB"; fi

LOG_FILE="$ROOT/data/server.log"
"$PYTHON" -m uvicorn main:app --host "$HOST" --port "$PORT" >"$LOG_FILE" 2>&1 &
SERVER_PID=$!
cleanup() { kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; }
trap cleanup EXIT INT TERM HUP

healthy() { "$PYTHON" - "$PORT" <<'PY'
import sys, urllib.request
try:
    with urllib.request.urlopen(f"http://127.0.0.1:{int(sys.argv[1])}/health", timeout=1) as r: raise SystemExit(0 if r.status == 200 else 1)
except Exception: raise SystemExit(1)
PY
}
i=0
while [ "$i" -lt 40 ]; do healthy && break; i=$((i + 1)); sleep 0.25; done
if ! healthy; then echo "Backend health check failed; see $LOG_FILE" >&2; exit 1; fi

echo "RouteOS backend started on $HOST:$PORT"
echo "API docs: http://127.0.0.1:$PORT/docs"
echo "Server log: $LOG_FILE"
exec env TUI_BACKEND_URL="$TUI_BACKEND_URL" PYTHONPATH="$PYTHONPATH" "$PYTHON" -m tui.app
