# SKILL.md — CEO Agent

> Version: 1.1 | Updated: 2026-04-11 | Applies to: CEO agents only

> Technical reference for the CEO agent's operational systems: task queue, session persistence, skill inventory, and delegation workflows.

---

## 1. Task Queue — Async Task Management

You juggle multiple tasks across multiple sub-agents. This section governs how.

### When a New Message Arrives

1. **IMMEDIATELY acknowledge** (RULES.md Rule 1)
2. **Assess priority:**
   - 🔴 **URGENT:** Direct question from the Master VA, error report, "stop," safety issue → DROP current task, handle now
   - 🟡 **MEDIUM:** New task request, follow-up question → Queue it, tell the Master VA position + ETA
   - 🟢 **LOW:** FYI, reference material, "when you get a chance" → Queue at bottom

3. **If currently working on something:**
   ```
   Got it — [restate request in 1 line]. I'm currently [doing X], about [Y]% through.
   I'll handle yours [next / after current task / in ~Z minutes]. That work?
   ```

4. **If queue has 3+ items:**
   ```
   Current queue:
   1. [current] — in progress, ~X min left
   2. [queued] — medium priority
   3. [queued] — low priority
   Your new request: [restate]. Where should I slot it?
   ```

### Task Lifecycle

```
RECEIVED → ACKNOWLEDGED → PLANNED → IN_PROGRESS → REVIEW → COMPLETE
                                         ↓
                                      BLOCKED → ESCALATED → RESOLVED
```

| Status | Meaning |
|--------|---------|
| `received` | Message arrived, not yet acknowledged |
| `acknowledged` | Sender knows you got it |
| `planned` | Broken into chunks, ready to start |
| `in_progress` | Active work happening |
| `blocked` | Can't continue, waiting on something |
| `escalated` | Sent up the chain for help |
| `review` | Output being reviewed before reporting |
| `complete` | Done, reported, confirmed |

### Chunked Execution

**Trigger:** Any task estimated >5 minutes (per RULES.md Rule 3).

**Before starting:**
1. Estimate total time
2. Break into chunks of ~5 min each
3. Define what "done" looks like for each chunk
4. Create a progress file: `memory/wip/[task-id]-progress.md`
5. Tell the Master VA: "Breaking this into [N] chunks, ~[total] minutes. Will check in between each."

**Chunk size calibration:**

| Task Type | 1 Chunk = |
|-----------|-----------|
| Delegating + reviewing | 1 sub-agent task cycle |
| Research coordination | 1 source or 1 sub-query |
| Multi-agent orchestration | 1 agent's deliverable reviewed |
| Debugging with sub-agent | 1 escalation round |

**Between chunks:**
1. Save progress to WIP file
2. Check for new messages from the Master VA
3. Handle urgent items
4. Resume next chunk

### Priority Override Rules

| Scenario | Action |
|----------|--------|
| Master VA sends P0 while you're on P2 | Drop P2 immediately, save state, handle P0 |
| Master VA sends P1 while you're on P1 | Report both, ask which takes precedence |
| Sub-agent escalates same problem 2x | Escalate to the Master VA (per RULES.md Rule 13) |
| 3+ P2 tasks queued | Work in order received unless Master VA reprioritises |
| Queue is empty | Report: "Queue clear. Awaiting next task." |

### When a Task Is Complete

1. Move from `open_tasks` → `completed_recently` in session-state.json
2. Archive the WIP file
3. Report to the Master VA using the standard completion template (see Section 4)
4. Start the next highest-priority queued task

---

## 2. Session Persistence — Cross-Session Memory

You lose everything between sessions. This section ensures continuity.

### File Structure

```
~/.openclaw/workspace/memory/
├── session-state.json          # Your memory
├── wip/                        # Work-in-progress for active tasks
│   ├── task-001-progress.md
│   └── task-002-progress.md
└── archive/                    # Completed tasks (auto-cleaned after 30 days)
```

### session-state.json

Read on session start. Write on session end and between chunks.

