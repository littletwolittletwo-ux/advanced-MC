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
