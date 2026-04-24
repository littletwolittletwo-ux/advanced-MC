#!/bin/bash
# Usage: comms-reply.sh <message_id> <body> [priority]
# Replies to a specific message
set -e

if [ $# -lt 2 ]; then
  echo "Usage: comms-reply.sh <message_id> <body> [priority]" >&2
  exit 1
fi

MESSAGE_ID="$1"
BODY="$2"
PRIORITY="${3:-P2}"

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

# JSON-escape the body
json_escape() {
  if command -v jq &>/dev/null; then
    echo "$1" | jq -Rs .
  elif command -v python3 &>/dev/null; then
    python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$1"
  else
    echo "ERROR: jq or python3 required for JSON escaping" >&2
    exit 1
  fi
}

ESCAPED_BODY=$(json_escape "$BODY")

curl -s --connect-timeout 10 --max-time 30 \
  -X POST "${API_URL}/messages/${MESSAGE_ID}/reply" \
  -H "Content-Type: application/json" \
  ${API_KEY:+-H "X-API-Key: $API_KEY"} \
  -d "{\"from_agent\":\"${AGENT_ID}\",\"body\":${ESCAPED_BODY},\"priority\":\"${PRIORITY}\"}"
