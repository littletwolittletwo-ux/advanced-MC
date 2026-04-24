# Phase 5 — Smoke Tests and Final Audit

You are running two end-to-end smoke tests to confirm the QA loop works, then a final audit checklist to catch any configuration gaps. After this phase, the system is ready for real work.

This phase requires David (the user) to participate in a couple of places — mostly to trigger the tests and confirm he sees the expected outputs. Pause and ask for his input where noted.

## Pre-check

Confirm Phases 1-4 completed:

```bash
# Phase 1
[ -f "$HOME/.agent-browser/.encryption-key" ] || { echo "Phase 1 incomplete"; exit 1; }

# Phase 2 (Sunny)
for f in bin/browser reference/browser-policy.json reference/HANDOFF_PROTOCOL.md \
         reference/AUDIT_CRITERIA.md reference/REVIEW_PROTOCOL.md; do
  [ -e "$HOME/.openclaw/workspace/$f" ] || { echo "Phase 2 incomplete: $f missing"; exit 1; }
done
grep -q '^## Review Protocol' "$HOME/.openclaw/workspace/SOUL.md" || { echo "Phase 2 incomplete: SOUL.md"; exit 1; }

# Phase 3 (Builder)
for f in bin/browser reference/browser-policy.json reference/HANDOFF_PROTOCOL.md \
         reference/SKILL_BROWSER.md reference/COMPLETION_REPORT_TEMPLATE.md; do
  [ -e "$HOME/.openclaw/workspace-builder/$f" ] || { echo "Phase 3 incomplete: $f missing"; exit 1; }
done

# Phase 4 (Debugger)
for f in bin/browser reference/browser-policy.json reference/HANDOFF_PROTOCOL.md \
         reference/SKILL_BROWSER.md reference/INVESTIGATION_REPORT_TEMPLATE.md; do
  [ -e "$HOME/.openclaw/workspace-debugger/$f" ] || { echo "Phase 4 incomplete: $f missing"; exit 1; }
done

echo "All prerequisite phases complete — proceeding with Phase 5."
```

## Task 1 — Seed one test vault entry (ask David to run this)

**Pause and ask David**: "I need to seed one test credential into the auth vault to verify the vault works. Can you run the command below with a throwaway set of credentials — literally any test account you have for a dev site, or I can use `httpbin.org/basic-auth/testuser/testpass` which is a public test endpoint."

Default command (safe, public test endpoint):

```bash
# Seed a no-risk test entry using httpbin's public basic-auth endpoint
echo "testpass" | agent-browser --session builder auth save httpbin-test \
  --url "https://httpbin.org/basic-auth/testuser/testpass" \
  --username testuser \
  --password-stdin
```

Then confirm the entry is listed:

```bash
agent-browser --session builder auth list
```

Expected output: `httpbin-test` appears in the list. The vault is working.

Do the same for debugger session if you want parity:

```bash
echo "testpass" | agent-browser --session debugger auth save httpbin-test \
  --url "https://httpbin.org/basic-auth/testuser/testpass" \
  --username testuser \
  --password-stdin
```

## Task 2 — Round-trip drill 1: Builder loop

This drill confirms: Sunny can send a task brief → Builder receives it → Builder produces a completion report in the correct format → Sunny reviews it → Sunny issues an accept/reject → Builder acknowledges.

Use a deliberately trivial task so success depends on the protocol, not the task difficulty.

### 2a. Sunny sends a task brief to Builder

