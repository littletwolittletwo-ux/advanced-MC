#!/bin/bash
# Usage: comms-search.sh <query>
# Searches messages across all agent's channels
set -e

if [ $# -lt 1 ]; then
  echo "Usage: comms-search.sh <query>" >&2
  exit 1
fi

QUERY="$1"

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

# URL-encode the query
if command -v python3 &>/dev/null; then
  ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")
elif command -v jq &>/dev/null; then
  ENCODED=$(printf '%s' "$QUERY" | jq -sRr @uri)
else
  # Basic encoding: replace spaces with +
  ENCODED=$(echo "$QUERY" | sed 's/ /+/g')
fi

curl -s --connect-timeout 10 --max-time 30 ${API_KEY:+-H "X-API-Key: $API_KEY"} "${API_URL}/messages/search?q=${ENCODED}&agent=${AGENT_ID}"
