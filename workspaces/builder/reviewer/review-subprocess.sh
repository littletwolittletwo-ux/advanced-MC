#!/usr/bin/env bash
# Usage: review-subprocess.sh <task_id> <plan-output-path> <pr-url-or-path>
# Invokes claude -p with a fresh adversarial reviewer context.
# Prints the subprocess's JSON output to stdout. Nonzero exit if the subprocess failed.
set -euo pipefail

source "$HOME/.openclaw/.env"
: "${ANTHROPIC_API_KEY:?}"
: "${GITHUB_PAT:?}"

TASK_ID="$1"
PLAN_PATH="$2"
PR_URL="$3"

[ -f "$PLAN_PATH" ] || { echo '{"verdict":"reject","summary":"plan-output.md not found — cannot review"}'; exit 1; }

# Extract just the Acceptance criteria section from the plan — reviewer should not see reasoning
CRITERIA=$(awk '/^## Acceptance criteria/{found=1} found{print} found && /^## [^A]/{exit}' "$PLAN_PATH" | sed '$d')
[ -z "$CRITERIA" ] && { echo '{"verdict":"reject","summary":"no Acceptance criteria found in plan"}'; exit 1; }

# Fetch the PR diff
if [[ "$PR_URL" == http* ]]; then
  DIFF=$(gh pr diff "$PR_URL" 2>&1 || echo "<could not fetch diff>")
  PR_BODY=$(gh pr view "$PR_URL" --json body -q .body 2>&1 || echo "")
  CI_STATUS=$(gh pr checks "$PR_URL" 2>&1 || echo "no checks")
else
  DIFF="<PR_URL not provided or not a URL>"
  PR_BODY=""
  CI_STATUS="unknown"
fi

# Load the rubric
RUBRIC=$(cat "$HOME/.openclaw/workspace-builder/reviewer/REVIEW_RUBRIC.md")

# Build the reviewer prompt — EVERYTHING the subprocess knows is in here
PROMPT=$(cat <<PROMPT_END
${RUBRIC}

---

# Review inputs for task ${TASK_ID}

## Acceptance criteria (from the plan)

${CRITERIA}

## PR description

${PR_BODY}

## CI status

${CI_STATUS}

## Diff

\`\`\`diff
${DIFF}
\`\`\`

---

Produce your review as the JSON object specified in the rubric. Nothing else. No preamble, no markdown fences, no explanation — just the JSON. Your output is parsed by a script.
PROMPT_END
)

# Invoke claude with no context carryover (--no-resume keeps it stateless)
OUTPUT=$(unset CLAUDECODE; echo "$PROMPT" | claude -p --output-format text 2>&1) || {
  echo "{\"verdict\":\"reject\",\"summary\":\"reviewer subprocess failed: ${OUTPUT}\"}"
  exit 1
}

# Strip any markdown fences the subprocess might have added despite instructions
CLEANED=$(echo "$OUTPUT" | sed -n '/^```json/,/^```$/p' | sed '1d;$d')
[ -z "$CLEANED" ] && CLEANED=$(echo "$OUTPUT" | sed -n '/^```/,/^```$/p' | sed '1d;$d')
[ -z "$CLEANED" ] && CLEANED="$OUTPUT"

# Validate JSON
if ! echo "$CLEANED" | jq . > /dev/null 2>&1; then
  # Return a rejection wrapping the unparseable output so Builder can see what went wrong
  jq -n --arg raw "$OUTPUT" '{verdict:"reject", summary:"reviewer returned unparseable output", raw:$raw}'
  exit 1
fi

echo "$CLEANED"