Run this as Sunny (either by asking Sunny's session to run it, or by executing directly on behalf of Sunny):

```bash
TASK_ID="smoke-build-$(date +%Y%m%d-%H%M%S)"

bash "$HOME/.openclaw/workspace/comms/scripts/comms-send.sh" \
  dm:sunny-builder \
  "NEW TASK: Browser tool smoke test $TASK_ID

CONTEXT:
We are smoke-testing the QA review loop. This is not real work. The only goal
is to exercise: brief → execution → evidence capture → report → review → accept.

INSTRUCTIONS:
Use your bin/browser to open https://example.com, take a screenshot, read the
page title, and write both to evidence files under ./evidence/$TASK_ID/.
Then fill in reference/COMPLETION_REPORT_TEMPLATE.md and submit on
dm:sunny-builder.

ACCEPTANCE CRITERIA:
1. Screenshot exists at ./evidence/$TASK_ID/example.png
2. Page title saved to ./evidence/$TASK_ID/title.txt, content is 'Example Domain'
3. Completion report follows the template structure (all sections present)
4. Report's SELF-CHECK has every box ticked

EVIDENCE REQUIRED:
- Screenshot file path
- Title file path
- Console output confirming clean state

PRIORITY: P3

DEADLINE: 30 minutes

RESOURCES:
- bin/browser (your wrapper)
- reference/COMPLETION_REPORT_TEMPLATE.md (mandatory format)
- reference/SKILL_BROWSER.md (how to use the tool)" P3
```

Confirm the message posted:

```bash
# Check Builder's inbox has it (within 30s, the poller should have picked it up)
curl -sS -H "X-API-Key: $BUS_API_KEY" \
  "${BUS_API_URL}/messages/poll?agent=builder&limit=5" | jq '.[].body | capture("smoke-build-[0-9-]+")' | head -3
```

### 2b. Wait for Builder's completion report

Poll `dm:sunny-builder` for a message starting with `COMPLETION REPORT:` referencing the same TASK_ID. Expected timeline: Builder's poller wakes within 30s, then Builder has 30 minutes per the deadline — but for a task this trivial, completion should be within a few minutes.

Pause and ask David: "Task dispatched to Builder. Expected a completion report on `dm:sunny-builder` within ~5 minutes. Let me know when it arrives — or if it doesn't within 10 minutes, we'll debug."

When the report arrives, run structural checks:

```bash
# Fetch the latest message on dm:sunny-builder
REPORT=$(curl -sS -H "X-API-Key: $BUS_API_KEY" \
  "${BUS_API_URL}/messages?channel=dm:sunny-builder&limit=1" | jq -r '.[0].body')

echo "$REPORT" | grep -q "^COMPLETION REPORT:" && echo "✓ Correct report prefix" || echo "✗ Wrong report format"
echo "$REPORT" | grep -q "Task ID: $TASK_ID" && echo "✓ Task ID matches" || echo "✗ Task ID missing"
echo "$REPORT" | grep -q "ACCEPTANCE CRITERIA" && echo "✓ Acceptance criteria section present" || echo "✗ Missing acceptance criteria"
echo "$REPORT" | grep -q "EVIDENCE" && echo "✓ Evidence section present" || echo "✗ Missing evidence section"
echo "$REPORT" | grep -q "SELF-CHECK" && echo "✓ Self-check section present" || echo "✗ Missing self-check"
```

### 2c. Verify evidence artifacts

```bash
EVIDENCE="$HOME/.openclaw/workspace-builder/evidence/$TASK_ID"
[ -f "$EVIDENCE/example.png" ] && echo "✓ Screenshot exists" || echo "✗ Screenshot missing at $EVIDENCE/example.png"
[ -f "$EVIDENCE/title.txt" ] && echo "✓ Title file exists" || echo "✗ Title file missing"
grep -q "Example Domain" "$EVIDENCE/title.txt" 2>/dev/null && echo "✓ Title content correct" || echo "✗ Title content wrong"
file "$EVIDENCE/example.png" 2>/dev/null | grep -q "PNG" && echo "✓ Screenshot is valid PNG" || echo "✗ Screenshot not a valid PNG"
```

### 2d. Sunny reviews and responds

Run Sunny's verification independently (not trusting Builder's report):

```bash
# Sunny uses her own browser to confirm
"$HOME/.openclaw/workspace/bin/browser" open https://example.com >/dev/null
SUNNY_TITLE=$("$HOME/.openclaw/workspace/bin/browser" get title)
"$HOME/.openclaw/workspace/bin/browser" close >/dev/null

echo "Sunny's independent title: $SUNNY_TITLE"
echo "$SUNNY_TITLE" | grep -qi "example domain" && echo "✓ Sunny confirms title independently" || echo "✗ Sunny's check disagrees"
```

Then Sunny sends the review decision:

```bash
bash "$HOME/.openclaw/workspace/comms/scripts/comms-send.sh" \
  dm:sunny-builder \
  "REVIEW RESULT: ACCEPT

Task: Browser tool smoke test $TASK_ID
Iterations taken: 1

Verified:
- Screenshot exists at evidence path — confirmed with file check
- Title file content matches 'Example Domain' — confirmed by independent browser check by me
- Report structure complete — all template sections present, SELF-CHECK ticked

Final report going to David now." P3
```

Confirm Builder acknowledges (typically a short ack message on `dm:sunny-builder`).

### 2e. Drill 1 outcome

```
DRILL 1 RESULT:
  Task dispatched:        PASS / FAIL
  Builder acknowledged:   PASS / FAIL
  Report received:        PASS / FAIL
  Report structure:       PASS / FAIL
  Evidence artifacts:     PASS / FAIL
  Sunny's independent:    PASS / FAIL
  Accept message sent:    PASS / FAIL
  Builder ack'd accept:   PASS / FAIL
```

