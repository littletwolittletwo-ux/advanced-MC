#!/usr/bin/env bash
# Usage: obsidian-write-task.sh <task_id> <island: build|bug> <brief> <outcome> <pr_url>
# Creates a task note in Sunny's vault. Idempotent — overwrites if called twice.
set -euo pipefail

source "$HOME/.openclaw/.env"
: "${OBSIDIAN_VAULT:?}"

TASK_ID="$1"
ISLAND="$2"
BRIEF="$3"
OUTCOME="$4"
PR_URL="${5:-none}"

SUNNY_ROOT="${OBSIDIAN_VAULT}/Sunny"
TASK_FILE="${SUNNY_ROOT}/tasks/${TASK_ID}.md"

mkdir -p "$(dirname "$TASK_FILE")"

cat > "$TASK_FILE" << NOTE_EOF
# ${TASK_ID}

- **Island:** ${ISLAND}
- **Opened:** $(date +%Y-%m-%dT%H:%M)
- **Outcome:** ${OUTCOME}
- **PR:** ${PR_URL}

## Brief
${BRIEF}

## Why I routed it here
<Sunny fills this in — her reasoning for delegation choice, any alternative considered>

## What happened
<Sunny fills this in on completion — the high-level narrative, not the execution details. Those live in Supabase.>

## What I learned
<Sunny fills this in — anything worth remembering next time>
NOTE_EOF

echo "Wrote ${TASK_FILE}"
