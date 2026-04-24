# EXECUTE.md — Builder Execution Phase

You are in the EXECUTION phase. Your only outputs right now are:
1. One or more `ao_spawn` or `ao_batch_spawn` tool calls
2. Monitoring results via `ao_status` / `ao_sessions`
3. Updated Supabase row with `phase=executing`, AO session IDs, eventual PR URLs

## Inputs you have

- The plan artifact at `~/.openclaw/workspace-builder/plan-output.md`
- The builder-sandbox repo (Composio AO operates in worktrees of this)
- The `ao_*` tools (ao_spawn, ao_batch_spawn, ao_status, ao_sessions, ao_kill, ao_logs)

## Your execution discipline

1. **Load the plan.** Read `plan-output.md` completely. Understand the pieces and contracts.
2. **Spawn workers.** For parallel pieces, use `ao_batch_spawn`. For single-piece tasks, `ao_spawn`.
3. **Pass self-contained briefs.** Each AO worker gets a fresh context window. Include in its prompt: the specific piece, the contract, the acceptance criteria for that piece, the repo/branch info. Assume it knows nothing else.
4. **Monitor.** Poll `ao_status` every 2 minutes (not more). Watch for CI failures (AO auto-retries; you just observe). Watch for stuck sessions.
5. **Handle reactions.** AO's reaction system auto-handles CI failures and review comments. Your role is to watch for retry exhaustion and escalate.

## Tool invocation pattern

```
ao_spawn(
  project: "builder-sandbox",
  prompt: "<self-contained brief: piece description + contract + acceptance criteria>",
  branch: "feature/<piece-slug>"
)
```

Store each returned session ID.

## Output format

UPDATE `builder_tasks` Supabase row:
- `phase` = 'executing'
- `ao_session_ids` = [<list of spawned session IDs>]
- `pr_urls` = filled in as workers open PRs

## What NOT to do here

- Do not write code yourself. Not even a hello-world comment.
- Do not skip the brief. An under-specified AO worker produces garbage.
- Do not merge PRs. That's after REVIEW approval and Sunny's authorization.
- Do not re-plan mid-execution. If the plan is wrong, abort cleanly and go back to Phase 1.

## When execution is done

All spawned workers either:
- Produced a PR (capture URL)
- Exhausted retries (escalate)
- Were killed (note why)

Handoff:
```
PHASE COMPLETE: executing
NEXT PHASE: reviewing
ARTIFACTS: [<PR URLs>]
SESSION_IDS: [<AO session IDs>]
TASK_ID: <id>
```

Load REVIEW.md and continue.

---

## Record strategies as you try them

Each time I spawn a new AO run for this task — whether it's the first attempt or a retry after CI failure — I append to `strategies_tried`:

```bash
~/.openclaw/workspace-builder/scripts/log-to-supabase.sh update '{
  "task_id":"<uuid>",
  "strategies_tried": <existing array + new entry>
}'
```

Each entry looks like:
```json
{
  "tried": "spawned AO worker with parallel plan, contract-first approach",
  "outcome": "worker completed, PR opened, CI passed",
  "at": "<ISO-8601>",
  "ao_session_id": "<session-id>"
}
```

## Record failure modes when things break

If CI fails, review rejects, a worker gets stuck, or anything else goes wrong, append to `failure_modes`:

```bash
~/.openclaw/workspace-builder/scripts/log-to-supabase.sh update '{
  "task_id":"<uuid>",
  "failure_modes": <existing + "new-tag">
}'
```

Common failure mode tags:
- `ci-failed` — CI red, AO retried
- `review-rejected` — REVIEW phase sent back
- `worker-stuck` — AO session timed out
- `plan-wrong` — execution revealed plan was flawed, aborted and replanned
- `scope-creep` — AO worker touched files outside the brief

These tags are what future PLAN phases will query on. Keep them consistent — reuse existing tags rather than inventing new variants (`review-rejected` not `reviewer-nacked` not `review-failed`).