If any step failed, stop and debug before running Drill 2. Common causes: poller not running, channel misconfigured, Builder's OpenClaw session not waking, evidence dir permissions.

## Task 3 — Round-trip drill 2: Debugger loop

Same shape, different agent. Investigating a fake "bug" on a known-behaviour site.

### 3a. Sunny sends an investigation brief

```bash
BUG_ID="smoke-bug-$(date +%Y%m%d-%H%M%S)"

bash "$HOME/.openclaw/workspace/comms/scripts/comms-send.sh" \
  dm:sunny-debugger \
  "NEW TASK: Bug investigation smoke test $BUG_ID

CONTEXT:
Smoke-testing the investigation loop. Not a real bug. Goal: exercise brief →
repro → evidence capture → investigation report → review → accept.

INSTRUCTIONS:
httpbin.org/status/500 returns HTTP 500. Treat this as a 'bug': investigate
why a request to that URL fails. Capture the full evidence suite (HAR,
console, errors, screenshots), formulate a root cause (trivially: the
endpoint is designed to return 500), and propose a 'fix' (trivially: use
a different endpoint). Fill in INVESTIGATION_REPORT_TEMPLATE.md and submit.

ACCEPTANCE CRITERIA:
1. HAR captured at ./gnap/$BUG_ID/failure.har, non-empty, contains the 500 response
2. Console dump at ./gnap/$BUG_ID/console.txt
3. Errors dump at ./gnap/$BUG_ID/errors.txt
4. Screenshot at ./gnap/$BUG_ID/failure.png
5. Report follows INVESTIGATION_REPORT_TEMPLATE.md structure
6. Root cause hypothesis cites specific HAR entry as evidence
7. At least one alternative hypothesis considered
8. SELF-CHECK has every box ticked

EVIDENCE REQUIRED:
- All file paths from acceptance criteria 1-4
- Investigation report on dm:sunny-debugger

PRIORITY: P3

DEADLINE: 30 minutes

RESOURCES:
- bin/browser (diagnostic wrapper)
- reference/INVESTIGATION_REPORT_TEMPLATE.md (mandatory format)
- reference/SKILL_BROWSER.md (reproduction workflow)" P3
```

### 3b. Wait for investigation report

Same pattern — poll `dm:sunny-debugger` for a message starting with `INVESTIGATION REPORT:`.

### 3c. Structural check

```bash
REPORT=$(curl -sS -H "X-API-Key: $BUS_API_KEY" \
  "${BUS_API_URL}/messages?channel=dm:sunny-debugger&limit=1" | jq -r '.[0].body')

echo "$REPORT" | grep -q "^INVESTIGATION REPORT:" && echo "✓ Correct prefix" || echo "✗ Wrong prefix"
echo "$REPORT" | grep -q "Bug ID: $BUG_ID" && echo "✓ Bug ID matches" || echo "✗ Bug ID missing"
for section in "REPRODUCTION STEPS" "EVIDENCE" "ROOT CAUSE HYPOTHESIS" "RECOMMENDED FIX" "SELF-CHECK"; do
  echo "$REPORT" | grep -q "$section" && echo "✓ $section section present" || echo "✗ Missing $section"
done
```

### 3d. Evidence artifacts check

```bash
GNAP="$HOME/.openclaw/workspace-debugger/gnap/$BUG_ID"
[ -s "$GNAP/failure.har" ] && echo "✓ HAR non-empty" || echo "✗ HAR missing or empty"
[ -f "$GNAP/console.txt" ] && echo "✓ Console dump exists" || echo "✗ Console missing"
[ -f "$GNAP/errors.txt" ] && echo "✓ Errors dump exists" || echo "✗ Errors missing"
[ -f "$GNAP/failure.png" ] && file "$GNAP/failure.png" | grep -q PNG && echo "✓ Screenshot valid" || echo "✗ Screenshot invalid"

# HAR should actually contain a 500 response
jq -e '.log.entries[] | select(.response.status == 500)' "$GNAP/failure.har" >/dev/null 2>&1 && \
  echo "✓ HAR contains a 500 response" || echo "✗ HAR missing expected 500"
```

### 3e. Sunny reviews independently

```bash
# Sunny reproduces the 500 herself
"$HOME/.openclaw/workspace/bin/browser" open https://httpbin.org/status/500 >/dev/null 2>&1
SUNNY_STATUS=$("$HOME/.openclaw/workspace/bin/browser" network requests --status 5xx --json 2>/dev/null | jq -r '.[0].status // empty')
"$HOME/.openclaw/workspace/bin/browser" close >/dev/null 2>&1

[ "$SUNNY_STATUS" = "500" ] && echo "✓ Sunny reproduces 500 independently" || echo "✗ Sunny's repro disagrees"
```

