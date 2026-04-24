# REVIEW.md — Builder Review Phase (Subprocess Dispatch)

You are in the REVIEW phase. You do NOT review directly. You dispatch review to a fresh subprocess and report its verdict.

## What changed from the old pattern

Previously, you read the plan and the PRs and graded them yourself. That pattern had a bias: the same context that produced the plan tended to rationalize the output. The subprocess pattern fixes this — review happens in a fresh `claude -p` invocation that sees only acceptance criteria, diff, and rubric. It has no knowledge of why the plan was written.

Your job in this phase is to prepare the inputs, invoke the subprocess, parse its output, and report the verdict. You do not second-guess the subprocess. You do not soften its rejections. You do not add caveats.

## Inputs you have

- Plan artifact at `~/.openclaw/workspace-builder/plan-output.md`
- One or more PR URLs from EXECUTE phase

## Discipline — enforced order

### Step 1 — Validate you have a plan with acceptance criteria

```bash
grep -q '^## Acceptance criteria' ~/.openclaw/workspace-builder/plan-output.md || \
  { echo "no acceptance criteria in plan — returning to PLAN"; exit 1; }
```

If no criteria present, go back to PLAN phase. Subprocess review cannot grade against a missing rubric.

### Step 2 — Invoke the reviewer subprocess for EACH PR

For each PR from EXECUTE:

```bash
VERDICT=$(~/.openclaw/workspace-builder/reviewer/review-subprocess.sh \
  "<task_id>" \
  "~/.openclaw/workspace-builder/plan-output.md" \
  "<pr-url>")

echo "$VERDICT" | jq .
```

The subprocess output is structured JSON as specified in the rubric. Parse it.

### Step 3 — Aggregate verdicts across PRs

If all PRs returned `verdict: "approve"` → the whole task is approved.
If any PR returned `verdict: "reject"` → the whole task is rejected (with that PR's feedback).

### Step 4 — Log the review run to Supabase

Append to `strategies_tried` with the review outcome:

```bash
~/.openclaw/workspace-builder/scripts/log-to-supabase.sh update '{
  "task_id":"<uuid>",
  "review_output": <full JSON from subprocess>,
  "phase": "done" | "executing" | "escalated"
}'
```

If `reject`, also add to `failure_modes`:
```json
{ "failure_modes": ["review-rejected"] }
```

### Step 5 — Report to Sunny

Approved:
```
STATUS: approved
TASK_ID: <id>
PR_URLS: [<urls>]
REVIEWER_VERDICT: approve
CRITERIA_MET: <count>/<total>
REVIEWER_SUMMARY: <one-line from subprocess JSON>
```

Rejected:
```
STATUS: rejected
TASK_ID: <id>
PR_URLS: [<urls>]
REVIEWER_VERDICT: reject
FAILED_CRITERIA: [<numbers>]
SCOPE_VIOLATIONS: [<list>]
FEEDBACK: <retry_feedback from subprocess>
NEXT: return to execute with this feedback
```

Escalated (3rd rejection):
```
STATUS: escalated
TASK_ID: <id>
REASON: review rejected three times; planner/executor cannot converge with reviewer
ALL_FEEDBACK: [<list of three feedback blocks>]
RECOMMENDATION: replan from scratch or escalate to David
```

## What NOT to do

- Do NOT re-read the PRs yourself and form an opinion. The subprocess IS the opinion.
- Do NOT edit or soften the subprocess's `retry_feedback` before sending it to EXECUTE. The feedback is adversarial and specific by design.
- Do NOT approve on your own authority if the subprocess rejected. If you believe the subprocess is wrong, escalate to Sunny with "reviewer rejected but I disagree, here's why" — let Sunny decide. Do not silently override.
- Do NOT skip the subprocess on "small" tasks. Every PR gets subprocess review. Exceptions are how rigor erodes.

## Handoff

Feed the verdict back to the loop:
- Approved → report to Sunny
- Rejected → load EXECUTE.md, re-spawn AO with the subprocess's retry_feedback
- Escalated → report to Sunny, stop the loop
