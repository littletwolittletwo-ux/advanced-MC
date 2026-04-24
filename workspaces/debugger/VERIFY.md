# VERIFY.md — Debugger Verify Phase (Subprocess Dispatch)

You are in the VERIFY phase. You do NOT verify the fix directly. You dispatch verification to a fresh subprocess and report its verdict.

## Why subprocess

The verifier in fresh context has no knowledge of why the investigator chose a hypothesis, why the fixer took a particular approach, or what the gnap conversation looked like. It sees only the bug brief, the root cause statement, and the diff. It cannot rationalize — it can only grade.

## Inputs you have

- The gnap task file at `~/projects/debugger-sandbox/.gnap/tasks/<TASK>.json`
- The latest fixer run at `~/projects/debugger-sandbox/.gnap/runs/<TASK>-<N>.json`
- The fix branch (typically `bugfix/<task-lowercase>`)
- The Supabase `debugger_runs` row for this run

## Discipline — enforced order

### Step 1 — Confirm the task is ready for verify

```bash
cd ~/projects/debugger-sandbox
git pull --rebase origin main
STATE=$(jq -r '.state' .gnap/tasks/<TASK>.json)
[ "$STATE" = "review" ] || { echo "task not ready for review (state=$STATE)"; exit 1; }
```

If the state is anything other than `review`, the fixer isn't done. Return control to INVESTIGATE phase.

### Step 2 — Invoke the verifier subprocess

```bash
VERDICT=$(~/.openclaw/workspace-debugger/reviewer/verify-subprocess.sh \
  "<run_id>" \
  "<gnap-task-id>" \
  "<branch-name>")

echo "$VERDICT" | jq .
```

Parse the returned JSON.

### Step 3 — Log the verification to Supabase

```bash
~/.openclaw/workspace-debugger/gnap-scripts/log-to-supabase.sh debugger_runs update '{
  "run_id":"<uuid>",
  "verify_output": <full JSON>,
  "phase": "pr-open" | "investigating" | "escalated"
}'
```

If rejected, add to `failure_modes`:
```json
{ "failure_modes": ["verify-rejected"] }
```

### Step 4 — Act on the verdict

**Approved:**
1. Create a PR from the fix branch:
   ```bash
   gh pr create \
     --head "<branch>" \
     --title "fix: <title from task>" \
     --body "<composed from task brief + root cause + verifier summary>"
   ```
2. Set gnap task to `done`:
   ```bash
   jq '.state = "done" | .updated_at = (now | todate)' .gnap/tasks/<TASK>.json > /tmp/t.json
   mv /tmp/t.json .gnap/tasks/<TASK>.json
   git add .gnap/tasks/<TASK>.json
   git commit -m "debugger: approve <TASK>"
   git push origin main
   ```
3. Report to Sunny with PR URL.

**Rejected:**
1. Do NOT create a PR. Do NOT merge anything.
2. Set gnap task back to `in_progress`:
   ```bash
   jq '.state = "in_progress" | .updated_at = (now | todate)' .gnap/tasks/<TASK>.json > /tmp/t.json
   mv /tmp/t.json .gnap/tasks/<TASK>.json
   ```
3. Post a gnap message to fixer with the verifier's retry_feedback:
   ```bash
   MSG_ID=$(($(ls .gnap/messages/*.json 2>/dev/null | wc -l) + 1))
   cat > .gnap/messages/${MSG_ID}.json << MSG_EOF
   {
     "id": "${MSG_ID}",
     "from": "debugger",
     "to": ["fixer"],
     "at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
     "type": "feedback",
     "text": "Verifier rejected. Specific issues: <retry_feedback>"
   }
   MSG_EOF
   git add .gnap/tasks/<TASK>.json .gnap/messages/${MSG_ID}.json
   git commit -m "debugger: reject <TASK>, feedback to fixer"
   git push origin main
   ```
4. Report to Sunny: STATUS rejected, feedback included.

### Step 5 — Escalation threshold

Check `failure_modes` on the `debugger_runs` row for this run. If `verify-rejected` appears three or more times:

- Do NOT reject again.
- Set gnap task to `blocked` with `blocked_reason`: "three consecutive verifier rejections"
- Escalate to Sunny:
  ```
  STATUS: escalated
  RUN_ID: <id>
  TASK: <gnap-task>
  REASON: three verifier rejections; fixer cannot converge
  ALL_FEEDBACK: [<list>]
  RECOMMENDATION: replan the fix, escalate to David, or accept the risk explicitly
  ```

## What NOT to do

- Do NOT re-verify yourself after the subprocess returns. Its verdict is authoritative.
- Do NOT soften the verifier's retry_feedback before sending to fixer. Specific, adversarial feedback is how the fixer gets it right on the next attempt.
- Do NOT approve if the subprocess rejected, on your own authority. Escalate instead.
- Do NOT create a PR without the subprocess approving first.

## Handoff

- Approved → PR created, report to Sunny, done.
- Rejected → task back in `in_progress`, message to fixer, report to Sunny. Fixer's next heartbeat picks up the feedback.
- Escalated → Sunny decides.
