#!/bin/bash
# agent-wake.sh — wake this OpenClaw subagent to process bus messages
set -e

WORKSPACE="${AGENT_WORKSPACE:-$(dirname "${BASH_SOURCE[0]}")/..}"
CONFIG_FILE="$WORKSPACE/comms-config.json"
LOG_DIR="${AGENT_LOG_DIR:-$WORKSPACE/logs}"
LOG_FILE="$LOG_DIR/wake.log"
LOCK_FILE="$WORKSPACE/.wake.lock"

mkdir -p "$LOG_DIR"
trap 'rm -f "$LOCK_FILE"' EXIT

AGENT_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['agent_id'])")
PRIMARY_CHANNEL=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['channels']['primary'])")

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Wake for $AGENT_ID" >> "$LOG_FILE"

WAKE_PROMPT="Unread messages on the bus. Process them now.

1. Poll: bash $WORKSPACE/comms/scripts/comms-poll.sh
2. For each message:
   - If it starts with NEW TASK: enter the correct phase per your SOUL/phase files
     (Builder: PLAN → EXECUTE → REVIEW. Debugger: TRIAGE → INVESTIGATE → VERIFY.)
   - If it's a follow-up: get context via comms-thread.sh $PRIMARY_CHANNEL
   - Acknowledge immediately per RULES.md Rule 1: 'Got it — <restate> — starting now.'
   - Execute per your role
   - Report result back via: bash $WORKSPACE/comms/scripts/comms-send.sh $PRIMARY_CHANNEL '<body>' <P0|P1|P2>
   - Mark read: bash $WORKSPACE/comms/scripts/comms-read.sh <message-id>
3. If you need context you don't have: bash $WORKSPACE/comms/scripts/comms-request-context.sh $PRIMARY_CHANNEL '<what you need>' and wait.
4. Exit when all messages processed.

Load only what you need — your SOUL.md is already loaded. Don't re-read phase files unless you're entering a phase."

cd "$HOME/projects/openclaw-main"
export PATH="/usr/bin:/usr/local/bin:$HOME/Library/pnpm:$HOME/.npm-global/bin:$PATH"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Invoking openclaw agent --agent $AGENT_ID" >> "$LOG_FILE"

node scripts/run-node.mjs agent --agent "$AGENT_ID" -m "$WAKE_PROMPT" >> "$LOG_FILE" 2>&1
EXIT=$?

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sleep $AGENT_ID (exit=$EXIT)" >> "$LOG_FILE"
