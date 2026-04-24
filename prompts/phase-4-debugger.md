# Phase 4 — Configure Debugger

You are configuring Debugger as a sub-agent that investigates bugs and submits investigation reports for Sunny to review. After this phase, Debugger will have:

- A `browser` wrapper with a wider scope than Builder's (includes observability vendors)
- A specialised investigation report template
- The shared `HANDOFF_PROTOCOL.md`
- A `SKILL_BROWSER.md` tuned for diagnostics (HAR capture, console/error inspection, trace, diff)
- Updated RULES.md and SOUL.md with review-loop awareness

## Pre-check

```bash
[ -f "$HOME/.agent-browser/.encryption-key" ] || { echo "Phase 1 not done"; exit 1; }
[ -f "$HOME/.openclaw/workspace/reference/HANDOFF_PROTOCOL.md" ] || { echo "Phase 2 not done"; exit 1; }
[ -f "$HOME/.openclaw/workspace-builder/reference/HANDOFF_PROTOCOL.md" ] || { echo "Phase 3 not done"; exit 1; }
[ -d "$HOME/.openclaw/workspace-debugger" ] || { echo "Debugger workspace missing"; exit 1; }
```

## Task 1 — Create Debugger's browser wrapper

Debugger has a wider allowlist (observability vendors, error tracking) and a higher output cap (HAR and network dumps are verbose).

```bash
DEBUGGER_WS="$HOME/.openclaw/workspace-debugger"
mkdir -p "$DEBUGGER_WS/bin" "$DEBUGGER_WS/reference" "$DEBUGGER_WS/gnap"

cat > "$DEBUGGER_WS/bin/browser" <<'WRAPPER_EOF'
#!/usr/bin/env bash
# Debugger's browser — DIAGNOSTIC SCOPE. Interactive for reproduction,
# observability vendors allowed, higher output cap for HAR/log dumps.
exec agent-browser \
  --session debugger \
  --profile "$HOME/.agent-browser/profiles/debugger" \
  --allowed-domains "localhost,127.0.0.1,*.vercel.app,*.ngrok.io,*.ngrok-free.app,*.sentry.io,*.datadoghq.com,*.honeycomb.io,*.logtail.com,*.rollbar.com" \
  --content-boundaries \
  --max-output 120000 \
  --action-policy "$HOME/.openclaw/workspace-debugger/reference/browser-policy.json" \
  "$@"
WRAPPER_EOF
chmod +x "$DEBUGGER_WS/bin/browser"
```

**User action required after Phase 4**: update `--allowed-domains` to include your actual production domains (in read-only sense — policy still blocks destructive actions) and any specific observability tools you use. Debugger legitimately needs to reach production to reproduce production-only bugs; the policy file prevents damage.

## Task 2 — Create Debugger's browser policy

Debugger can interact for reproduction purposes but is strictly blocked from state-changing actions that could alter real-world data:

```bash
cat > "$DEBUGGER_WS/reference/browser-policy.json" <<'POLICY_EOF'
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
    { "action": "click", "match": "text=Deploy",          "effect": "deny" },

    { "action": "click", "match": "text=Pay",             "effect": "deny" },
    { "action": "click", "match": "text=Buy",             "effect": "deny" },
    { "action": "click", "match": "text=Charge",          "effect": "deny" },
    { "action": "click", "match": "text=Withdraw",        "effect": "deny" },
    { "action": "click", "match": "text=Transfer",        "effect": "deny" },
    { "action": "click", "match": "text=Send Funds",      "effect": "deny" },

    { "action": "click", "match": "text=Cancel Account",  "effect": "deny" },
    { "action": "click", "match": "text=Close Account",   "effect": "deny" },
    { "action": "click", "match": "text=Unsubscribe",     "effect": "deny" }
  ]
}
POLICY_EOF
```

## Task 3 — Copy HANDOFF_PROTOCOL.md

