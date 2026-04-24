#!/bin/bash
# Usage: comms-distill.sh <channel_id> <marker_message_id>
# Returns thread as a single text block for distillation
set -e

if [ $# -lt 2 ]; then
  echo "Usage: comms-distill.sh <channel_id> <marker_message_id>" >&2
  exit 1
fi

CHANNEL_ID="$1"
MARKER_ID="$2"

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

curl -s --connect-timeout 10 --max-time 30 ${API_KEY:+-H "X-API-Key: $API_KEY"} "${API_URL}/messages/distill/${CHANNEL_ID}/${MARKER_ID}"
