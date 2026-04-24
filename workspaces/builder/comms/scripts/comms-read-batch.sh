#!/bin/bash
# Usage: comms-read-batch.sh <message_id_1> <message_id_2> ...
# Marks multiple messages as read
set -e

if [ $# -lt 1 ]; then
  echo "Usage: comms-read-batch.sh <message_id_1> [message_id_2] ..." >&2
  exit 1
fi

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

AGENT_ID=$(cat "$CONFIG" | grep -o '"agent_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
API_URL=$(cat "$CONFIG" | grep -o '"api_url"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
API_KEY=$(cat "$CONFIG" | grep -o '"api_key"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')

# Build JSON array from arguments
IDS=""
for id in "$@"; do
  if [ -n "$IDS" ]; then
    IDS="${IDS},"
  fi
  IDS="${IDS}\"${id}\""
done

curl -s --connect-timeout 10 --max-time 30 \
  -X POST "${API_URL}/messages/read-batch" \
  -H "Content-Type: application/json" \
  ${API_KEY:+-H "X-API-Key: $API_KEY"} \
  -d "{\"agent\":\"${AGENT_ID}\",\"message_ids\":[${IDS}]}"
