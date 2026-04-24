#!/usr/bin/env bash
# Investigator heartbeat — runs one iteration of the gnap loop as the 'investigator' agent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

cd "$REPO_DIR"

# Find tasks assigned to 'investigator' in state 'ready' or 'in_progress' where no investigator run exists yet
TASK_FILE=$(jq -r 'select(.assigned_to | index("investigator")) | select(.state == "ready" or .state == "in_progress") | .id' .gnap/tasks/*.json 2>/dev/null | head -1 || true)

if [ -z "$TASK_FILE" ]; then
  # Fallback: find tasks assigned to investigator that have no completed investigator run yet
  for task_json in .gnap/tasks/*.json; do
    [ -f "$task_json" ] || continue
    TASK_ID=$(jq -r '.id' "$task_json")
    STATE=$(jq -r '.state' "$task_json")
    ASSIGNED=$(jq -r '.assigned_to | join(",")' "$task_json")
    if [[ ",$ASSIGNED," == *",investigator,"* ]] && [[ "$STATE" == "ready" || "$STATE" == "in_progress" ]]; then
      # Check if an investigator run already completed for this task
      INVEST_RUN=$(find .gnap/runs -name "${TASK_ID}-*.json" 2>/dev/null | head -1)
      if [ -z "$INVEST_RUN" ]; then
        TASK_FILE="$TASK_ID"
        break
      fi
      # Or if latest run didn't complete investigation
      LATEST_RUN=$(ls -t .gnap/runs/${TASK_ID}-*.json 2>/dev/null | head -1)
      if [ -n "$LATEST_RUN" ]; then
        RUN_STATE=$(jq -r '.state' "$LATEST_RUN")
        RUN_AGENT=$(jq -r '.agent' "$LATEST_RUN")
        if [ "$RUN_AGENT" != "investigator" ] || [ "$RUN_STATE" != "completed" ]; then
          TASK_FILE="$TASK_ID"
          break
        fi
      fi
    fi
  done
fi

if [ -z "$TASK_FILE" ]; then
  echo "[investigator] no pending tasks"
  exit 0
fi

TASK_ID="$TASK_FILE"
echo "[investigator] claiming $TASK_ID"

# Transition task to in_progress if ready
jq --arg id "$TASK_ID" \
  'if .id == $id and .state == "ready" then .state = "in_progress" | .updated_at = (now | todate) else . end' \
  ".gnap/tasks/${TASK_ID}.json" > /tmp/task.json && mv /tmp/task.json ".gnap/tasks/${TASK_ID}.json"

git add ".gnap/tasks/${TASK_ID}.json"
git diff --cached --quiet || git commit -m "investigator: claim ${TASK_ID}"
git push origin main || { echo "[investigator] push failed, aborting heartbeat"; exit 1; }

# Determine attempt number
ATTEMPT=$(($(ls .gnap/runs/${TASK_ID}-*.json 2>/dev/null | wc -l) + 1))
RUN_ID="${TASK_ID}-${ATTEMPT}"
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Invoke Claude Code with investigator prompt
TASK_DESC=$(jq -r '.desc' ".gnap/tasks/${TASK_ID}.json")

INVESTIGATOR_PROMPT=$(cat <<PROMPT
You are the INVESTIGATOR agent for gnap task ${TASK_ID}.

Your role (from the debugger-sandbox team):
- You investigate bugs. You do NOT write fixes.
- You trace root causes with specificity — line numbers, variable names, commit hashes.
- You write minimal, targeted findings — not sweeping architectural critiques.

Task description:
---
${TASK_DESC}
---

Current repo state: \$(pwd) is ${REPO_DIR}. You have full read access to the code.

What to do:
1. Read the bug description, reproduction, and acceptance criteria.
2. Explore the code — read the affected files. Trace how the bug manifests.
3. Identify the root cause. Not "something in auth.ts" — "line 47 of src/auth.ts uses the pre-refresh token because the refresh hook on line 42 was not awaited."
4. Propose a fix approach. Minimal. Do NOT implement it.
5. Write your findings as a structured report.

When done, output ONLY this (and nothing else) so the heartbeat can parse it:

\`\`\`json
{
  "root_cause": "...",
  "affected_files": ["..."],
  "fix_approach": "...",
  "confidence": "high|medium|low",
  "unknowns": "..."
}
\`\`\`

If you cannot identify a root cause, output:
\`\`\`json
{
  "root_cause": null,
  "blocked": "cannot reproduce step X" or "need access to Y",
  "confidence": "low"
}
\`\`\`

DO NOT write code. DO NOT commit. DO NOT modify any files.
PROMPT
)

# Run Claude Code with the prompt (non-interactive)
FINDINGS_FILE=$(mktemp)
claude -p "$INVESTIGATOR_PROMPT" --output-format text > "$FINDINGS_FILE" 2>&1 || {
  echo "[investigator] claude invocation failed"
  cat "$FINDINGS_FILE"
  exit 1
}

# Extract JSON from output (Claude may wrap it in text)
FINDINGS_JSON=$(grep -A1000 '```json' "$FINDINGS_FILE" | grep -B1000 '^```$' | sed '1d;$d' | head -500)
if [ -z "$FINDINGS_JSON" ]; then
  # Fallback: try entire output if no fences
  FINDINGS_JSON=$(cat "$FINDINGS_FILE")
fi

# Write the run
FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > ".gnap/runs/${RUN_ID}.json" <<RUN_EOF
{
  "id": "${RUN_ID}",
  "task": "${TASK_ID}",
  "agent": "investigator",
  "state": "completed",
  "attempt": ${ATTEMPT},
  "started_at": "${STARTED_AT}",
  "finished_at": "${FINISHED_AT}",
  "result": $(echo "$FINDINGS_JSON" | jq -Rs .)
}
RUN_EOF

# Validate JSON
if ! jq . ".gnap/runs/${RUN_ID}.json" > /dev/null 2>&1; then
  echo "[investigator] produced invalid run JSON, retry next heartbeat"
  rm -f ".gnap/runs/${RUN_ID}.json"
  exit 1
fi

git add ".gnap/runs/${RUN_ID}.json"
git commit -m "investigator: complete ${RUN_ID} — investigation done"
git push origin main

# Post message to fixer
MSG_ID=$(($(ls .gnap/messages/*.json 2>/dev/null | wc -l) + 1))
cat > ".gnap/messages/${MSG_ID}.json" << MSG_EOF
{
  "id": "${MSG_ID}",
  "from": "investigator",
  "to": ["fixer"],
  "at": "${FINISHED_AT}",
  "type": "info",
  "text": "Investigation complete for ${TASK_ID}. See .gnap/runs/${RUN_ID}.json for findings."
}
MSG_EOF

git add ".gnap/messages/${MSG_ID}.json"
git commit -m "investigator: notify fixer about ${TASK_ID}"
git push origin main

rm -f "$FINDINGS_FILE"

echo "[investigator] done: ${RUN_ID}"
