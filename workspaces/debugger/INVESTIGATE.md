# INVESTIGATE.md — Debugger Investigation/Fix Coordination

You are in the INVESTIGATE/FIX phase. You don't investigate or fix directly — the gnap-registered investigator and fixer agents do. Your job is to observe and nudge.

## What's happening underneath

The `investigator` and `fixer` agents (registered in `~/projects/debugger-sandbox/.gnap/agents.json`) are running their own heartbeat loops. They:
1. Pull the repo
2. Read the gnap task you created
3. Investigator explores → writes findings to `.gnap/runs/BUG-<N>-1.json`
4. Fixer reads findings → implements + test → commits → updates run
5. Task state transitions `in_progress` → `review` when fixer believes it's done

Both agents see each other's commits in real time. The "shared sandbox" is the git repo itself.

## Your monitoring discipline

1. **Poll the gnap task state every 2 minutes.** `cat ~/projects/debugger-sandbox/.gnap/tasks/BUG-<N>.json | jq .state`
2. **Watch for stuck states.** If `in_progress` for >30 min with no new commits, check:
   - `git log --since="30 min ago"` — are they committing?
   - `.gnap/runs/BUG-<N>-*.json` — latest run state?
   - `.gnap/messages/` — anything blocked?
3. **Read messages for Debugger.** Check `.gnap/messages/*.json` where `to` contains `"debugger"`. Respond if they're asking you something (e.g., "cannot reproduce step X, is this correct?").
4. **DO NOT JUMP IN AND FIX.** Even if you see the bug. Your agent role is investigation coordinator, not fixer.

## When Phase 2 is done

The task transitions to `state: review`. The fixer has committed the fix + regression test. At this point:
- Pull the latest
- Verify the task.json has `state: review`
- Latest run exists at `.gnap/runs/BUG-<N>-<attempt>.json` with `state: completed` and a meaningful `result`
- Commits on main include the fix

UPDATE Supabase `debugger_runs`:
- `phase` = 'investigating' or 'fixing' depending on the latest run's state
- `root_cause` = extract from the latest run's `result` field

## Timeouts and escalation

- Task stuck `in_progress` >60 min → post a message to investigator + fixer asking status
- Task stuck >120 min → escalate to Sunny
- Task transitions to `blocked` → read `blocked_reason` and forward to Sunny

## Handoff

When task.state becomes 'review':
```
PHASE COMPLETE: investigate/fix
NEXT PHASE: verify
GNAP_TASK: BUG-<N>
LATEST_RUN: BUG-<N>-<attempt>
COMMITS: [<SHAs>]
```

Load VERIFY.md.

---

## Record strategies and failure modes

As gnap runs unfold, I append what the investigator and fixer are trying and how it's going:

```bash
~/.openclaw/workspace-debugger/gnap-scripts/log-to-supabase.sh debugger_runs update '{
  "run_id":"<uuid>",
  "strategies_tried": <existing + new entry>
}'
```

Each entry:
```json
{
  "tried": "investigator hypothesis: stale cache in auth middleware",
  "outcome": "confirmed via log trace at line 142",
  "at": "<ISO-8601>",
  "gnap_run_id": "BUG-7-1"
}
```

When the fixer's work gets verified and rejected, when investigator blocks on "cannot reproduce", when gnap gets stuck — log to `failure_modes`:

- `cannot-reproduce` — investigator could not trigger the bug
- `verify-rejected` — Debugger's VERIFY phase sent it back
- `regression` — the "fix" re-broke something else
- `gnap-stuck` — a heartbeat agent stopped responding
- `root-cause-wrong` — fix addressed symptom, not cause
