#!/bin/sh
# Repository-level entrypoint. Keep the real launcher in backend/ so it can
# still be run directly from that directory.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$ROOT/backend/routeos.sh" "$@"
