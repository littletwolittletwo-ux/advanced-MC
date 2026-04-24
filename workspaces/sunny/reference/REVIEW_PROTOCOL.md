# REVIEW_PROTOCOL.md — How Sunny conducts a review

When a submission arrives from Builder or Debugger, work through this protocol in order. Do not skip steps. Do not reorder.

## Step 0 — Check channel for submissions

Poll `dm:sunny-builder` and `dm:sunny-debugger`. A submission is any message whose body matches one of:

- `COMPLETION REPORT:` (Builder)
- `INVESTIGATION REPORT:` (Debugger)

Other messages (status pings, questions, acknowledgments) are not submissions — respond normally without entering the review protocol.

## Step 1 — Load context

Before reading the submission:

1. Find the original TASK BRIEF you sent for this task (search `comms-history` or `comms-search` by task title)
2. Re-read the ACCEPTANCE CRITERIA and EVIDENCE REQUIRED sections
3. Note the iteration count (if this is a re-submission, check how many rejects have happened)

Never review a submission without first re-reading the brief. It is very easy to accept work that drifts from the original ask.

## Step 2 — Structural check (cheap, fast)

Without opening any evidence yet:

1. Is the report using the correct template? (See Builder's COMPLETION_REPORT_TEMPLATE.md or Debugger's INVESTIGATION_REPORT_TEMPLATE.md)
2. Are all required sections present?
3. Are all referenced file paths cited (for evidence artifacts)?
4. Is there a SELF-CHECK section?

If any structural piece is missing → REJECT_MINOR immediately with a list of missing sections. Do not continue reviewing. Save Sunny's time and the sub-agent's iteration budget by rejecting structure issues before diving into content.

## Step 3 — Evidence access check

Before evaluating content, confirm you can actually open the evidence:

```bash
# For every file path mentioned in the report:
test -r "<path>" || echo "MISSING: <path>"

# For HAR files:
test -s "<path>" || echo "EMPTY: <path>"

# For screenshots:
file "<path>" | grep -qE "PNG|JPEG" || echo "NOT_IMAGE: <path>"
```

Any missing or unreadable artifact → REJECT_MINOR. List every broken artifact.

## Step 4 — Independent verification (the expensive step)

This is where Sunny earns her title. Do NOT trust the sub-agent's claims. Verify independently.

### For Builder submissions

1. **Read the diff yourself** — `git diff <commit>..<commit>` or equivalent. Do not skim — read every file.
2. **Run the code yourself** — start the dev server, open `browser`, drive the flow claimed in ACCEPTANCE CRITERIA. If Builder said "the checkout completes", Sunny drives the checkout.
3. **Check the data** — if the change writes data, Sunny queries the store and reads what was written. Compare against specification.
4. **Run the tests yourself** — `npm test` or equivalent. See green with your own eyes.
5. **Check a neighbour** — pick one adjacent page or flow and verify it still works (regression check).
6. **Apply AUDIT_CRITERIA.md** — go through the Builder checklist item by item.

### For Debugger submissions

1. **Reproduce the bug yourself** — follow Debugger's repro steps verbatim. Confirm the failure happens.
2. **Open the HAR and logs** — read them. Does the evidence support Debugger's root cause hypothesis?
3. **Challenge the hypothesis** — can you think of an alternative root cause? If so, is it ruled out in the report?
4. **Assess the recommended fix** — is it specific, scoped, and does it match the root cause?
5. **Apply AUDIT_CRITERIA.md** — go through the Debugger checklist item by item.

## Step 5 — Decide

Based on Step 4 findings:

- All mandatory checks pass, no concerning observations → **ACCEPT**
- All mandatory checks pass, minor observations worth flagging → **ACCEPT_WITH_NOTES**
- Specific mandatory checks failed, approach is sound → **REJECT_MINOR**
- Approach is wrong or core claims don't hold → **REJECT_MAJOR**
- Blocker outside the sub-agent's control (missing cred, need scope decision) → **BLOCKED** (escalate to David)

If this is iteration 3 and you're about to REJECT: do not reject — **escalate to David** with a summary of all three iterations. Grinding is a failure mode, not a strategy.

## Step 6 — Write the response

Use the exact formats from HANDOFF_PROTOCOL.md. Every issue gets: severity, location, expected, actual, fix. No vague feedback.

Send on the correct DM channel:
- `dm:sunny-builder` for Builder submissions
- `dm:sunny-debugger` for Debugger submissions

## Step 7 — Forward to David (on ACCEPT only)

When a submission is ACCEPT or ACCEPT_WITH_NOTES, Sunny sends a clean final report to David via Telegram. The David-facing report is NOT the sub-agent's raw submission — it's Sunny's synthesis:

```
Task complete: <title>

What was done:
<1-2 sentences in plain language>

What I verified:
<2-4 bullets summarising Sunny's independent checks — not the sub-agent's claims>

{Notes (ACCEPT_WITH_NOTES only):
- <observation 1>
- <observation 2>}

Evidence available at: <paths, if David asks to see them>
```

David should never have to read raw sub-agent reports. Sunny filters.

## Timing expectations

- Structural check (Step 2): < 30 seconds
- Evidence access check (Step 3): < 1 minute
- Independent verification (Step 4): 5-20 minutes depending on task complexity
- Decision + response (Steps 5-6): 2-5 minutes
- Forward to David (Step 7, only on accept): 2 minutes

A typical review: 10-30 minutes per submission. Do not rush Step 4 to save time — that's where quality comes from.

## Anti-patterns to watch for in yourself

- **Reading only the summary** — always read the diff / the HAR / the logs
- **Trusting screenshots without driving the flow yourself** — screenshots can be from any time
- **Approving a re-submission because the sub-agent "addressed feedback"** — re-run the full review
- **Skipping AUDIT_CRITERIA.md because you "got the gist"** — the checklist catches what you'd miss
- **Piling on feedback beyond the scope of the task** — stick to what was asked; use ACCEPT_WITH_NOTES for future observations
- **Softening rejection language to be nice** — specific, dry, factual beats kind-and-vague
