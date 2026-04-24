# TRIAGE.md — Debugger Triage Phase

You are in the TRIAGE phase. Outputs:
1. A reproduced bug (or an "I cannot reproduce" report)
2. Classified severity
3. Explicit acceptance criteria (what would prove it's fixed)
4. A gnap task written to `~/projects/debugger-sandbox/.gnap/tasks/`
5. Updated Supabase row with `phase=triaging`

## Discipline

1. **Read the bug report from Sunny in full.**
2. **Try to reproduce.** Actually attempt it. Clone the debugger-sandbox repo if needed. Run the scenario described. Watch the actual behavior.
3. **If you cannot reproduce:** stop. Do not proceed to fix phase. Report to Sunny: "Cannot reproduce. Need: <specifics>." This is not failure — it's essential gate-keeping.
4. **Classify severity:** critical | high | medium | low. Base on evidence, not urgency in the report.
5. **Write acceptance criteria.** What specifically would prove it's fixed? Not "bug no longer happens" — that's circular. "Running `<specific command>` produces `<specific result>` instead of `<previous result>`." A regression test that would have caught this bug is mandatory; describe it explicitly.
6. **Identify scope.** What files/modules are likely affected? Be conservative — don't speculate outside evidence.

## Output: the gnap task

Create `~/projects/debugger-sandbox/.gnap/tasks/BUG-<next-id>.json`:

```json
{
  "id": "BUG-<N>",
  "title": "<short title>",
  "desc": "BUG REPORT:\n<symptom>\n\nREPRODUCTION:\n<steps>\n\nEXPECTED:\n<what should happen>\n\nACTUAL:\n<what happens>\n\nSEVERITY: <classification>\n\nACCEPTANCE CRITERIA:\n- [ ] <criterion 1>\n- [ ] <criterion 2>\n- [ ] Regression test added: <description>\n\nSCOPE: <likely files/modules>",
  "assigned_to": ["investigator", "fixer"],
  "state": "ready",
  "priority": <severity-to-int>,
  "created_by": "debugger",
  "reviewer": "debugger",
  "created_at": "<ISO-8601>",
  "tags": ["bug"]
}
```

Commit and push:
```bash
cd ~/projects/debugger-sandbox
git add .gnap/tasks/BUG-<N>.json
git commit -m "debugger: create BUG-<N> — <short title>"
git push origin main
```

UPDATE Supabase `debugger_runs`:
- `triage_output` = the full task description above
- `gnap_task_ids` = ["BUG-<N>"]
- `phase` = 'triaging' → 'investigating' at handoff

## What NOT to do

- Do not propose fixes. TRIAGE is analysis, not prescription.
- Do not skip reproduction. "It looks like X" is not triage.
- Do not assign to yourself. Investigator and fixer are separate agents in the gnap registry.

## Handoff

```
PHASE COMPLETE: triage
NEXT PHASE: investigate
GNAP_TASK: BUG-<N>
TASK_ID: <run-id>
```

Load INVESTIGATE.md.

---

## Query history before triaging

Before writing the triage report, I extract topical tags from the bug description (e.g. `auth`, `race-condition`, `timeout`, `memory-leak`) and run:

```bash
~/.openclaw/workspace-debugger/gnap-scripts/query-history.sh <tag1> <tag2> ...
```

This shows the last 10 completed runs with overlapping tags — their root causes, strategies tried, failure modes.

**What to look for:**

- **Recurrence.** Has the same bug shape appeared before? If yes: is this a new instance of the same underlying issue, or a regression of a prior fix? Flag loudly to Sunny.
- **Pattern.** Are there 3+ past runs with `failure_modes: ["cannot-reproduce"]` on similar tags? That's a design issue manifesting as "unreproducible bugs" — escalate beyond "fix one instance."
- **Prior root causes.** If the tag `auth` has 5 prior runs all with `root_cause` referencing the same module, the auth module has a structural problem. Name it.

## Tag the run at triage

Include tags in the initial Supabase upsert:

```bash
~/.openclaw/workspace-debugger/gnap-scripts/log-to-supabase.sh debugger_runs upsert '{
  "run_id":"<uuid>",
  "bug_brief":"...",
  "phase":"triaging",
  "tags":["auth","race-condition"],
  "strategies_tried":[],
  "failure_modes":[]
}'
```
