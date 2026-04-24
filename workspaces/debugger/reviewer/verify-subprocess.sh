#!/usr/bin/env bash
# Usage: verify-subprocess.sh <run_id> <gnap-task-id> <branch>
# Example: verify-subprocess.sh abc-uuid BUG-7 bugfix/bug-7
set -euo pipefail

source "$HOME/.openclaw/.env"
: "${ANTHROPIC_API_KEY:?}"

RUN_ID="$1"
GNAP_TASK="$2"
BRANCH="$3"

REPO_DIR="$HOME/projects/debugger-sandbox"
cd "$REPO_DIR"
git fetch origin --quiet
git pull --rebase origin main --quiet

TASK_FILE=".gnap/tasks/${GNAP_TASK}.json"
[ -f "$TASK_FILE" ] || { echo '{"verdict":"reject","summary":"gnap task file missing"}'; exit 1; }

# Extract bug brief and acceptance criteria from the task description
BUG_BRIEF=$(jq -r '.desc' "$TASK_FILE")

# Find the latest investigator run for root cause
INVEST_RUN=$(ls -t .gnap/runs/${GNAP_TASK}-*.json 2>/dev/null | while read f; do
  [ "$(jq -r '.agent' "$f")" = "investigator" ] && [ "$(jq -r '.state' "$f")" = "completed" ] && { echo "$f"; break; }
done | head -1)

ROOT_CAUSE="<no investigator run found>"
if [ -n "$INVEST_RUN" ]; then
  ROOT_CAUSE=$(jq -r '.result' "$INVEST_RUN")
fi

# Get the diff on the fix branch vs main
DIFF=$(git log main..origin/${BRANCH} --format="%H %s" 2>/dev/null || echo "<branch not found>")
FULL_DIFF=$(git diff main...origin/${BRANCH} 2>/dev/null || echo "<could not compute diff>")

# CI status for the branch (if a PR exists)
PR_NUM=$(gh pr list --head "$BRANCH" --json number -q '.[0].number' 2>/dev/null || echo "")
if [ -n "$PR_NUM" ]; then
  CI_STATUS=$(gh pr checks "$PR_NUM" 2>&1 || echo "no checks")
else
  CI_STATUS="no PR yet (verification runs before PR creation)"
fi

RUBRIC=$(cat "$HOME/.openclaw/workspace-debugger/reviewer/VERIFY_RUBRIC.md")

PROMPT=$(cat <<PROMPT_END
${RUBRIC}

---

# Verify inputs for run ${RUN_ID} (gnap task ${GNAP_TASK})

## Bug brief and acceptance criteria

${BUG_BRIEF}

## Investigator's root cause

${ROOT_CAUSE}

## Fix branch commits

${DIFF}

## Fix diff

\`\`\`diff
${FULL_DIFF}
\`\`\`

## CI status

${CI_STATUS}

---

Produce your verification as the JSON specified in the rubric. Nothing else.
PROMPT_END
)

OUTPUT=$(unset CLAUDECODE; echo "$PROMPT" | claude -p --output-format text 2>&1) || {
  echo "{\"verdict\":\"reject\",\"summary\":\"verifier subprocess failed: ${OUTPUT}\"}"
  exit 1
}

# Strip markdown fences if present
CLEANED=$(echo "$OUTPUT" | sed -n '/^```json/,/^```$/p' | sed '1d;$d')
[ -z "$CLEANED" ] && CLEANED=$(echo "$OUTPUT" | sed -n '/^```/,/^```$/p' | sed '1d;$d')
[ -z "$CLEANED" ] && CLEANED="$OUTPUT"

if ! echo "$CLEANED" | jq . > /dev/null 2>&1; then
  jq -n --arg raw "$OUTPUT" '{verdict:"reject", summary:"verifier returned unparseable output", raw:$raw}'
  exit 1
fi

echo "$CLEANED"
