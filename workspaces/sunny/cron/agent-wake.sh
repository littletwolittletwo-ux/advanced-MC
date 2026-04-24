#!/bin/bash
# agent-wake.sh — wake Sunny (Master VA) to process bus messages
# Called by agent-poller.sh when unread messages arrive.

WORKSPACE="${AGENT_WORKSPACE:-$(dirname "${BASH_SOURCE[0]}")/..}"
LOG_DIR="${AGENT_LOG_DIR:-$WORKSPACE/logs}"
LOG_FILE="$LOG_DIR/wake.log"
LOCK_FILE="$WORKSPACE/.wake.lock"

mkdir -p "$LOG_DIR"
set -e
trap 'rm -f "$LOCK_FILE"' EXIT

CONFIG_FILE="$WORKSPACE/comms-config.json"
AGENT_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['agent_id'])")
PRIMARY_CHANNEL=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['channels']['primary'])")

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Wake for $AGENT_ID" >> "$LOG_FILE"

WAKE_PROMPT="Unread messages on the bus. Process them now.

1. Poll: bash $WORKSPACE/comms/scripts/comms-poll.sh
2. For each message:
   - If it is a NEW TASK for a sub-agent (build request, bug report, debug task):
     Route it to the correct island channel:
       Build tasks → bash $WORKSPACE/comms/scripts/comms-send.sh dm:sunny-builder 'NEW TASK: <full task details>' P1
       Debug tasks → bash $WORKSPACE/comms/scripts/comms-send.sh dm:sunny-debugger 'NEW TASK: <full task details>' P1
     Then acknowledge to the sender on $PRIMARY_CHANNEL.
   - If it is a status update or completion report from a sub-agent:
     Acknowledge and relay the result to the operator on $PRIMARY_CHANNEL.
   - If it is a direct question or request for Sunny:
     Respond directly on $PRIMARY_CHANNEL.
   - Acknowledge immediately per RULES.md Rule 1: 'Got it — <restate> — starting now.'
   - Mark each message read after processing: bash $WORKSPACE/comms/scripts/comms-read.sh <message-id>
3. If you need context: bash $WORKSPACE/comms/scripts/comms-request-context.sh $PRIMARY_CHANNEL '<what you need>'
4. Exit when all messages processed.

Load only what you need — your SOUL.md is already loaded. Don't re-read phase files unless you're entering a phase."

cd "$WORKSPACE"
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$HOME/Library/pnpm:$HOME/.npm-global/bin:$PATH"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Invoking claude --print for $AGENT_ID" >> "$LOG_FILE"

echo "$WAKE_PROMPT" | claude --print --dangerously-skip-permissions >> "$LOG_FILE" 2>&1
EXIT=$?

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sleep $AGENT_ID (exit=$EXIT)" >> "$LOG_FILE"
