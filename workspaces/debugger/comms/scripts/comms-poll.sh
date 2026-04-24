#!/bin/bash
# Usage: comms-poll.sh
# Polls for unread messages addressed to this agent
# Returns JSON array of unread messages sorted by priority
set -e

# Locate config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -n "$COMMS_CONFIG" ] && [ -f "$COMMS_CONFIG" ]; then
  CONFIG="$COMMS_CONFIG"
elif [ -f "$SCRIPT_DIR/comms-config.json" ]; then
  CONFIG="$SCRIPT_DIR/comms-config.json"
elif [ -f "$SCRIPT_DIR/../comms-config.json" ]; then
  CONFIG="$SCRIPT_DIR/../comms-config.json"
else
  echo "ERROR: comms-config.json not found. Set COMMS_CONFIG env var or place config in workspace root." >&2
  exit 1
fi

AGENT_ID=$(cat "$CONFIG" | grep -o '"agent_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
API_URL=$(cat "$CONFIG" | grep -o '"api_url"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
API_KEY=$(cat "$CONFIG" | grep -o '"api_key"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')

if [ -z "$AGENT_ID" ] || [ -z "$API_URL" ]; then
  echo "ERROR: agent_id or api_url not found in config" >&2
  exit 1
fi

curl -s --connect-timeout 10 --max-time 30 ${API_KEY:+-H "X-API-Key: $API_KEY"} "${API_URL}/messages/poll?agent=${AGENT_ID}"