### 3f. Sunny accepts

```bash
bash "$HOME/.openclaw/workspace/comms/scripts/comms-send.sh" \
  dm:sunny-debugger \
  "REVIEW RESULT: ACCEPT

Task: Bug investigation smoke test $BUG_ID
Iterations taken: 1

Verified:
- Reproduction steps followed, 500 confirmed via my own browser
- HAR artifact opened, contains the 500 response as claimed
- Root cause hypothesis aligns with evidence
- Alternative hypothesis present and reasonable
- Report structure complete

Final report going to David now." P3
```

### 3g. Drill 2 outcome

```
DRILL 2 RESULT:
  Task dispatched:        PASS / FAIL
  Debugger acknowledged:  PASS / FAIL
  Report received:        PASS / FAIL
  Report structure:       PASS / FAIL
  Evidence artifacts:     PASS / FAIL
  HAR contains 500:       PASS / FAIL
  Sunny's independent:    PASS / FAIL
  Accept message sent:    PASS / FAIL
```

## Task 4 — Final audit checklist

A comprehensive config verification. Everything should be green before the system is declared ready.

```bash
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  FINAL AUDIT                                             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0
check() { if eval "$2"; then echo "  ✓ $1"; PASS=$((PASS+1)); else echo "  ✗ $1"; FAIL=$((FAIL+1)); fi; }

echo "── agent-browser install"
check "agent-browser on PATH"                                "command -v agent-browser >/dev/null"
check "Chrome for Testing downloaded"                        "agent-browser install 2>&1 | grep -qiE 'already|installed|ready'"
check "Encryption key exists"                                "[ -f \"$HOME/.agent-browser/.encryption-key\" ]"
check "Encryption key has correct permissions (600)"         "[ \"\$(stat -f '%A' \"$HOME/.agent-browser/.encryption-key\" 2>/dev/null || stat -c '%a' \"$HOME/.agent-browser/.encryption-key\")\" = '600' ]"

echo ""
echo "── Profile directories"
for a in sunny builder debugger; do
  check "profiles/$a exists" "[ -d \"$HOME/.agent-browser/profiles/$a\" ]"
done

echo ""
echo "── Sunny (reviewer)"
S="$HOME/.openclaw/workspace"
check "bin/browser executable"                               "[ -x \"$S/bin/browser\" ]"
check "browser-policy.json valid JSON"                       "jq -e . \"$S/reference/browser-policy.json\" >/dev/null 2>&1"
check "browser-policy denies eval"                           "jq -e '.rules[] | select(.action==\"eval\" and .effect==\"deny\")' \"$S/reference/browser-policy.json\" >/dev/null"
check "browser-policy denies fill"                           "jq -e '.rules[] | select(.action==\"fill\" and .effect==\"deny\")' \"$S/reference/browser-policy.json\" >/dev/null"
check "HANDOFF_PROTOCOL.md present"                          "[ -s \"$S/reference/HANDOFF_PROTOCOL.md\" ]"
check "AUDIT_CRITERIA.md present"                            "[ -s \"$S/reference/AUDIT_CRITERIA.md\" ]"
check "REVIEW_PROTOCOL.md present"                           "[ -s \"$S/reference/REVIEW_PROTOCOL.md\" ]"
check "SOUL.md has Review Protocol section"                  "grep -q '^## Review Protocol' \"$S/SOUL.md\""

echo ""
echo "── Builder"
B="$HOME/.openclaw/workspace-builder"
check "bin/browser executable"                               "[ -x \"$B/bin/browser\" ]"
check "browser-policy.json valid JSON"                       "jq -e . \"$B/reference/browser-policy.json\" >/dev/null 2>&1"
check "browser-policy denies eval"                           "jq -e '.rules[] | select(.action==\"eval\" and .effect==\"deny\")' \"$B/reference/browser-policy.json\" >/dev/null"
check "HANDOFF_PROTOCOL.md matches Sunny's"                  "diff -q \"$S/reference/HANDOFF_PROTOCOL.md\" \"$B/reference/HANDOFF_PROTOCOL.md\" >/dev/null"
check "SKILL_BROWSER.md present"                             "[ -s \"$B/reference/SKILL_BROWSER.md\" ]"
check "COMPLETION_REPORT_TEMPLATE.md present"                "[ -s \"$B/reference/COMPLETION_REPORT_TEMPLATE.md\" ]"
check "RULES.md has Browser Tool section"                    "grep -q '^## Browser Tool and Review Loop' \"$B/reference/RULES.md\""
check "SOUL.md has Review Loop Awareness"                    "grep -q '^## Review Loop Awareness' \"$B/SOUL.md\""
check "comms-config.json still valid"                        "jq -e . \"$B/comms-config.json\" >/dev/null 2>&1"

echo ""
echo "── Debugger"
D="$HOME/.openclaw/workspace-debugger"
check "bin/browser executable"                               "[ -x \"$D/bin/browser\" ]"
check "browser-policy.json valid JSON"                       "jq -e . \"$D/reference/browser-policy.json\" >/dev/null 2>&1"
check "browser-policy denies eval"                           "jq -e '.rules[] | select(.action==\"eval\" and .effect==\"deny\")' \"$D/reference/browser-policy.json\" >/dev/null"
check "HANDOFF_PROTOCOL.md matches Sunny's"                  "diff -q \"$S/reference/HANDOFF_PROTOCOL.md\" \"$D/reference/HANDOFF_PROTOCOL.md\" >/dev/null"
check "SKILL_BROWSER.md present"                             "[ -s \"$D/reference/SKILL_BROWSER.md\" ]"
check "INVESTIGATION_REPORT_TEMPLATE.md present"             "[ -s \"$D/reference/INVESTIGATION_REPORT_TEMPLATE.md\" ]"
check "RULES.md has Browser Tool section"                    "grep -q '^## Browser Tool and Review Loop' \"$D/reference/RULES.md\""
check "SOUL.md has Review Loop Awareness"                    "grep -q '^## Review Loop Awareness' \"$D/SOUL.md\""
check "gnap/ directory exists"                               "[ -d \"$D/gnap\" ]"
check "comms-config.json still valid"                        "jq -e . \"$D/comms-config.json\" >/dev/null 2>&1"

echo ""
echo "── Auth vault"
check "httpbin-test vault entry (builder)"                   "agent-browser --session builder auth list 2>/dev/null | grep -q httpbin-test"

echo ""
echo "── Smoke drill results"
check "Drill 1 (Builder loop) passed"                        "true"   # set false manually if drill failed
check "Drill 2 (Debugger loop) passed"                       "true"   # set false manually if drill failed

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
printf  "║  RESULT: %d passed, %d failed%*s║\n" "$PASS" "$FAIL" $((30 - ${#PASS} - ${#FAIL})) ""
echo "╚══════════════════════════════════════════════════════════╝"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "One or more checks failed. System is NOT ready for production use."
  echo "Fix each ✗ above and re-run the audit."
  exit 1
fi
```

