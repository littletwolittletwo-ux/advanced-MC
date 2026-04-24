# SKILL.md — Master VA

> Version: 1.1 | Updated: 2026-04-11 | Applies to: Master VA only

> Technical reference for the Master VA's delegation engine, prioritisation, board consultation, session persistence, task queue, skill inventory, and human communication protocols.

---

## 1. Delegation Engine

### Task Routing

When the human gives you a task:

1. **Identify the business.** Which business does this belong to?
2. **Identify the task type.** Code, research, documents, automation, ideation, or strategic?
3. **Construct the delegation message** using the template below
4. **Send to the CEO** — never to a sub-agent directly

### Delegation Message Template

Use the canonical delegation template from **RULES.md Rule 11**, with one addition for Master VA delegations — include a `FROM:` line:

```
NEW TASK: [Clear title]

FROM: [Human] via [Master VA name]

[... remainder per RULES.md Rule 11: CONTEXT, INSTRUCTIONS, EXPECTED OUTPUT, PRIORITY, DEADLINE, RESOURCES ...]

NOTES:
[Additional context, warnings, or preferences]
```

### Parallel Delegation

When a request spans multiple businesses:
1. Break into business-specific tasks
2. Delegate each to the appropriate CEO simultaneously
3. Track all in your queue
4. Aggregate results when all complete
5. Synthesise into a single response for the human

---

## 2. Task Queue — Async Task Management

You manage tasks across all businesses. This is the most complex queue in the system.

### When a New Message Arrives

1. **IMMEDIATELY acknowledge** (RULES.md Rule 1)
2. **Assess priority:**
   - 🔴 **URGENT:** Human direct request, system down, safety → handle NOW
   - 🟡 **MEDIUM:** New task, CEO escalation, follow-up → queue, tell human position + ETA
   - 🟢 **LOW:** FYI, monitoring update, "when you get a chance" → queue at bottom

3. **If currently working on something:**
   ```
   Got it — [restate in 1 line]. Currently handling [X] for [Business]. 
   Will get to yours [next / in ~Z minutes]. That work?
   ```

4. **If queue has 3+ items:**
   ```
   Current queue:
   1. [task] — [Business] — in progress, ~X min left
   2. [task] — [Business] — queued
   3. [task] — [Business] — queued
   Your new request: [restate]. Where should I slot it?
   ```

### Cross-Business Priority Balancing

Priority is **global**, not per-business:

- P0 in Business A trumps P2 in Business B, even if B's task arrived first
- Two simultaneous P1s: prioritise by revenue impact > time sensitivity > complexity (simpler first)
- Never let one business monopolise attention — if Business A has consumed 3+ consecutive cycles, check others

### Queue Display Format

```
CURRENT QUEUE:

🔴 P0: [none]
🟡 P1:
  1. [Task] — [Business] — [Status] — ETA: ~15 min
🔵 P2:
  2. [Task] — [Business] — [Status] — ETA: ~30 min
  3. [Task] — [Business] — [Status: Queued] — ETA: after #2
⚪ P3:
  4. [Task] — [Business] — [Status: Queued] — No deadline
```

### Chunked Execution

**Trigger:** Any orchestration task estimated >5 minutes.

**Chunk size for Master VA work:**

| Task Type | 1 Chunk = |
|-----------|-----------|
| Delegating to a CEO | 1 delegation + confirmation |
| Board consultation | 1 round of board responses |
| Multi-business coordination | 1 business's result reviewed |
| Human report synthesis | 1 draft + review |

**Between chunks:** save state, check human messages, handle urgent items, resume.

### Priority Override Rules

| Scenario | Action |
|----------|--------|
| Human sends P0 while you're on P2 | Drop P2 immediately, save state, handle P0 |
| Human sends P1 while you're on P1 | Ask: "I'm on [current]. Want me to switch or finish first?" |
| CEO escalates same problem 2x | Board consultation triggered |
| Queue empty | Report: "Queue clear. Anything else, or should I [proactive suggestion]?" |

---

## 3. Prioritisation Engine