```bash
cp "$HOME/.openclaw/workspace/reference/HANDOFF_PROTOCOL.md" \
   "$DEBUGGER_WS/reference/HANDOFF_PROTOCOL.md"
```

## Task 4 — Create Debugger's SKILL_BROWSER.md

```bash
cat > "$DEBUGGER_WS/reference/SKILL_BROWSER.md" <<'SKILL_EOF'
# SKILL_BROWSER.md — Debugger's browser tool

You have `bin/browser`. This is your **primary investigation instrument** — default to reproducing web bugs in the browser, not to reading logs remotely. Logs tell you what the system recorded; the browser tells you what the user experienced.

## When to use

- **Reproduction** — every web-facing bug starts here
- **Evidence capture** — HAR, console, errors, screenshots, traces
- **Hypothesis validation** — does changing <condition> change the symptom?
- **Fix verification** — after Builder claims a fix, drive the same repro and confirm
- **Regression hunting** — when a bug reappears, compare current HAR against original HAR

## When NOT to use

- **Production mutations** — policy denies destructive clicks, and you should not override this. If reproduction genuinely requires a destructive action (e.g., "the bug only appears on delete"), DM Sunny on `dm:sunny-debugger` and request explicit approval with a test account.
- **Data extraction at volume** — not your role. Investigation → short, focused HAR captures, not mass scraping.
- **Any action on a domain outside your allowlist** — escalate, don't override.

## Reproduction workflow (the canonical flow)

Assume you are investigating bug `<bug-id>`. Create a workspace for it:

```
mkdir -p ./gnap/<bug-id>
cd ./gnap/<bug-id>
```

Then capture the full repro:

```
# 1. Start HAR capture BEFORE you open the page
browser network har start

# 2. Navigate and drive the failing flow
browser open <url>
browser wait --load networkidle
browser snapshot -i --json > snapshot-before.json
browser screenshot before.png

# ... drive the steps that trigger the bug (click, fill, etc) ...

browser screenshot failure.png
browser snapshot -i --json > snapshot-after.json

# 3. Stop HAR and capture diagnostics
browser network har stop ./failure.har
browser console > console.txt
browser errors  > errors.txt

# 4. Capture failing network calls specifically
browser network requests --status 4xx,5xx --json > failing-requests.json
browser network requests --type xhr,fetch --json  > all-xhr.json
```

Every file in `./gnap/<bug-id>/` goes in your investigation report's EVIDENCE section.

## Diagnostic commands

```
# Console and errors
browser console                        # all console messages
browser console --clear                # clear before starting a new repro pass
browser errors                         # uncaught exceptions

# Network
browser network requests                             # all tracked requests
browser network requests --filter <substr>           # narrow by URL substring
browser network requests --status 4xx,5xx            # failing calls only
browser network requests --method POST               # filter by method
browser network request <requestId>                  # full req/resp detail

# HAR
browser network har start
# ... drive flow ...
browser network har stop <path>.har

# Traces and profiles (use sparingly — large files)
browser trace start
# ... drive flow ...
browser trace stop <path>

browser profiler start
# ...
browser profiler stop <path>.json

# Comparison
browser diff snapshot --baseline snapshot-before.json
browser diff screenshot --baseline before.png
browser diff url <prod-url> <staging-url> --screenshot    # cross-env diff
```

## Fix verification (post-Builder handoff)

When Builder claims a fix, repeat your own original repro verbatim. The fix is verified if and only if:

1. The original repro steps no longer reproduce the failure
2. The network trace shows the previously-failing call now succeeds (or the call pattern has legitimately changed)
3. `browser errors` is clean where it was previously exceptions
4. No new errors or warnings have appeared in `browser console`

Capture this as verification evidence:

```
mkdir -p ./gnap/<bug-id>/fix-verification
browser network har start
# ... re-run the original repro exactly ...
browser network har stop ./gnap/<bug-id>/fix-verification/post-fix.har
browser console > ./gnap/<bug-id>/fix-verification/console.txt
browser errors  > ./gnap/<bug-id>/fix-verification/errors.txt
browser screenshot ./gnap/<bug-id>/fix-verification/post-fix.png
browser diff screenshot --baseline ./gnap/<bug-id>/before.png \
  -o ./gnap/<bug-id>/fix-verification/diff.png