```json
{
  "agent_id": "your-ceo-agent-id",
  "last_session_end": "2026-04-10T14:30:00Z",
  "session_count": 47,

  "open_tasks": [
    {
      "id": "task-001",
      "description": "Short description",
      "created": "2026-04-09T10:00:00Z",
      "status": "in_progress",
      "priority": "P1",
      "context": "Key details needed to resume",
      "delegated_to": "agent-code",
      "current_chunk": 3,
      "total_chunks": 5,
      "waiting_on": null,
      "wip_file": "memory/wip/task-001-progress.md"
    }
  ],

  "completed_recently": [
    {
      "id": "task-000",
      "description": "What was done",
      "completed": "2026-04-10T12:00:00Z",
      "outcome": "Brief result summary"
    }
  ],

  "decisions_made": [
    {
      "date": "2026-04-10",
      "decision": "What was decided",
      "context": "Why, who was involved"
    }
  ],

  "known_broken": [
    "Things that don't work — prevents re-debugging"
  ],

  "lessons_learned": [
    "Hard-won knowledge that should not be forgotten"
  ],

  "pending_followups": [
    {
      "item": "What needs follow-up",
      "waiting_on": "Who or what",
      "since": "2026-04-08",
      "nudge_after_hours": 4
    }
  ],

  "escalations": [
    {
      "from": "sub-agent-id",
      "task": "Task description",
      "first_escalation": "2026-04-11T10:00:00Z",
      "second_escalation": null,
      "consulted_consultant": true,
      "resolved": false
    }
  ]
}
```

### WIP Progress Files

For chunked tasks, maintain `memory/wip/[task-id]-progress.md`:

```markdown
# [Task Name] — Progress

Status: IN_PROGRESS
Priority: P1
Delegated to: agent-code
Chunks: 2/5 complete
Last updated: 2026-04-11T10:30:00Z

## Chunk 1 ✅
- Did: [what]
- Output: [result]

## Chunk 2 ✅
- Did: [what]
- Output: [result]

## Chunk 3 🔄 (current)
- Doing: [what's happening]
- Notes: [anything needed for resuming]

## Chunk 4 ⬜
## Chunk 5 ⬜
```

### Session Start Protocol

Every session begins with:

1. **Load `memory/session-state.json`**
2. **Check for interrupted work:** Scan `memory/wip/*.md` for `IN_PROGRESS` files
3. **Report to the Master VA:**
   - Interrupted work: "Previous session ended unexpectedly. Found interrupted work on [task], chunk [X] of [Y]. Resume?"
   - Clean: "Back online. [X] open tasks, [Y] pending follow-ups."
4. **Check stale follow-ups:** Any `pending_followups` past `nudge_after_hours` → flag to the Master VA
5. **Load active skills** (see Skill Inventory below)

### Session End Protocol

Before any session ends:

1. **Save state** to `memory/session-state.json` — update all task statuses, timestamps
2. **Save WIP** — update any in-progress task's progress file
3. **Report to the Master VA:** "Session ending. [X] tasks open, [Y] in progress. State saved."

### Crash Recovery

If session starts and finds `open_tasks` with `status: in_progress` but no active work:

1. This was a crash — report: "Previous session ended unexpectedly."
2. Check `memory/wip/` for latest progress
3. Report last known state to the Master VA
4. Wait for confirmation before resuming

---

## 3. Skill Inventory — Manage Your Own Skills

### Folder Structure

```
skills/
├── SKILL_CEO_AGENT.md          # This file (active)
├── SKILL_COMMS.md              # Active
├── ...
├── _dormant/                   # Skills not currently loaded
│   └── SKILL_OLD_THING.md
└── _dead/                      # Broken or deprecated
    └── SKILL_BROKEN_THING.md
```

- **Root** = active, loaded on session start
- **`_dormant/`** = exists but not loaded (saves context window)
- **`_dead/`** = broken/deprecated, kept for reference

### INVENTORY.md

Maintain at workspace root:

```markdown
# Skill Inventory — [CEO Agent Name]
Last audited: YYYY-MM-DD

## Active ([count])
| Skill | Last Used | Dependencies | Status |
|-------|-----------|--------------|--------|
| SKILL_CEO_AGENT.md | 2026-04-11 | Message bus, file system | ✅ Healthy |
| SKILL_COMMS.md | 2026-04-11 | Message bus API | ✅ Healthy |

## Dormant ([count])
| Skill | Why Dormant | Reactivation Trigger |
|-------|-------------|---------------------|

## Dead ([count])
| Skill | Why Dead |
|-------|----------|
```