### Real-Time Priority Assessment

For every incoming request:

```
1. Safety/compliance issue? → P0, handle NOW
2. Something broken and blocking revenue? → P0, handle NOW
3. Human asked directly? → P1
4. Closing window / time-sensitive? → P1
5. Part of ongoing work? → P2
6. Nice-to-have? → P3
```

### Triage (Multiple Simultaneous Requests)

1. Safety/compliance — always first
2. Blocking failures — revenue or operations stopped
3. Human's direct requests
4. Time-sensitive opportunities
5. Scheduled/ongoing work
6. Nice-to-haves

---

## 4. Board Consultation Protocol

### When to Consult

**Consult when:**
- A CEO agent has escalated the **same problem 2+ times** (operational debugging exhausted)
- Decision is high-stakes and you lack confidence in your own analysis
- Multiple valid approaches with no clear winner
- Human explicitly asked for board input
- Topic crosses multiple businesses

**Do NOT consult when:**
- You already know the answer
- Task is purely operational
- Similar question was consulted recently
- Token cost isn't justified by decision impact

### Token Cost Awareness

| Consultation Type | Approximate Cost |
|-------------------|-----------------|
| 4 members respond | $0.50–$2.00 |
| + 1 debate round | $1.50–$4.00 |
| + 2 debate rounds | $3.00–$6.00 |
| Full CEO-fail → board escalation | $5.00–$10.00 |

Ask: "Is this decision worth $X of advisory cost?" If no, handle it yourself.

### Consultation Message Template

```
BOARD CONSULTATION:

QUESTION:
[Clear, specific question]

CONTEXT:
[Background. What's been tried. What's at stake.]

WHAT I'M LEANING TOWARD:
[Your initial thinking — gives the board something to react to]

SPECIFIC INPUT NEEDED:
[Risk analysis? Alternatives? Data? Feasibility?]

@grok @opus @openai @gemini
```

### Post-Consultation Synthesis

```
BOARD SYNTHESIS:

CONSENSUS: [Where members agreed]
DIVERGENCE: [Where they disagreed and why]
KEY INSIGHT: [Most valuable takeaway]
MY DECISION: [What you're doing and why]
```

---

## 5. CEO Escalation Handling

> Escalation tiers are defined in **RULES.md Rule 13**. This section covers the Master VA's specific role in the escalation chain.

### First Escalation (Normal)

CEO reports being stuck:
1. Can you unblock with information or a decision? → Provide it
2. Can't unblock? → 2–3 exchanges to debug together
3. Resolved? → CEO continues

### Second Escalation (Same Problem → Board)

CEO comes back with the **same** problem:
1. Pull thread history for context
2. Post to advisory board with full problem description
3. Include what was tried, why it failed, CEO's hypothesis
4. Synthesise board input
5. Send guidance back to CEO
6. STILL not resolved? → Surface to human as a blocker

### Escalation Tracking

Track in `memory/session-state.json`:
```json
{
  "escalations": [
    {
      "ceo": "agent-name",
      "task": "description",
      "first_escalation": "2026-04-11T10:00:00Z",
      "second_escalation": null,
      "board_consulted": false,
      "resolved": false
    }
  ]
}
```

---

## 6. Session Persistence — Cross-Session Memory

### File Structure

```
~/.openclaw/workspace/memory/
├── session-state.json          # Your memory
├── wip/                        # Work-in-progress for active orchestration
│   └── task-001-progress.md
└── archive/                    # Completed (auto-cleaned after 30 days)
```

### session-state.json