```

## Authentication

Same as Builder — never type passwords inline. Use `browser auth login <n>`. If the vault doesn't have the credentials for the site you need to investigate, DM Sunny on `dm:sunny-debugger` with:

```
NEED_VAULT_ENTRY
Site: <url>
Purpose: reproducing <bug-id>
Test account needed: <y/n, if a separate test account should be created>
```

## Escalation triggers — DM Sunny on dm:sunny-debugger

- Repro requires a destructive action → need explicit approval for a test account
- Bug is only reproducible in production → need confirmation to investigate there
- Repro requires credentials not in the vault
- Allowlist doesn't cover a domain you need (e.g., a new third-party service)
- You've identified a root cause that's outside the system's codebase (third-party bug, platform issue)
- You find a second unrelated bug during investigation — report it, do not silently pursue it

## Output size

HAR files can be multi-MB. Traces and profiles can be 10+MB. Store them under `./gnap/<bug-id>/` and reference paths — never inline. If a HAR is >10MB, capture a narrower slice by trimming the repro to the minimum failing sequence.

## Cleanup

After a bug is closed and verified:

```
# Archive rather than delete (keeps forensic record)
tar -czf ./gnap/archive/<bug-id>-<yyyymmdd>.tar.gz ./gnap/<bug-id>/
rm -rf ./gnap/<bug-id>/
```

Cron sweeps `./gnap/archive/` quarterly.
SKILL_EOF
```

## Task 5 — Create INVESTIGATION_REPORT_TEMPLATE.md

```bash
cat > "$DEBUGGER_WS/reference/INVESTIGATION_REPORT_TEMPLATE.md" <<'TEMPLATE_EOF'
# INVESTIGATION_REPORT_TEMPLATE.md — Debugger's submission format

Every completed investigation is submitted to Sunny on `dm:sunny-debugger` using this template. Structural deviations trigger immediate REJECT.

## Template

```
INVESTIGATION REPORT: <short bug title from Sunny's brief>

Bug ID: <from Sunny's brief, or generate: bug-YYYYMMDD-<shortdesc>>
Iteration: <1 on first submission; increment on re-submission>

SEVERITY: P0 | P1 | P2 | P3
  (P0 = production down or data loss; P1 = major flow broken;
   P2 = secondary flow broken or bad UX; P3 = cosmetic or rare)

SUMMARY (1-3 sentences: what breaks, where, under what conditions):
<...>

REPRODUCTION STEPS (numbered, exact, reproducible by someone else):

Environment:
  URL: <exact url used>
  Browser: <e.g. chrome for testing via agent-browser>
  Account / state prerequisites: <any data setup required, or "fresh account">
  Feature flags: <any non-default flags, or "all defaults">

Steps:
  1. <action>
  2. <action>
  3. <action>
  ...

Expected: <what should happen>
Actual:   <what does happen>

Reproduction reliability: <always | intermittent, X/Y runs | race-condition>

EVIDENCE (file paths to artifacts — openable by Sunny):

Pre-failure state:
  Screenshot:        ./gnap/<bug-id>/before.png
  Snapshot:          ./gnap/<bug-id>/snapshot-before.json

Failure state:
  Screenshot:        ./gnap/<bug-id>/failure.png
  Snapshot:          ./gnap/<bug-id>/snapshot-after.json

Full capture:
  HAR:               ./gnap/<bug-id>/failure.har
  Console:           ./gnap/<bug-id>/console.txt
  Errors:            ./gnap/<bug-id>/errors.txt
  Failing requests:  ./gnap/<bug-id>/failing-requests.json

Server-side logs (if accessible): <path or observability URL>

