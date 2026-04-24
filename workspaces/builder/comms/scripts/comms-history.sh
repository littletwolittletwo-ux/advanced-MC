#!/bin/bash
# Usage: comms-history.sh <channel_id> [limit]
# Returns message history for a channel (default: last 50)
set -e

if [ $# -lt 1 ]; then
  echo "Usage: comms-history.sh <channel_id> [limit]" >&2
  exit 1
fi

CHANNEL_ID="$1"
LIMIT="${2:-50}"

# Locate config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -n "$COMMS_CONFIG" ] && [ -f "$COMMS_CONFIG" ]; then
  CONFIG="$COMMS_CONFIG"
elif [ -f "$SCRIPT_DIR/comms-config.json" ]; then
  CONFIG="$SCRIPT_DIR/comms-config.json"
elif [ -f "$SCRIPT_DIR/../comms-config.json" ]; then
  CONFIG="$SCRIPT_DIR/../comms-config.json"
else
  echo "ERROR: comms-config.json not found." >&2
  exit 1
fi

API_URL=$(cat "$CONFIG" | grep -o '"api_url"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
API_KEY=$(cat "$CONFIG" | grep -o '"api_key"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')

curl -s --connect-timeout 10 --max-time 30 ${API_KEY:+-H "X-API-Key: $API_KEY"} "${API_URL}/messages/history/${CHANNEL_ID}?limit=${LIMIT}"
