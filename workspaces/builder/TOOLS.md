# TOOLS.md — Builder Local Notes

## Composio AO
- CLI: `ao` (installed in Prompt 3)
- Working dir: `~/projects/builder-sandbox/`
- Must contain `agent-orchestrator.yaml` (set up in Prompt 3)
- Dashboard: http://localhost:3000/

## GitHub
- Auth via `gh` CLI (token in ~/.openclaw/.env)
- Repo: littletwolittletwo-ux/builder-sandbox

## Supabase
- Project URL: set as BUILDER_SUPABASE_URL in ~/.openclaw/.env
- Service key: set as BUILDER_SUPABASE_SERVICE_KEY in ~/.openclaw/.env
- Table: builder_tasks

## Phase files (referenced from SOUL.md section 4)
- PLAN.md — Phase 1 instructions
- EXECUTE.md — Phase 2 instructions
- REVIEW.md — Phase 3 instructions (adversarial)

## Supabase logging helper

~/.openclaw/workspace-builder/scripts/log-to-supabase.sh

Usage:
  log-to-supabase.sh upsert '{"task_id":"<uuid>", "phase":"planning", "brief":"..."}'

Fields: task_id, received_from, brief, phase, plan_output, review_output, pr_urls, ao_session_ids, notes

Helper loads auth from ~/.openclaw/.env.

## History query

Location: `~/.openclaw/workspace-builder/scripts/query-history.sh`

Usage: `./query-history.sh auth migration`

Returns the last 10 completed tasks whose tags overlap with the given terms, with brief, strategies tried, failure modes, and outcome. Use this in PLAN phase to factor past experience into the decomposition.

## Expanded log payload

When calling `log-to-supabase.sh upsert`, include:
- `tags`: array of topical keywords (`["auth", "migration"]`)
- `failure_modes`: array of failure tags when something breaks (`["ci-failed", "review-rejected"]`)
- `strategies_tried`: array of `{tried: "...", outcome: "...", at: "..."}` — one entry per distinct approach

## Reviewer subprocess

Location: `~/.openclaw/workspace-builder/reviewer/review-subprocess.sh`
Rubric: `~/.openclaw/workspace-builder/reviewer/REVIEW_RUBRIC.md`

Usage:
  ./review-subprocess.sh <task_id> <plan-output-path> <pr-url>

Returns structured JSON (verdict: approve|reject, criteria graded, scope violations, retry_feedback). Takes ~30s per call. Don't skip it. Don't override it.
