# Phase 3 — Configure Builder

You are configuring Builder as a sub-agent that implements code changes and submits completion reports with evidence for Sunny to review. After this phase, Builder will have:

- A `browser` wrapper scoped to dev environments
- A per-task completion report template Builder must fill out before handing off
- The shared `HANDOFF_PROTOCOL.md`
- A `SKILL_BROWSER.md` tuned for verification-oriented browser use
- Updated RULES.md and SOUL.md with review-loop awareness

## Pre-check

Confirm Phases 1 and 2 completed:

```bash
[ -f "$HOME/.agent-browser/.encryption-key" ] || { echo "Phase 1 not done"; exit 1; }
[ -f "$HOME/.openclaw/workspace/reference/HANDOFF_PROTOCOL.md" ] || { echo "Phase 2 not done"; exit 1; }
[ -d "$HOME/.openclaw/workspace-builder" ] || { echo "Builder workspace missing — fix before running Phase 3"; exit 1; }
```

## Task 1 — Create Builder's browser wrapper

Builder's browser is interactive (can click, fill, submit) but scoped to dev/staging domains only. Update the allowlist in the wrapper once you know the actual domains — placeholders below are safe starters.

```bash
BUILDER_WS="$HOME/.openclaw/workspace-builder"
mkdir -p "$BUILDER_WS/bin" "$BUILDER_WS/reference"

cat > "$BUILDER_WS/bin/browser" <<'WRAPPER_EOF'
#!/usr/bin/env bash
# Builder's browser — DEV SCOPE. Can interact with UI, but destructive
# actions and production domains are policy-denied.
exec agent-browser \
  --session builder \
  --profile "$HOME/.agent-browser/profiles/builder" \
  --allowed-domains "localhost,127.0.0.1,*.vercel.app,*.ngrok.io,*.ngrok-free.app" \
  --content-boundaries \
  --max-output 40000 \
  --action-policy "$HOME/.openclaw/workspace-builder/reference/browser-policy.json" \
  "$@"
WRAPPER_EOF
chmod +x "$BUILDER_WS/bin/browser"
```

**User action required after Phase 3**: edit the `--allowed-domains` list to include your actual project domains (staging, preview deploys, whatever Builder needs to reach). The placeholder list covers local + generic tunnel services.

## Task 2 — Create Builder's browser policy (dev-permissive, production-safe)

```bash
cat > "$BUILDER_WS/reference/browser-policy.json" <<'POLICY_EOF'
{
  "deny_by_default": false,
  "rules": [
    { "action": "eval",     "effect": "deny" },
    { "action": "upload",   "effect": "deny" },
    { "action": "download", "effect": "deny" },

    { "action": "click", "match": "text=Delete",          "effect": "deny" },
    { "action": "click", "match": "text=Remove Account",  "effect": "deny" },
    { "action": "click", "match": "text=Drop",            "effect": "deny" },
    { "action": "click", "match": "text=Publish",         "effect": "deny" },
    { "action": "click", "match": "text=Deploy to Prod",  "effect": "deny" },
    { "action": "click", "match": "text=Deploy Production","effect": "deny" },

    { "action": "click", "match": "text=Pay",             "effect": "deny" },
    { "action": "click", "match": "text=Buy",             "effect": "deny" },
    { "action": "click", "match": "text=Charge",          "effect": "deny" },
    { "action": "click", "match": "text=Withdraw",        "effect": "deny" },
    { "action": "click", "match": "text=Transfer Funds",  "effect": "deny" }
  ]
}
POLICY_EOF
```

Note: `text=Submit` and `text=Save` are NOT denied for Builder — those are legitimate in dev-flow testing (submitting a test form, saving a draft). The deny list targets irreversible + high-consequence actions only.

## Task 3 — Copy HANDOFF_PROTOCOL.md from Sunny

Same file, verbatim — all three agents must share the identical protocol:

