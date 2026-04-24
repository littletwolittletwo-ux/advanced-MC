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