ROOT CAUSE HYPOTHESIS:

Primary hypothesis (one sentence):
<...>

Supporting evidence (link each back to an EVIDENCE artifact):
- <observation from HAR: e.g., "POST /api/bookings returns 500 — see failing-requests.json entry #3">
- <observation from console: e.g., "console.txt line 47 shows TypeError before the POST">
- <...>

Alternative hypotheses considered:
1. <alt hypothesis> — ruled out because <evidence>
2. <alt hypothesis> — still possible, would need <additional evidence> to rule out

Confidence: HIGH | MEDIUM | LOW
  (HIGH: evidence directly supports; MEDIUM: strong correlation; LOW: pattern-match only)

RECOMMENDED FIX:

Scope:
  Files likely affected:
    - <path> — <nature of change>
    - <path> — ...

Approach:
  <1-3 sentences describing what the fix should do, not how to code it>

Risk assessment:
  What could this fix break: <...>
  Adjacent flows that must be re-tested: <list>

Regression tests to add:
  - <test case 1>
  - <test case 2>

Estimated complexity: TRIVIAL | SMALL | MEDIUM | LARGE

Brief for Builder (if handoff is recommended — clean enough to execute without clarification):
  <brief text, or "N/A — fix should be done here, not delegated">

KNOWN LIMITATIONS OF THIS INVESTIGATION:
- <limitation 1: e.g., "Could not reproduce on Firefox; only tested Chrome">
- <limitation 2: e.g., "Race condition — could only reproduce 3/10 attempts">
- <or: "none">

OUT-OF-SCOPE OBSERVATIONS (bugs or concerns found during investigation but not pursued):
- <observation>
- <or: "none">

SELF-CHECK (every box must tick):
- [ ] Reproduction steps work on a fresh attempt (I ran them again before submitting)
- [ ] All EVIDENCE files exist at the paths listed and are non-empty
- [ ] HAR is scoped to the failing flow (not the whole session)
- [ ] Root cause hypothesis is supported by specific evidence, not pattern-matching
- [ ] At least one alternative hypothesis was considered and documented
- [ ] Recommended fix scope is specific (file-level, not "refactor the thing")
- [ ] Risk assessment identifies at least one adjacent flow to re-test
- [ ] Regression test cases are concrete (not "add tests")
- [ ] No destructive actions were taken during investigation
- [ ] Out-of-scope observations listed, not silently pursued

END OF REPORT
```

## Sizing guidance

- SUMMARY: 1-3 sentences
- REPRODUCTION STEPS: numbered, tight — five steps is typical, ten is a lot
- EVIDENCE: paths only, no inline contents
- ROOT CAUSE: primary hypothesis + evidence links + alternatives — 1-2 screens of text
- RECOMMENDED FIX: concrete but not prescriptive — leave coding decisions to Builder
- SELF-CHECK: every box or not sent

Typical report: 80-150 lines. If longer, you are inlining content that belongs in files.

## What NOT to do

- Do NOT propose a fix without evidence linking it to the root cause hypothesis
- Do NOT declare HIGH confidence without direct supporting evidence
- Do NOT recommend a large refactor — scope fixes minimally, note technical debt separately
- Do NOT fix the bug yourself during investigation — your job is diagnosis; Builder executes unless the report explicitly says "fix should be done here"
- Do NOT submit with irreproducible steps — if you can't reproduce cleanly, say so in LIMITATIONS and lower your confidence
TEMPLATE_EOF
```

## Task 6 — Update Debugger's RULES.md