```bash
cp "$HOME/.openclaw/workspace/reference/HANDOFF_PROTOCOL.md" \
   "$BUILDER_WS/reference/HANDOFF_PROTOCOL.md"
```

If this fails because Sunny's copy is missing, stop — Phase 2 did not complete.

## Task 4 — Create Builder's SKILL_BROWSER.md

```bash
cat > "$BUILDER_WS/reference/SKILL_BROWSER.md" <<'SKILL_EOF'
# SKILL_BROWSER.md — Builder's browser tool

You have `bin/browser` available. It wraps `agent-browser` with your session, profile, domain allowlist, and action policy already configured. Do not call `agent-browser` directly.

## When to use

- **Verify your own work**: after implementing a change, drive the affected flow(s) and confirm behaviour
- **Visual regression**: take screenshots before/after a UI change, compare with `diff screenshot`
- **Smoke-test forms and interactions**: after wiring up a form, submit it and watch the response
- **Read docs not in your context**: open the documentation page, snapshot, answer your question
- **Check that a dev server or preview deploy is actually working**: open, snapshot, confirm
- **Produce evidence for your completion report**: screenshots, HAR, console output

## When NOT to use

- **Scraping or data extraction**: not your job. If a task devolves into scraping, escalate to Sunny.
- **Testing production**: your allowlist does not include production. If testing requires prod, escalate.
- **Destructive actions** (delete, deploy, publish, pay, transfer): policy will deny. Do not retry with different wording — escalate.
- **Sites you have no vault credentials for**: do not manually type passwords. Use `browser auth login <name>` or escalate to Sunny for a new vault entry.

## Standard flow (the happy path)

```
browser open <url>
browser wait --load networkidle
browser snapshot -i --json             # see interactive elements, get refs
browser click @eN                      # interact by ref
browser fill @eN "value"
browser screenshot ./evidence/<task>/<step>.png
```

## Evidence capture (required for every completion report)

For any task that touches UI:

```
# Before-state screenshots (take these BEFORE making code changes if possible)
browser open <url-of-affected-page>
browser screenshot ./evidence/<task-id>/before-<page-name>.png

# After-state screenshots (after changes, server restarted)
browser open <url-of-affected-page>
browser screenshot ./evidence/<task-id>/after-<page-name>.png

# Console and errors during the verification drive-through
browser console > ./evidence/<task-id>/console.txt
browser errors  > ./evidence/<task-id>/errors.txt

# Network trace of the happy-path flow
browser network har start
# ... drive the flow end-to-end ...
browser network har stop ./evidence/<task-id>/flow.har
```

File the paths in your completion report's EVIDENCE section. Do not inline contents — reference paths.

## Authentication

Never type passwords inline into form fields. Always use the vault:

```
browser auth login <vault-name>
```

If the vault does not contain the credentials you need, DM Sunny on `dm:sunny-builder`:

```
NEED_VAULT_ENTRY
Site: <url>
Purpose: <why you need it for this task>
```

Sunny provisions credentials. You never handle raw passwords.

## Escalation triggers — DM Sunny on dm:sunny-builder

- 2FA code prompt appears (Sunny relays from David)
- Captcha (human required)
- Login form with no vault entry yet
- Policy denied an action you believe is legitimate for this task
- Allowlist blocks a domain you need (propose which one and why)
- Flow behaves unexpectedly and might affect real systems
- Verification reveals a bug outside the scope of your current task (report it, do not silently fix)

## Timeout behaviour

Default operation timeout is 25s. For slow pages (`load networkidle` can be slow on heavy apps), chain an explicit wait:

```
browser open <url>
browser wait --load networkidle     # explicit wait
browser snapshot -i
```

If 25s is genuinely not enough for legitimate operations, ask Sunny — do not self-modify the wrapper.

## Sessions are isolated

Your session name is `builder`. State (cookies, localStorage, logins) persists in `~/.agent-browser/profiles/builder`. You do not see Debugger's or Sunny's session state and they do not see yours. If you need to share artifacts with them, put files under `~/.openclaw/workspace-builder/evidence/<task-id>/` and reference the paths in bus messages.
SKILL_EOF
```

