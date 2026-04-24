#!/bin/bash
# comms-request-context.sh — sub-agent asks their CEO for context
# Usage: comms-request-context.sh <channel_id> "<what you need>"

set -e

CHANNEL_ID="${1:?Usage: comms-request-context.sh <channel_id> \"<what you need>\"}"
REQUEST="${2:?Describe what context you need}"

WORKSPACE="$(dirname "${BASH_SOURCE[0]}")/../.."
CONFIG_FILE="$WORKSPACE/comms-config.json"

read_json() { python3 -c "import json; print(json.load(open('$1')).get('$2',''))"; }

AGENT_ID=$(read_json "$CONFIG_FILE" "agent_id")
API_URL=$(read_json "$CONFIG_FILE" "api_url")
API_KEY=$(read_json "$CONFIG_FILE" "api_key")

BODY="CONTEXT REQUEST

I need context to execute safely. Specifically:

$REQUEST

Please reply with the context I need, then I'll proceed."

# Send the context request via comms-send.sh
bash "$WORKSPACE/comms/scripts/comms-send.sh" "$CHANNEL_ID" "$BODY" "P1"

echo "Context request sent to $CHANNEL_ID. Poll again after ~30s for the response."
