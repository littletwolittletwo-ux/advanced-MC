#!/bin/bash
# Usage: comms-thread.sh <channel_id>
# Returns messages in the current thread (from latest NEW TASK marker)
set -e

if [ $# -lt 1 ]; then
  echo "Usage: comms-thread.sh <channel_id>" >&2
  exit 1
fi

CHANNEL_ID="$1"

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

curl -s --connect-timeout 10 --max-time 30 ${API_KEY:+-H "X-API-Key: $API_KEY"} "${API_URL}/messages/thread/${CHANNEL_ID}"
