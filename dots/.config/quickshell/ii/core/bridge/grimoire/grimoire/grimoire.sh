#!/usr/bin/env bash
# grimoire.sh — Grimoire IDE launcher
# Called by Grimoire.qml via Quickshell.Io.Process.

fuser -k 9053/tcp 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/grimoire.py" "$@"
