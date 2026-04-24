# PLAN.md — Builder Planning Phase

You are in the PLANNING phase. Your only outputs right now are:
1. A structured plan document
2. An updated Supabase row with `phase=planning`
3. A handoff signal to move to EXECUTE phase

## Inputs you have

- The task brief from Sunny
- The builder-sandbox repo at `~/projects/builder-sandbox`
- Any prior Supabase `builder_tasks` rows (query for context on recurring patterns)

## Your planning discipline

1. **Read the task brief adversarially.** What is vague? What's missing? What's hidden behind "obviously"?
2. **Decompose into pieces.** Ask: which parts are genuinely independent (parallelizable) vs sequentially dependent?
3. **Write the contracts.** For any two pieces that will run in parallel, define the interfaces between them. Data shapes, API contracts, file ownership. "The auth module produces a User object shaped `{id, email, role}` and the API consumes it from `src/types/user.ts`." If you can't write the contract, the pieces aren't truly independent — merge them.
4. **Write acceptance criteria.** For each piece and for the whole, what specifically would prove it's done? Not vibes — checkable things. "README updated" is vibes. "README contains a 'Usage' section with at least one code example" is checkable.
5. **Identify risks.** What could go wrong in execution? Which pieces are most likely to fail verification? Flag them.

## Output format

Write to `~/.openclaw/workspace-builder/plan-output.md`:

```
# Plan for task: <task-id>

## Pieces
1. <piece-1-name> — <what it does>
   Independent: yes|no (depends on: <piece-id>)
   Contract: <inputs → outputs>
2. ...

## Acceptance criteria
- [ ] <criterion 1>
- [ ] <criterion 2>
...

## Risks
- <risk 1 and mitigation>

## Execution plan
Parallel spawn: [<piece-ids>]
Sequential after: [<piece-ids>]
```

Also UPDATE `builder_tasks` Supabase row:
- `plan_output` = full text of the above
- `phase` = 'planning' → then 'executing' right before handoff

## What NOT to do here

- Do not call `ao_spawn` in this phase. That's EXECUTE.
- Do not write code. That's what AO workers do.
- Do not decide the review is "probably fine" based on the plan. Review is its own phase.
- Do not skip contracts. Parallel work without contracts is where bugs are born.

## When you are done

Handoff message to yourself (next context load will be EXECUTE):
```
PHASE COMPLETE: planning
NEXT PHASE: executing
ARTIFACT: ~/.openclaw/workspace-builder/plan-output.md
TASK_ID: <id>
```

Then load EXECUTE.md and continue.

---

## Query history before decomposing

Before writing the plan, I extract topical tags from the task brief (e.g. `auth`, `migration`, `api`, `refactor`) and run:

```bash
~/.openclaw/workspace-builder/scripts/query-history.sh <tag1> <tag2> ...
```

The output shows the last 10 completed tasks with overlapping tags — including what was tried, what broke, what failure modes recurred. I factor this into the plan explicitly:

- If a past task with similar tags had `failure_modes: ["review-rejected"]` three times, I ask: what did those reviewers catch? Am I about to fall into the same trap?
- If a past task's `strategies_tried` shows an approach that failed, I don't re-propose it unless I can explain what's different now.
- If nothing similar exists, I proceed without historical anchoring and note "first task of this shape" in the plan output.

## Tag the task at plan time

The plan output must include a `tags` field — 2-5 lowercase topical keywords. Written to Supabase as part of the initial upsert:

```bash
~/.openclaw/workspace-builder/scripts/log-to-supabase.sh upsert '{
  "task_id":"<uuid>",
  "brief":"...",
  "phase":"planning",
  "tags":["auth","migration"],
  "strategies_tried":[],
  "failure_modes":[]
}'
```

Tags are what makes future history queries useful. Be specific enough that the tag is meaningful, general enough that a future task can match on it.
