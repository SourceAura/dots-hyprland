#!/usr/bin/env bash
# dms-notify — Push notification to the SiM Syndicate UI

TITLE="${1:-NOTIFICATION}"
MESSAGE="${2:-}"
LEVEL="${3:-info}"
ICON="${4:-◈}"

# Send to the SiM orchestrator via a named pipe or a temporary file
# For now, we'll append to a notification log that the orchestrator polls
NOTIF_LOG="/tmp/sim-notifications.log"

echo "$(date +%s)|$TITLE|$MESSAGE|$LEVEL|$ICON" >> "$NOTIF_LOG"