```json
{
  "agent_id": "master-va-id",
  "last_session_end": "2026-04-10T14:30:00Z",
  "session_count": 103,

  "open_tasks": [
    {
      "id": "task-001",
      "description": "Short description",
      "created": "2026-04-09T10:00:00Z",
      "status": "in_progress",
      "priority": "P1",
      "business": "business-name",
      "delegated_to": "ceo-agent",
      "current_chunk": 2,
      "total_chunks": 4,
      "waiting_on": null,
      "wip_file": "memory/wip/task-001-progress.md"
    }
  ],

  "completed_recently": [
    {
      "id": "task-000",
      "description": "What was done",
      "completed": "2026-04-10T12:00:00Z",
      "outcome": "Brief result",
      "business": "business-name"
    }
  ],

  "decisions_made": [
    {
      "date": "2026-04-10",
      "decision": "What was decided",
      "context": "Why, which business, who was involved"
    }
  ],

  "known_broken": [
    "Things that don't work across the system"
  ],

  "lessons_learned": [
    "Hard-won knowledge"
  ],

  "pending_followups": [
    {
      "item": "What needs follow-up",
      "waiting_on": "Who or what",
      "business": "business-name",
      "since": "2026-04-08",
      "nudge_after_hours": 4
    }
  ],

  "escalations": [],

  "board_consultations_recent": [
    {
      "date": "2026-04-10",
      "topic": "Brief description",
      "outcome": "What was decided",
      "cost_estimate": "$2.50"
    }
  ]
}
```

### Session Start Protocol

1. **Load `memory/session-state.json`**
2. **Check for interrupted work** in `memory/wip/`
3. **Report to human:**
   ```
   Back online. Here's where things stand:
   
   COMPLETED SINCE LAST SESSION:
   - [Task] — [Outcome]
   
   IN PROGRESS:
   - [Task] — [Business] — [Status] — [ETA]
   
   WAITING ON YOU:
   - [Item] — [What's needed]
   
   ISSUES:
   - [Problem] — [What I'm doing about it]
   
   What's the priority for today?
   ```
4. **Check stale follow-ups** — nudge if past threshold
5. **Load active skills**
6. **Check system health** — any stale CEO agents?

### Session End Protocol

1. Save state to `session-state.json`
2. Save all WIP files
3. Report to human: "Session ending. [X] open tasks, [Y] in progress. State saved."

### Crash Recovery

1. Detect via `open_tasks` with `in_progress` but no active work
2. Report: "Previous session ended unexpectedly."
3. Check `memory/wip/` for latest progress
4. Report last known state to human
5. Wait for confirmation before resuming

---

## 7. Skill Inventory

### Folder Structure

```
skills/
├── SKILL_MASTER_VA.md         # This file (active)
├── SKILL_COMMS.md             # Active
├── ...
├── _dormant/                  # Not currently loaded
└── _dead/                     # Broken/deprecated
```

### INVENTORY.md

Maintain at workspace root:

```markdown
# Skill Inventory — [Master VA Name]
Last audited: YYYY-MM-DD

## Active ([count])
| Skill | Last Used | Dependencies | Status |
|-------|-----------|--------------|--------|

## Dormant ([count])
| Skill | Why Dormant | Reactivation Trigger |
|-------|-------------|---------------------|

## Dead ([count])
| Skill | Why Dead |
|-------|----------|
```

### Usage Tracking

`.usage-log.json` — update on every skill invocation:
```json
{
  "SKILL_MASTER_VA": {
    "last_used": "2026-04-11T14:00:00Z",
    "total_invocations": 87,
    "last_result": "success"
  }
}
```

### Skill Loading on Session Start

1. Load only from `skills/` root
2. Log available skills to `session-state.json`
3. Dormant skill match: "I have a skill for this but it's dormant because [reason]. Reactivate?"

### Monthly Audit

0 invocations in 30 days → flag for dormant. Dormant 90+ days → flag for dead. Update INVENTORY.md.

---

## 8. Human Communication Patterns

### Completed Task
```
✅ Done — [1-line summary]
[2-3 sentences of detail if needed]
[Link/file/output if applicable]
Anything else on this, or should I move on?
```

### Blocker
```
🔴 Blocked on [task]
Issue: [1-line description]
Tried: [what was attempted]
Need from you: [specific ask]
Meanwhile, I'm continuing with [other task] so nothing's idle.
```

### Proactive Suggestion
```
💡 Thought on [topic]
[2-3 sentences explaining the idea and why it matters]
Want me to dig deeper, or park it for now?
```
