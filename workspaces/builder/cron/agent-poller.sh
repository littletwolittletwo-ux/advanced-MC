#!/bin/bash
# agent-poller.sh — check for unread messages, wake agent if any
# Runs every 30s via system cron.

set -e

# ---- Config ----
WORKSPACE="${AGENT_WORKSPACE:-$(dirname "${BASH_SOURCE[0]}")/..}"
CONFIG_FILE="$WORKSPACE/comms-config.json"
LOG_DIR="${AGENT_LOG_DIR:-$WORKSPACE/logs}"
LOG_FILE="$LOG_DIR/poller.log"

mkdir -p "$LOG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: comms-config.json not found at $CONFIG_FILE" >> "$LOG_FILE"
  exit 1
fi

# Extract fields with python (more portable than jq)
read_json() {
  python3 -c "import json; d=json.load(open('$1')); print(d.get('$2',''))" 2>/dev/null
}

AGENT_ID=$(read_json "$CONFIG_FILE" "agent_id")
API_URL=$(read_json "$CONFIG_FILE" "api_url")
API_KEY=$(read_json "$CONFIG_FILE" "api_key")

if [ -z "$AGENT_ID" ] || [ -z "$API_URL" ] || [ -z "$API_KEY" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Missing config values" >> "$LOG_FILE"
  exit 1
fi

# ---- Poll ----
RESPONSE=$(curl -s -m 10 -w "\n%{http_code}" \
  -H "X-API-Key: $API_KEY" \
  "$API_URL/messages/poll?agent=$AGENT_ID")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Poll failed HTTP $HTTP_CODE" >> "$LOG_FILE"
  exit 0
fi

# Count unreads
UNREAD_COUNT=$(echo "$BODY" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        msgs = data
    else:
        msgs = data.get('unread', data.get('messages', []))
    print(len(msgs))
except:
    print(0)
")

if [ "$UNREAD_COUNT" = "0" ]; then
  # No messages — silent exit
  exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] $UNREAD_COUNT unread message(s) — waking agent" >> "$LOG_FILE"

# ---- Check lock (prevent overlapping wakes) ----
LOCK_FILE="$WORKSPACE/.wake.lock"
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE")
  if kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Already awake (PID $LOCK_PID) — skipping" >> "$LOG_FILE"
    exit 0
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stale lock — removing" >> "$LOG_FILE"
    rm -f "$LOCK_FILE"
  fi
fi

# ---- Wake ----
WAKE_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/agent-wake.sh"
if [ ! -x "$WAKE_SCRIPT" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: agent-wake.sh not found or not executable" >> "$LOG_FILE"
  exit 1
fi

# Run wake synchronously — forked children die under launchd process group management.
# launchd StartInterval won't re-trigger while this process is still running, so blocking is fine.
echo "$$" > "$LOCK_FILE"
"$WAKE_SCRIPT"
WAKE_EXIT=$?
rm -f "$LOCK_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Wake finished (exit=$WAKE_EXIT)" >> "$LOG_FILE"
