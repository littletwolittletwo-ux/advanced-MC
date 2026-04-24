#!/usr/bin/env bash
# Fixer heartbeat — picks up tasks with completed investigation, implements fix + regression test
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

cd "$REPO_DIR"

# Find tasks where investigation is complete but fix is not
TASK_ID=""
for task_json in .gnap/tasks/*.json; do
  [ -f "$task_json" ] || continue
  [ "$(basename "$task_json")" = ".gitkeep" ] && continue

  TID=$(jq -r '.id' "$task_json")
  STATE=$(jq -r '.state' "$task_json")
  ASSIGNED=$(jq -r '.assigned_to | join(",")' "$task_json")

  [[ ",$ASSIGNED," == *",fixer,"* ]] || continue
  [[ "$STATE" == "in_progress" ]] || continue

  # Must have a completed investigator run
  INVEST_RUN=$(ls .gnap/runs/${TID}-*.json 2>/dev/null | while read f; do
    if [ "$(jq -r '.agent' "$f")" = "investigator" ] && [ "$(jq -r '.state' "$f")" = "completed" ]; then
      echo "$f"
      break
    fi
  done | head -1)
  [ -z "$INVEST_RUN" ] && continue

  # Must NOT already have a completed fixer run after the latest investigator run
  LATEST_FIXER=$(ls -t .gnap/runs/${TID}-*.json 2>/dev/null | while read f; do
    if [ "$(jq -r '.agent' "$f")" = "fixer" ]; then
      echo "$f"
      break
    fi
  done | head -1)

  if [ -n "$LATEST_FIXER" ]; then
    FIXER_STATE=$(jq -r '.state' "$LATEST_FIXER")
    [ "$FIXER_STATE" = "completed" ] && continue
  fi

  TASK_ID="$TID"
  INVESTIGATOR_RUN="$INVEST_RUN"
  break
done

if [ -z "$TASK_ID" ]; then
  echo "[fixer] no pending tasks"
  exit 0
fi

echo "[fixer] working on $TASK_ID"

ATTEMPT=$(($(ls .gnap/runs/${TASK_ID}-*.json 2>/dev/null | wc -l) + 1))
RUN_ID="${TASK_ID}-${ATTEMPT}"
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Pull task and investigator findings
TASK_DESC=$(jq -r '.desc' ".gnap/tasks/${TASK_ID}.json")
FINDINGS=$(jq -r '.result' "$INVESTIGATOR_RUN")

# Create a bugfix branch if not already on one
BRANCH="bugfix/${TASK_ID,,}"
git checkout -B "$BRANCH"

FIXER_PROMPT=$(cat <<PROMPT
You are the FIXER agent for gnap task ${TASK_ID}.

Your role:
- You implement minimal, targeted fixes.
- You MUST add a regression test that would have caught this bug.
- You do NOT refactor unrelated code. Scope discipline is non-negotiable.

Task:
---
${TASK_DESC}
---

Investigator findings:
---
${FINDINGS}
---

Repo: ${REPO_DIR} (you are on branch ${BRANCH})

What to do:
1. Read the investigator's findings. Apply the proposed fix minimally.
2. Write a regression test that fails BEFORE your fix and passes AFTER. The test must target the specific bug scenario, not a generic case.
3. Run the test suite to confirm everything still passes.
4. Commit your changes with message: "fix: <short description> (${TASK_ID})"

Constraints:
- Minimal diff. Do not touch files outside the scope identified by the investigator.
- Regression test is mandatory unless the investigator explicitly noted it's unnecessary (rare — docs-only fixes only).
- Do NOT create PRs. The Debugger agent creates PRs after verification.
- Do NOT push. Only commit.

When done, output ONLY this JSON (no other prose):
\`\`\`json
{
  "changes": "...",
  "regression_test": "<file path>: <scenario tested>",
  "test_command": "...",
  "test_result": "pass|fail",
  "commits": ["<SHA>", "..."]
}
\`\`\`

If you cannot fix it, output:
\`\`\`json
{
  "blocked": "<specific reason>",
  "partial_changes": "...",
  "commits": []
}
\`\`\`
PROMPT
)

OUTPUT_FILE=$(mktemp)
claude -p "$FIXER_PROMPT" --output-format text --allow-write > "$OUTPUT_FILE" 2>&1 || {
  echo "[fixer] claude invocation failed"
  cat "$OUTPUT_FILE"
  # Don't push partial work
  git reset --hard HEAD
  exit 1
}

# Push the branch (not main)
git push origin "$BRANCH" 2>&1 || echo "[fixer] warning: branch push failed"

# Parse output
FIX_JSON=$(grep -A1000 '```json' "$OUTPUT_FILE" | grep -B1000 '^```$' | sed '1d;$d' | head -500)
[ -z "$FIX_JSON" ] && FIX_JSON=$(cat "$OUTPUT_FILE")

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Back to main to commit the run record
git checkout main
git pull --rebase origin main

cat > ".gnap/runs/${RUN_ID}.json" << RUN_EOF
{
  "id": "${RUN_ID}",
  "task": "${TASK_ID}",
  "agent": "fixer",
  "state": "completed",
  "attempt": ${ATTEMPT},
  "started_at": "${STARTED_AT}",
  "finished_at": "${FINISHED_AT}",
  "result": $(echo "$FIX_JSON" | jq -Rs .),
  "commits": $(git log --format="%H" "main..${BRANCH}" 2>/dev/null | jq -R . | jq -sc . 2>/dev/null || echo '[]')
}
RUN_EOF

# Transition task to 'review' — Debugger VERIFY phase picks it up
jq --arg id "$TASK_ID" \
  'if .id == $id then .state = "review" | .updated_at = (now | todate) else . end' \
  ".gnap/tasks/${TASK_ID}.json" > /tmp/task.json && mv /tmp/task.json ".gnap/tasks/${TASK_ID}.json"

git add ".gnap/runs/${RUN_ID}.json" ".gnap/tasks/${TASK_ID}.json"
git commit -m "fixer: complete ${RUN_ID} — task ready for review"
git push origin main

# Message the debugger for verification
MSG_ID=$(($(ls .gnap/messages/*.json 2>/dev/null | wc -l) + 1))
cat > ".gnap/messages/${MSG_ID}.json" << MSG_EOF
{
  "id": "${MSG_ID}",
  "from": "fixer",
  "to": ["debugger"],
  "at": "${FINISHED_AT}",
  "type": "request",
  "text": "Fix ready for verification. Task: ${TASK_ID}, branch: ${BRANCH}, run: ${RUN_ID}"
}
MSG_EOF

git add ".gnap/messages/${MSG_ID}.json"
git commit -m "fixer: request verification for ${TASK_ID}"
git push origin main

rm -f "$OUTPUT_FILE"

echo "[fixer] done: ${RUN_ID} (branch ${BRANCH})"
