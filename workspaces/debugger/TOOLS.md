# TOOLS.md — Debugger Local Notes

## gnap
- Repo: ~/projects/debugger-sandbox (cloned locally)
- Task board: .gnap/tasks/
- Runs log: .gnap/runs/
- Messages: .gnap/messages/
- Agent registry: .gnap/agents.json
- Protocol version: .gnap/version (integer "4")

## GitHub
- Auth via gh CLI (token in ~/.openclaw/.env)
- Repo: littletwolittletwo-ux/debugger-sandbox

## Supabase
- Project URL: DEBUGGER_SUPABASE_URL in ~/.openclaw/.env
- Service key: DEBUGGER_SUPABASE_SERVICE_KEY
- Table: debugger_runs

## Phase files
- TRIAGE.md — Phase 1
- INVESTIGATE.md — Phase 2 (observation of gnap shared workspace)
- VERIFY.md — Phase 3 (adversarial)

## gnap agents (registered in .gnap/agents.json, set up in Prompt 2)
- debugger (this agent, orchestrator)
- investigator (heartbeat worker)
- fixer (heartbeat worker)

## Supabase logging helper

~/.openclaw/workspace-debugger/gnap-scripts/log-to-supabase.sh

Usage:
  log-to-supabase.sh debugger_runs upsert '{"run_id":"...", "phase":"triaging", "bug_brief":"..."}'

The helper loads auth from ~/.openclaw/.env.

## History query

Location: `~/.openclaw/workspace-debugger/gnap-scripts/query-history.sh`

Usage: `./query-history.sh race-condition auth`

Returns the last 10 completed runs whose tags overlap with the given terms, with bug brief, root cause, strategies tried, and failure modes. Use this in TRIAGE phase to check for recurring patterns.

## Expanded log payload

When calling `log-to-supabase.sh upsert`, include:
- `tags`: array of topical keywords (`["race-condition", "auth"]`)
- `failure_modes`: (`["cannot-reproduce", "verify-rejected", "gnap-stuck"]`)
- `strategies_tried`: array of `{tried: "...", outcome: "...", at: "..."}`

## Verifier subprocess

Location: `~/.openclaw/workspace-debugger/reviewer/verify-subprocess.sh`
Rubric: `~/.openclaw/workspace-debugger/reviewer/VERIFY_RUBRIC.md`

Usage:
  ./verify-subprocess.sh <run_id> <gnap-task-id> <branch>

Returns structured JSON (verdict, regression_test diagnostics, root_cause_addressed, scope violations, retry_feedback). Takes ~30s per call.