## Task 5 — Create COMPLETION_REPORT_TEMPLATE.md

```bash
cat > "$BUILDER_WS/reference/COMPLETION_REPORT_TEMPLATE.md" <<'TEMPLATE_EOF'
# COMPLETION_REPORT_TEMPLATE.md — Builder's submission format

Every completed task is submitted to Sunny on `dm:sunny-builder` using this template. Deviations from this format trigger an immediate structural REJECT.

The report goes directly in the bus message body. Keep prose tight — evidence goes in files, referenced by path.

## Template (fill in, delete the guidance in parentheses)

```
COMPLETION REPORT: <short task title from Sunny's brief>

Task ID: <from Sunny's brief, or generate: task-YYYYMMDD-<shortdesc>>
Iteration: <1 on first submission; increment on re-submission after rejection>

SUMMARY (1-3 sentences, what was done, not how):
<...>

ACCEPTANCE CRITERIA (copy each criterion from Sunny's brief, mark status):
1. <criterion> — MET | PARTIALLY MET | NOT MET
   Evidence: <file path or inline reference>
2. <criterion> — ...
   Evidence: ...

CHANGES MADE:
Files modified:
  - <path> — <one-line reason>
  - <path> — <one-line reason>

Files added:
  - <path> — <one-line reason>

Files deleted:
  - <path> — <one-line reason>

Diff: <path to saved diff, e.g. ./evidence/<task-id>/changes.diff>

Tests added/updated:
  - <test file> — <what it covers>
  - <test file> — ...

Test run output: <path to saved test output>

VERIFICATION PERFORMED (what you did yourself before submitting):

Pages/routes driven end-to-end:
  - <url> — <outcome>
  - <url> — <outcome>

Flows tested:
  - <flow description> — PASS | FAIL (if FAIL, stop and fix before submitting)

Screenshots:
  - Before: ./evidence/<task-id>/before-*.png (list all)
  - After:  ./evidence/<task-id>/after-*.png  (list all)

Network trace (HAR): ./evidence/<task-id>/flow.har

Console output: ./evidence/<task-id>/console.txt
  Errors observed: <count, or "none">

Errors dump: ./evidence/<task-id>/errors.txt
  Exceptions thrown: <count, or "none">

Data correctness check:
  <description of what data was written and how you verified it matches spec,
   e.g., "Ran SELECT on bookings table, confirmed created_at matches submission time within 1s">

Regression spot-check:
  Neighbouring page/flow tested: <description>
  Outcome: <still works | issue found>

KNOWN LIMITATIONS (be explicit — hiding these is an auto-reject):
- <limitation 1 and why it's acceptable within scope>
- <limitation 2 and why>
- <or: "none">

OUT-OF-SCOPE OBSERVATIONS (things you noticed but did not fix):
- <observation — file/area, brief description>
- <or: "none">

SELF-CHECK (confirm each before submitting — if any is "no", do not submit):
- [ ] Every ACCEPTANCE CRITERIA item has evidence attached
- [ ] Every evidence file path listed exists and is readable
- [ ] Console was clean on the happy path
- [ ] No 4xx/5xx on the happy path network trace
- [ ] All tests pass (output saved)
- [ ] No console.log / print debug statements left in the diff
- [ ] No exposed secrets or API keys in the diff (ran grep to confirm)
- [ ] No commented-out code blocks in the diff
- [ ] No .skip / xit / pending tests added
- [ ] Regression spot-check completed on at least one neighbouring flow
- [ ] Out-of-scope observations listed, not silently fixed

END OF REPORT
```

## Sizing guidance

- SUMMARY: 1-3 sentences
- ACCEPTANCE CRITERIA: one line per criterion + evidence reference
- CHANGES MADE: concise bullets, not paragraphs
- VERIFICATION PERFORMED: the substantive section, but still bullets
- KNOWN LIMITATIONS: listed, not hidden
- SELF-CHECK: every box ticked or the report is not sent

A typical report is 60-120 lines. If yours is >200 lines, you are inlining content that should be in evidence files.

## What NOT to do in the report

- Do NOT inline screenshots, diffs, HAR contents, or log dumps. Reference paths.
- Do NOT skip sections because "they don't apply" — write "none" or "N/A" with a one-line reason.
- Do NOT submit with any SELF-CHECK box unchecked. Fix first, submit after.
- Do NOT claim "tests pass" without attaching test output.
- Do NOT minimise known limitations. Sunny will find them anyway.
- Do NOT fix out-of-scope issues silently. Report them, let Sunny decide.
TEMPLATE_EOF
```

## Task 6 — Update Builder's RULES.md

Append a section about the browser tool and review loop:

```bash
RULES="$BUILDER_WS/reference/RULES.md"

# Create it if it doesn't exist (defensive — it should from prior setup)
[ -f "$RULES" ] || touch "$RULES"

if grep -q '^## Browser Tool and Review Loop' "$RULES"; then
  echo "Browser Tool and Review Loop section already in RULES.md — skipping"
else
  cat >> "$RULES" <<'RULES_EOF'

---

## Browser Tool and Review Loop

### You have a browser

`bin/browser` is your verification tool. It is in your workspace PATH. Details in `reference/SKILL_BROWSER.md`. You are expected to use it to verify your own work before submitting to Sunny — not using it when a task touches UI is an automatic rejection pattern.

### Every completed task submits a report

You do not report task completion in free-form prose. You fill in `reference/COMPLETION_REPORT_TEMPLATE.md` and send it as a bus message on `dm:sunny-builder`. No exceptions.

### Sunny reviews everything

Every submission goes through Sunny's independent audit (`reference/HANDOFF_PROTOCOL.md`). She will:

- Read your diff herself
- Run your tests herself
- Drive your flows herself with her own `browser`
- Check your data against the database directly
- Apply `AUDIT_CRITERIA.md` line by line

She is harsh but reasonable. Her rejections are specific and actionable. Treat them as work items, not criticism.

### On rejection

Acknowledge the rejection message within one response turn. Then:

1. Read every issue in the rejection
2. Address them specifically — do not re-argue accepted points
3. Re-run the verification flow end-to-end
4. Fill in a new completion report with `Iteration: <n+1>`
5. Re-submit

Do not submit without addressing every issue. Partial fixes cause iteration loops.

### Iteration limit

After 3 rejections on the same task, Sunny auto-escalates to David. If you see you are about to hit this, proactively DM Sunny on `dm:sunny-builder` asking for help — a scope conversation, a pair-programming session, whatever breaks the cycle.

### Forbidden shortcuts

- Never submit a report without running the verification flow yourself
- Never claim "tests pass" without attaching test output
- Never silently fix out-of-scope issues
- Never inline screenshots, HARs, or diffs into the report — reference paths
- Never skip the SELF-CHECK — if a box doesn't tick, the report isn't ready

RULES_EOF
  echo "Browser Tool and Review Loop section appended to RULES.md"
fi
```

## Task 7 — Update Builder's SOUL.md

Append a short awareness section:

```bash
SOUL="$BUILDER_WS/SOUL.md"

if grep -q '^## Review Loop Awareness' "$SOUL"; then
  echo "Review Loop Awareness section already in Builder's SOUL.md — skipping"
else
  cat >> "$SOUL" <<'SOUL_EOF'

---

## Review Loop Awareness

Your work does not reach David directly. Every completed task goes to Sunny via `dm:sunny-builder` as a completion report. Sunny independently verifies, then forwards to David on accept or returns to you on reject.

Authoritative references in `reference/`:
- `HANDOFF_PROTOCOL.md` — the full loop
- `COMPLETION_REPORT_TEMPLATE.md` — the submission format (mandatory)
- `SKILL_BROWSER.md` — your verification tool
- `RULES.md` — the updated Browser Tool and Review Loop section

Before submitting any completion report, load `COMPLETION_REPORT_TEMPLATE.md` into working memory and fill it in. Do not submit free-form.

You have `bin/browser` for verification. Use it. A completion report on a UI-touching task without browser-captured evidence will be rejected on structure alone.

SOUL_EOF
  echo "Review Loop Awareness section appended to Builder's SOUL.md"
fi
```

## Task 8 — Verify Phase 3

```bash
echo "=== Phase 3 Verification ==="

# Wrapper executable
[ -x "$BUILDER_WS/bin/browser" ] && echo "✓ Builder's browser wrapper is executable" || echo "✗ browser wrapper missing"

# Policy valid JSON
jq -e . "$BUILDER_WS/reference/browser-policy.json" >/dev/null 2>&1 && echo "✓ browser-policy.json is valid JSON" || echo "✗ browser-policy.json invalid"

# Reference files present
for f in HANDOFF_PROTOCOL.md SKILL_BROWSER.md COMPLETION_REPORT_TEMPLATE.md; do
  [ -s "$BUILDER_WS/reference/$f" ] && echo "✓ $f present" || echo "✗ $f missing or empty"
done

# HANDOFF_PROTOCOL.md is identical to Sunny's
diff -q "$HOME/.openclaw/workspace/reference/HANDOFF_PROTOCOL.md" \
        "$BUILDER_WS/reference/HANDOFF_PROTOCOL.md" >/dev/null && \
  echo "✓ HANDOFF_PROTOCOL.md matches Sunny's copy" || \
  echo "✗ HANDOFF_PROTOCOL.md differs from Sunny's — re-copy"

# RULES.md updated
grep -q '^## Browser Tool and Review Loop' "$BUILDER_WS/reference/RULES.md" && \
  echo "✓ RULES.md contains Browser Tool and Review Loop section" || \
  echo "✗ RULES.md missing Browser Tool section"

# SOUL.md updated
grep -q '^## Review Loop Awareness' "$BUILDER_WS/SOUL.md" && \
  echo "✓ SOUL.md contains Review Loop Awareness section" || \
  echo "✗ SOUL.md missing Review Loop Awareness section"

# Smoke test Builder's browser
"$BUILDER_WS/bin/browser" open http://localhost >/dev/null 2>&1
"$BUILDER_WS/bin/browser" close >/dev/null 2>&1
echo "✓ Builder browser launched and closed cleanly"

echo "=== Phase 3 Complete ==="
```

## Final message to the user

```
PHASE 3 COMPLETE

Builder configured as implementer with mandatory review handoff.

Files created:
  ~/.openclaw/workspace-builder/bin/browser                              (dev-scope wrapper)
  ~/.openclaw/workspace-builder/reference/browser-policy.json            (policy)
  ~/.openclaw/workspace-builder/reference/HANDOFF_PROTOCOL.md            (shared)
  ~/.openclaw/workspace-builder/reference/SKILL_BROWSER.md               (verification-oriented)
  ~/.openclaw/workspace-builder/reference/COMPLETION_REPORT_TEMPLATE.md  (submission format)

Files modified:
  ~/.openclaw/workspace-builder/reference/RULES.md   (appended Browser Tool and Review Loop)
  ~/.openclaw/workspace-builder/SOUL.md              (appended Review Loop Awareness)

Verification: <all ✓ / list any ✗>

MANUAL ACTION REQUIRED FROM USER:
  Edit ~/.openclaw/workspace-builder/bin/browser and update --allowed-domains
  to include your actual project dev/staging domains. Default list covers
  localhost + generic tunnel services only.

READY FOR PHASE 4.
```

## Do NOT do in this phase

- Do NOT touch Sunny or Debugger workspaces
- Do NOT seed auth vault entries
- Do NOT edit Builder's SOUL.md beyond the appended section
- Do NOT modify the HANDOFF_PROTOCOL.md — it must match Sunny's copy verbatim
- Do NOT restart the Builder poller or OpenClaw session