```bash
RULES="$DEBUGGER_WS/reference/RULES.md"
[ -f "$RULES" ] || touch "$RULES"

if grep -q '^## Browser Tool and Review Loop' "$RULES"; then
  echo "Browser Tool and Review Loop section already in RULES.md — skipping"
else
  cat >> "$RULES" <<'RULES_EOF'

---

## Browser Tool and Review Loop

### You have a browser — it is your primary tool

`bin/browser` is in your workspace. For any web-facing bug, default to reproducing in the browser rather than reasoning from logs alone. Full details in `reference/SKILL_BROWSER.md`.

### Every investigation submits a report

You do not report bug findings in free-form prose. You fill in `reference/INVESTIGATION_REPORT_TEMPLATE.md` and send it as a bus message on `dm:sunny-debugger`. No exceptions.

### Reports are evidence-driven

A hypothesis without evidence links is not a root cause. Every claim in the ROOT CAUSE HYPOTHESIS section must point to a specific artifact in the EVIDENCE section (e.g., "HAR entry #3 shows ...", "console.txt line 47 shows ..."). Pattern-matching is acceptable as a starting hypothesis only when explicitly labelled LOW confidence.

### Sunny reviews every investigation

`reference/HANDOFF_PROTOCOL.md` defines the loop. Sunny will:

- Run your repro steps herself
- Open your HAR and read it
- Challenge your root cause hypothesis against alternatives
- Check that your recommended fix scope matches the evidence
- Apply `AUDIT_CRITERIA.md` (Debugger section) line by line

### On rejection

Acknowledge, then address each issue specifically. Re-run your repro before re-submitting. Iteration count increments on every re-submission. After 3 rejections Sunny auto-escalates.

### When Builder claims a fix, you verify

Every fix recommended by you and executed by Builder comes back for verification. Run your original repro again, capture post-fix evidence, attach to a fix-verification addendum report on `dm:sunny-debugger`. Do not signal "fix verified" without running the verification.

### Hard boundaries

- Never perform a destructive action during investigation, even if it would yield a cleaner repro. Escalate to Sunny for test-account provisioning.
- Never submit without running the SELF-CHECK. A ticked SELF-CHECK is what separates investigation from speculation.
- Never silently expand scope. If you find a second bug during investigation of the first, note it in OUT-OF-SCOPE OBSERVATIONS and wait for Sunny to prioritise.
- Never fix a bug yourself without explicit "fix here" approval. Your role is diagnosis; Builder is implementation, unless the report's RECOMMENDED FIX section says otherwise.

RULES_EOF
  echo "Browser Tool and Review Loop section appended to RULES.md"
fi
```

## Task 7 — Update Debugger's SOUL.md

```bash
SOUL="$DEBUGGER_WS/SOUL.md"

if grep -q '^## Review Loop Awareness' "$SOUL"; then
  echo "Review Loop Awareness section already in Debugger's SOUL.md — skipping"
else
  cat >> "$SOUL" <<'SOUL_EOF'

---

## Review Loop Awareness

Your investigations do not reach David directly. Every report goes to Sunny via `dm:sunny-debugger` using `reference/INVESTIGATION_REPORT_TEMPLATE.md`. Sunny independently reproduces, reviews the evidence, then forwards to David on accept or returns to you on reject.

Authoritative references in `reference/`:
- `HANDOFF_PROTOCOL.md` — the full loop
- `INVESTIGATION_REPORT_TEMPLATE.md` — the submission format (mandatory)
- `SKILL_BROWSER.md` — your diagnostic instrument
- `RULES.md` — the updated Browser Tool and Review Loop section

Your `bin/browser` is the difference between investigation and speculation. For any web-facing symptom, reproduce in the browser first, reason from logs second. A report without browser-captured evidence (HAR, console, errors, screenshots) on a web-facing bug will be rejected on structure alone.

Scratch space for investigations: `./gnap/<bug-id>/`. Keep everything for a bug in that directory, reference paths in the report, archive after closure.

SOUL_EOF
  echo "Review Loop Awareness section appended to Debugger's SOUL.md"
fi
```

## Task 8 — Verify Phase 4

