# HANDOFF_PROTOCOL.md

Shared protocol for Sunny, Builder, and Debugger. Every task completed by Builder or Debugger passes through Sunny for independent review before anything is reported to David.

## Roles in this loop

- **David** — assigns tasks (via Telegram to Sunny), receives final outcomes
- **Sunny** — decomposes, delegates, reviews, reports back to David. Final gatekeeper.
- **Builder** — implements code changes. Submits completion reports with evidence.
- **Debugger** — investigates bugs. Submits investigation reports with evidence.

## The loop

```
1. David  → Sunny     (task brief, via Telegram)
2. Sunny  → sub-agent (dm:sunny-{builder|debugger} with decomposed brief)
3. Sub-agent works
4. Sub-agent → Sunny  (completion or investigation report with evidence)
5. Sunny reviews independently using AUDIT_CRITERIA.md and her own `browser` tool
6. One of:
     ACCEPT           → Sunny → David (final report)
     ACCEPT_WITH_NOTES → Sunny → David (final report + notes)
     REJECT_MINOR     → Sunny → sub-agent (specific fixes required, re-submit)
     REJECT_MAJOR     → Sunny → sub-agent (approach wrong, re-scope before retry)
     BLOCKED          → Sunny → David (external input needed, escalation)
7. On reject: sub-agent iterates, re-submits, go to step 5
8. Max 3 reject cycles before mandatory escalation to David
```

## Task brief format (Sunny → sub-agent)

When Sunny delegates, her message on `dm:sunny-{agent}` MUST contain:

```
NEW TASK: <short title>

CONTEXT:
<what's the situation, why does it matter>

INSTRUCTIONS:
<what to do, specific and bounded>

ACCEPTANCE CRITERIA:
<what "done" looks like — concrete, verifiable>

EVIDENCE REQUIRED:
<the specific artifacts the report must contain>

PRIORITY: P0 | P1 | P2 | P3

DEADLINE: <time or "best effort">

RESOURCES:
<file paths, URLs, vault names, prior context>
```

Sub-agents who receive a task missing ACCEPTANCE CRITERIA or EVIDENCE REQUIRED must reply asking for them before starting work. Do not guess.

## Completion / investigation report format (sub-agent → Sunny)

Sub-agents submit reports via `dm:sunny-{agent}` when work is done. Report format is defined per-agent in their workspace's `COMPLETION_REPORT_TEMPLATE.md` (Builder) or `INVESTIGATION_REPORT_TEMPLATE.md` (Debugger). All reports must:

- Be self-contained (Sunny should not have to ask for missing evidence)
- Reference file paths for any artifacts >2KB (screenshots, HARs, logs), not inline contents
- Explicitly state which ACCEPTANCE CRITERIA from the brief have been met, one by one
- Declare any known limitations up front (do not hide them)
- End with a section titled `SELF-CHECK` listing what the sub-agent verified before submitting

## Sunny's review decision tree

1. **Completeness check** — Is every required evidence artifact present and openable? If no → REJECT_MINOR, list missing items.
2. **Independent verification** — Using `browser`, git, file reads, DB queries: does Sunny's own check match the sub-agent's claims? If no → REJECT_MAJOR, describe the discrepancy.
3. **Audit criteria** — Apply every mandatory check from AUDIT_CRITERIA.md. If any fails → REJECT_MINOR or REJECT_MAJOR (her judgment call on severity).
4. **Scope discipline** — Did the sub-agent stay within the task brief? Out-of-scope additions require explicit justification. Unjustified scope creep → REJECT_MINOR.
5. **If all pass** → ACCEPT (or ACCEPT_WITH_NOTES if she noticed future-improvement opportunities worth flagging).

## Rejection message format (Sunny → sub-agent)

```
REVIEW RESULT: REJECT_{MINOR|MAJOR}

Task: <title from original brief>
Iteration: <n> of 3

ISSUES (every issue must be specific and actionable):

1. <issue>
   Severity: {blocker|major|minor}
   Where: <file:line or URL or screenshot ref>
   Expected: <what it should do/show>
   Actual: <what Sunny observed>
   Fix: <what needs to change>

2. <next issue>
   ...

MUST RE-SUBMIT WITH:
- <specific evidence or fix>
- <...>

DO NOT:
- <things the sub-agent should not retry differently>

This is iteration <n> of 3. After iteration 3, the task auto-escalates to David.
```

## Acceptance message format (Sunny → sub-agent)

```
REVIEW RESULT: ACCEPT{,_WITH_NOTES}

Task: <title>
Iterations taken: <n>

Verified:
- <criterion 1> — confirmed via <method>
- <criterion 2> — confirmed via <method>
- ...

{NOTES (if ACCEPT_WITH_NOTES):
- <future improvement or observation, non-blocking>}

Final report going to David now.
```

## Escalation message format (Sunny → David)

```
ESCALATION: {BLOCKED|MAX_ITERATIONS_HIT|EXTERNAL_INPUT_NEEDED}

Task: <title>
Sub-agent: {builder|debugger}

What happened:
<concise summary>

What I've tried:
<decisions Sunny made along the way>

What I need from you:
<specific: a credential, a decision, a policy override, a scope re-definition>
```

## Hard rules

1. Sub-agents NEVER report directly to David. All work flows through Sunny.
2. Sunny NEVER accepts a submission on trust. She independently verifies.
3. "I think it works" without evidence is an automatic REJECT_MINOR.
4. Feedback must be specific. "Make it better" is not feedback.
5. After 3 reject cycles on the same task, auto-escalate — do not keep grinding.
6. Sub-agents must acknowledge rejection feedback before starting the next iteration.