## Task 5 — Final handoff message to the user

On full pass, print:

```
╔══════════════════════════════════════════════════════════════════╗
║  AGENT QA SYSTEM — READY FOR PRODUCTION USE                      ║
╚══════════════════════════════════════════════════════════════════╝

What's live:
  • Sunny — reviewer with read-only browser, AUDIT_CRITERIA, REVIEW_PROTOCOL
  • Builder — implementer with dev-scope browser, COMPLETION_REPORT_TEMPLATE
  • Debugger — investigator with diagnostic browser, INVESTIGATION_REPORT_TEMPLATE
  • Shared HANDOFF_PROTOCOL.md identical across all three workspaces
  • Auth vault seeded with test entry; encryption key secured
  • Both round-trip drills passed (Builder loop and Debugger loop)
  • Final audit: all checks green

How to use it:
  1. David assigns a task to Sunny (Telegram, as normal)
  2. Sunny decomposes and delegates to Builder or Debugger via bus
  3. Sub-agent does the work, captures evidence, submits report
  4. Sunny reviews independently using AUDIT_CRITERIA.md
  5. Sunny accepts → forwards synthesis to David
  6. Sunny rejects → sub-agent iterates (max 3 iterations before escalation)

What you still need to tune manually (not automated):
  • ~/.openclaw/workspace-builder/bin/browser   — edit --allowed-domains
  • ~/.openclaw/workspace-debugger/bin/browser  — edit --allowed-domains
  • Seed production-relevant vault entries (as needed, per site)
  • Adjust browser-policy.json rules if your app has specific dangerous-action
    text patterns not covered by the default deny list

First real task:
  Start with a P2 task — something non-critical — so you can observe the loop
  running on real work and adjust AUDIT_CRITERIA.md thresholds to your taste.

Rollback if needed: see MASTER_SEQUENCE.md rollback section.
```

## Do NOT do in this phase

- Do NOT skip the smoke drills even if everything looks fine statically
- Do NOT edit any config files during the audit — fix by re-running the relevant phase
- Do NOT declare ready if any check fails
- Do NOT remove the test vault entry — it's useful for future smoke-testing