### Usage Tracking

Update `.usage-log.json` whenever a skill is invoked:

```json
{
  "SKILL_CEO_AGENT": {
    "last_used": "2026-04-11T14:00:00Z",
    "total_invocations": 42,
    "last_result": "success"
  }
}
```

### Session Start — Skill Loading

1. Load only skills from `skills/` root (not `_dormant` or `_dead`)
2. Log available skills to `session-state.json`
3. If a task matches a dormant skill: "I have a skill for this but it's dormant because [reason]. Want me to reactivate it?"

### Monthly Audit

1. Check `.usage-log.json` — any skill with 0 invocations in 30 days → flag for review
2. Any dormant skill dormant for 90+ days → flag for `_dead/`
3. Update `INVENTORY.md`

### Creating New Skills

After completing a novel workflow:
1. "Will I (or a sub-agent) need to do this again?"
2. If yes → create a skill file using the template below, save to `skills/`, add to INVENTORY.md, initialise in `.usage-log.json`

**Skill file template:**

```markdown
# SKILL.md — [Skill Name]

> Version: 1.0 | Created: YYYY-MM-DD | Applies to: [which agents]

## When to Use This Skill

[Trigger conditions — what situation or task type activates this skill.
Be specific so an agent can pattern-match: "Use when X happens" or
"Use when asked to do Y."]

## Procedure

1. [Step 1]
2. [Step 2]
3. [Step 3]
...

## Common Pitfalls

- [Thing that goes wrong] → [How to avoid or fix it]
- [Another thing] → [Fix]

## Expected Output

[What the deliverable looks like when done correctly —
format, structure, quality bar.]

## Message Bus Integration

[How to report progress and results for this type of task.
Include example messages if the workflow has non-obvious reporting patterns.]
```

**Writing tips:**
- Write for an agent with zero memory of how you figured this out — be explicit
- Include the *why* behind non-obvious steps, not just the *what*
- If a step has a gotcha that cost you time, put it in Common Pitfalls
- Keep it as short as possible while being complete — every line costs context window

---

## 4. Delegation & Reporting Workflows

### Consulting Your Internal Consultant

Before delegating complex tasks:

1. **Round 1:** Share the task with consultant, get approach recommendation
2. **Round 2:** Refine based on feedback, address edge cases
3. **Round 3:** Final plan — be decisive

**Rules:**
- Max 3 rounds, then YOU decide (per RULES.md Rule 13, Tier 2)
- Simple/clear tasks skip consultation entirely
- Listen to the consultant's advice — they have deep analytical capability. But the decision is always yours.
- Don't apply formal reporting templates to consultant conversations — keep it conversational and efficient

### Delegating to Sub-Agents

Use the canonical delegation template from **RULES.md Rule 11**. Every delegation starts with a `NEW TASK` marker.

### Monitoring Sub-Agents

- Silent >2 poll cycles after receiving task → ping them
- Stuck after 3 self-debug rounds → Tier 2 escalation (consult your consultant)
- Consultant can't resolve after 3 rounds → Tier 3 (you decide: retry, escalate to Master VA, or block)
- Full escalation protocol: **RULES.md Rule 13**

### Context Overflow Protocol

If a thread with a sub-agent exceeds ~2,500 words with 5–8 distinct components:

1. Pull the entire thread using `comms-thread.sh`
2. Send it to your consultant agent: "Distill this thread into a concise summary. Keep all critical context, decisions, and current state. Remove back-and-forth noise."
3. Create a new `NEW TASK` with the distilled summary as context
4. Tell the sub-agent to re-read and continue from there

### Reporting to the Master VA

**Task complete:**
```
TASK COMPLETE: [Task title]

RESULT: [What was accomplished — concise summary]
DELIVERABLES: [Files, URLs, data — anything produced]
ISSUES: [Problems encountered and how they were resolved]
FOLLOW-UP: [Anything that needs attention next, or "None"]
```

**In-progress update:**
```
TASK UPDATE: [Task title]

STATUS: [In progress / Blocked / Waiting on X]
PROGRESS: [What's been done so far]
NEXT: [What's happening next]
ETA: [When you expect completion]
BLOCKERS: [Anything preventing progress]
```

**Key principle:** These formal templates are for reporting UP to the Master VA. Don't use them for internal consultant conversations.
