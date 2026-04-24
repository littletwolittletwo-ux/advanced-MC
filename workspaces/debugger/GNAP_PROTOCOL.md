# GNAP_PROTOCOL.md — Reference for the Debugger agent

## The protocol in one page

gnap (Git-Native Agent Protocol) coordinates multiple agents through a git repo. Four file types in `.gnap/`:

| File | Purpose |
|---|---|
| `version` | Protocol version (we use "4") |
| `agents.json` | Registry of participating agents |
| `tasks/<id>.json` | Work items with state machine |
| `runs/<task-id>-<attempt>.json` | Per-attempt execution records |
| `messages/<id>.json` | Inter-agent communication |

## The loop

Every agent follows:
1. `git pull --rebase`
2. Read `agents.json` — am I active?
3. Read `messages/` — anything for me?
4. Read `tasks/` — anything assigned to me in `ready` or `in_progress`?
5. If work available: claim it (state → `in_progress`), do it, write run, commit, push
6. If work done: state → `review` (for verifier) or `done`
7. Sleep until next heartbeat

## Task state machine

```
backlog → ready → in_progress → review → done
            ↑          ↑           │
            │          └───────────┘  (verifier rejects)
            │
         blocked → ready
            ↓
         cancelled
```

## Our island's agents

- **debugger** (you) — runtime: openclaw. Role: triage + verify + PR creation
- **investigator** — runtime: claude-code (via `investigator.sh`). Role: root-cause analysis, findings
- **fixer** — runtime: claude-code (via `fixer.sh`). Role: minimal fix + regression test on a branch

## Typical task lifecycle for BUG-N

1. Debugger's TRIAGE phase creates `tasks/BUG-N.json` with state `ready`, assigned to `[investigator, fixer]`
2. Investigator heartbeat picks it up, transitions to `in_progress`, writes `runs/BUG-N-1.json` with findings
3. Investigator posts message to fixer
4. Fixer heartbeat picks it up, creates `bugfix/bug-n` branch, commits fix+test, writes `runs/BUG-N-2.json`, transitions task to `review`
5. Debugger's VERIFY phase reads the task + runs + diff, approves or rejects
6. If approved: Debugger creates PR via `gh pr create`, sets task to `done`
7. If rejected: Debugger sets task back to `in_progress`, posts message to fixer with feedback; loop from step 4

## Heartbeat scripts

Located in `~/.openclaw/workspace-debugger/gnap-scripts/`:
- `investigator.sh` — one iteration of investigator loop
- `fixer.sh` — one iteration of fixer loop
- `env.sh` — shared env loader

Cron schedules these every N minutes (see Prompt 2 cron section).

## Your coordination commands (as Debugger)

```bash
cd ~/projects/debugger-sandbox

# Pull latest state
git pull --rebase origin main

# Check open tasks
ls .gnap/tasks/

# Get task status
jq . .gnap/tasks/BUG-N.json

# Read latest run
ls -t .gnap/runs/BUG-N-*.json | head -1 | xargs jq .

# Read messages for you
for msg in .gnap/messages/*.json; do
  jq 'select(.to | index("debugger"))' "$msg"
done
```

## When to use gnap messages vs phase files

- **Messages** (`.gnap/messages/`): for real-time coordination between the three agents (e.g., "blocked, need X"). Short, operational.
- **Phase files** (TRIAGE.md, INVESTIGATE.md, VERIFY.md in your workspace): for YOUR internal phase logic. Not committed to the debugger-sandbox repo.

## Failure modes

- **Heartbeat stuck**: check `launchctl list | grep ai.openclaw.gnap` (macOS) or `crontab -l` for the scheduled jobs
- **Investigator or fixer silent**: check `~/.openclaw/logs/gnap-investigator.log` and `gnap-fixer.log` for Claude Code errors
- **Push conflicts**: scripts auto-retry with `git pull --rebase`. If it keeps failing, investigate the conflict manually.
