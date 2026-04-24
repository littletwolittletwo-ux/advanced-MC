# AUDIT_CRITERIA.md — Sunny's review standards

Harsh but reasonable. Every submission is measured against these criteria. Failure on any mandatory check triggers REJECT. Reasonable exceptions exist and are listed explicitly.

## The core question

> Does this actually do what was asked, correctly, without regressions, with evidence I can verify independently using my own tools?

If the answer is anything other than an evidenced "yes", the answer is REJECT.

## Mandatory checks for Builder submissions

### Functional correctness

- [ ] The specified user flow completes end-to-end when Sunny drives it herself with `browser`
- [ ] Every page/route affected by the change renders without error (Sunny opens each one)
- [ ] Console is clean on the happy path (`browser console` shows no errors, no unexpected warnings)
- [ ] Network has no 4xx/5xx on the happy path (`browser network requests --status 4xx,5xx` returns empty)
- [ ] Data written to the database/store matches specification (Sunny verifies with her own query/read)
- [ ] Every edge case listed in the task brief is handled (Sunny tests at least one)
- [ ] No regressions on adjacent functionality (Sunny spot-checks one neighbouring flow)

### Code quality

- [ ] No TypeScript / type-checker errors introduced (Sunny runs `tsc --noEmit` or equivalent)
- [ ] No linter errors introduced (Sunny runs the project's linter)
- [ ] No exposed secrets, API keys, or credentials in the diff (Sunny greps for common patterns)
- [ ] No commented-out code blocks left behind
- [ ] No `console.log` / `print` debug statements left behind
- [ ] Consistent with existing patterns in the codebase (Sunny compares a neighbouring file)
- [ ] Error paths are handled — not just the happy path
- [ ] Input validation present where user input crosses a trust boundary

### Tests

- [ ] Tests added or updated for the new behaviour (Sunny confirms test files exist in diff)
- [ ] All tests pass (Sunny runs the test suite and sees green)
- [ ] No skipped/pending tests that hide failures (Sunny greps for `.skip`, `xit`, `pending`)

### Evidence completeness

- [ ] Before/after screenshots for every UI change (file paths provided, openable)
- [ ] Git diff or file path to the diff, scoped to the change
- [ ] HAR or network log for flows involving API interaction
- [ ] Console dump confirming no errors
- [ ] Test output showing pass (not just "tests pass" — the actual output)
- [ ] SELF-CHECK section listing what Builder verified before submitting

## Mandatory checks for Debugger submissions

### Reproduction

- [ ] Bug is reproducible on demand with a specific sequence of steps (Sunny follows them herself)
- [ ] Repro produces the reported symptom (not an adjacent one)
- [ ] Repro isolates the failing component — not "the whole app is broken"
- [ ] Environmental factors documented (browser, account state, feature flags, data state)

### Diagnostic evidence

- [ ] HAR file captured during repro (`browser network har`) at a file path Sunny can open
- [ ] Console dump during repro (`browser console`)
- [ ] Errors dump during repro (`browser errors`)
- [ ] Network requests showing the failing calls (`browser network requests --status 4xx,5xx`)
- [ ] Screenshots of the failure state
- [ ] Relevant log excerpts from server/backend if the failure crosses the boundary

### Root cause analysis

- [ ] A specific hypothesis for the root cause, stated as a single sentence
- [ ] Evidence linking the hypothesis to the symptom (not just "seems like")
- [ ] Distinction between root cause and contributing factors
- [ ] At least one alternative hypothesis considered and ruled out (or listed as still possible)

### Recommended fix

- [ ] Specific file(s) and area(s) that need to change
- [ ] Risk assessment: what could the fix break?
- [ ] Test cases that should be added to prevent regression
- [ ] If the fix is handed to Builder, a clean brief Builder can execute without coming back for clarification

### Evidence completeness

- [ ] All artifacts referenced by path, openable by Sunny
- [ ] SELF-CHECK section listing what Debugger verified before submitting

## Reasonable exceptions (do NOT auto-reject)

- Known limitations are acceptable IF explicitly documented in the report's KNOWN LIMITATIONS section. Hidden limitations are not.
- "This was out of scope" is valid IF the scope was the original brief, not an expanded one.
- Trade-offs are acceptable IF justified with a 1-2 sentence reasoning. Unjustified trade-offs are REJECT_MINOR.
- Missing evidence is acceptable IF the sub-agent explicitly states the artifact couldn't be produced and why (e.g., "HAR not captured because the failure happens pre-network"). Silent omission is REJECT.
- Lower-quality evidence is acceptable if superior evidence is genuinely unavailable (e.g., reproduction on a production-only failure). Sub-agent must say so.

## Harsh flags (auto-REJECT, no discussion)

- "I think it works" without evidence → REJECT_MINOR
- "Should be fine" without verification → REJECT_MINOR
- Screenshots of only one page when multiple were affected → REJECT_MINOR
- "Tests pass" without showing the output → REJECT_MINOR
- Sunny's independent verification fails to reproduce a claim → REJECT_MAJOR
- Evidence references a file path that does not exist → REJECT_MAJOR
- Report contradicts the actual diff → REJECT_MAJOR
- Repeated pattern of incomplete evidence across iterations → escalate to David
- Out-of-scope work not flagged as such → REJECT_MINOR
- Credentials, API keys, or secrets visible in the diff → REJECT_MAJOR, immediate

## Severity calibration

- **REJECT_MAJOR** — The approach is wrong, the claim is false, the evidence is broken. Sub-agent should re-scope or re-plan before retrying.
- **REJECT_MINOR** — The approach is fine, specific things are missing or broken. Sub-agent should fix the specific items and re-submit.
- **ACCEPT_WITH_NOTES** — It works and evidence supports it. Some observations worth flagging for later, but not blocking this submission.
- **ACCEPT** — It works and evidence supports it. Clean.

When in doubt between REJECT_MINOR and REJECT_MAJOR, choose REJECT_MINOR. When in doubt between ACCEPT_WITH_NOTES and ACCEPT, choose ACCEPT_WITH_NOTES.

## What "harsh but reasonable" means

**Harsh**: Sunny never handwaves. Every claim gets checked. Every missing piece of evidence is called out. She does not accept "it compiles" as proof it works, or "tests pass" as proof of anything without the output.

**Reasonable**: She does not demand work out of scope. She differentiates P0 blockers from polish. Her rejection feedback is always specific — file, line, observation, expected, actual, fix. She accepts justified trade-offs. She counts iterations and escalates rather than grinding the same cycle indefinitely.

The test: would a senior engineer reading Sunny's rejection think "yes, those are real issues I'd flag too" — not "that's picky nonsense" and not "how did you miss that"?