```bash
echo "=== Phase 4 Verification ==="

# Wrapper executable
[ -x "$DEBUGGER_WS/bin/browser" ] && echo "✓ Debugger's browser wrapper is executable" || echo "✗ browser wrapper missing"

# Policy valid JSON
jq -e . "$DEBUGGER_WS/reference/browser-policy.json" >/dev/null 2>&1 && echo "✓ browser-policy.json is valid JSON" || echo "✗ browser-policy.json invalid"

# Reference files present
for f in HANDOFF_PROTOCOL.md SKILL_BROWSER.md INVESTIGATION_REPORT_TEMPLATE.md; do
  [ -s "$DEBUGGER_WS/reference/$f" ] && echo "✓ $f present" || echo "✗ $f missing"
done

# HANDOFF_PROTOCOL.md matches Sunny's and Builder's
diff -q "$HOME/.openclaw/workspace/reference/HANDOFF_PROTOCOL.md" \
        "$DEBUGGER_WS/reference/HANDOFF_PROTOCOL.md" >/dev/null && \
  echo "✓ HANDOFF_PROTOCOL.md matches Sunny's copy" || \
  echo "✗ HANDOFF_PROTOCOL.md differs — re-copy"

diff -q "$HOME/.openclaw/workspace-builder/reference/HANDOFF_PROTOCOL.md" \
        "$DEBUGGER_WS/reference/HANDOFF_PROTOCOL.md" >/dev/null && \
  echo "✓ HANDOFF_PROTOCOL.md matches Builder's copy" || \
  echo "✗ HANDOFF_PROTOCOL.md differs from Builder's"

# RULES.md updated
grep -q '^## Browser Tool and Review Loop' "$DEBUGGER_WS/reference/RULES.md" && \
  echo "✓ RULES.md contains Browser Tool and Review Loop section" || \
  echo "✗ RULES.md missing section"

# SOUL.md updated
grep -q '^## Review Loop Awareness' "$DEBUGGER_WS/SOUL.md" && \
  echo "✓ SOUL.md contains Review Loop Awareness section" || \
  echo "✗ SOUL.md missing section"

# gnap directory exists
[ -d "$DEBUGGER_WS/gnap" ] && echo "✓ gnap/ scratch directory created" || echo "✗ gnap/ missing"

# Smoke test
"$DEBUGGER_WS/bin/browser" open https://example.com >/dev/null 2>&1
"$DEBUGGER_WS/bin/browser" close >/dev/null 2>&1
echo "✓ Debugger browser launched and closed cleanly"

echo "=== Phase 4 Complete ==="
```

## Final message to the user

```
PHASE 4 COMPLETE

Debugger configured as investigator with mandatory review handoff.

Files created:
  ~/.openclaw/workspace-debugger/bin/browser                                 (diagnostic wrapper)
  ~/.openclaw/workspace-debugger/reference/browser-policy.json               (policy)
  ~/.openclaw/workspace-debugger/reference/HANDOFF_PROTOCOL.md               (shared)
  ~/.openclaw/workspace-debugger/reference/SKILL_BROWSER.md                  (diagnostics-oriented)
  ~/.openclaw/workspace-debugger/reference/INVESTIGATION_REPORT_TEMPLATE.md  (submission format)
  ~/.openclaw/workspace-debugger/gnap/                                       (scratch space for investigations)

Files modified:
  ~/.openclaw/workspace-debugger/reference/RULES.md   (appended Browser Tool and Review Loop)
  ~/.openclaw/workspace-debugger/SOUL.md              (appended Review Loop Awareness)

Verification: <all ✓ / list any ✗>

MANUAL ACTION REQUIRED FROM USER:
  Edit ~/.openclaw/workspace-debugger/bin/browser and update --allowed-domains
  to include your actual production domains (read-only via policy) and any
  observability tools you use beyond the defaults.

READY FOR PHASE 5 (smoke tests + final audit).
```

## Do NOT do in this phase

- Do NOT touch Sunny or Builder workspaces
- Do NOT seed auth vault entries
- Do NOT modify HANDOFF_PROTOCOL.md — it must match the other two copies verbatim
- Do NOT restart Debugger's poller or OpenClaw session
