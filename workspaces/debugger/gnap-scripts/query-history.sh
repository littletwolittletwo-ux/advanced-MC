#!/usr/bin/env bash
# Usage: query-history.sh <tag> [<tag>...]
set -euo pipefail

source "$HOME/.openclaw/.env"
: "${DEBUGGER_SUPABASE_URL:?}"
: "${DEBUGGER_SUPABASE_SERVICE_KEY:?}"

[ $# -eq 0 ] && { echo "Usage: query-history.sh <tag> [<tag>...]" >&2; exit 1; }

TAGS_ARG=$(IFS=,; echo "$*")
FILTER="tags=ov.{${TAGS_ARG}}"

curl -sS "${DEBUGGER_SUPABASE_URL}/rest/v1/debugger_runs?${FILTER}&phase=in.(merged,pr-open,escalated,failed)&order=completed_at.desc&limit=10&select=run_id,bug_brief,phase,tags,failure_modes,strategies_tried,root_cause,completed_at,notes" \
  -H "apikey: $DEBUGGER_SUPABASE_SERVICE_KEY" \
  -H "Authorization: Bearer $DEBUGGER_SUPABASE_SERVICE_KEY" | \
  jq -r '.[] | "---\nRUN: \(.run_id)\nCOMPLETED: \(.completed_at)\nPHASE: \(.phase)\nTAGS: \(.tags | join(", "))\nFAILURE_MODES: \(.failure_modes | join(", "))\nBUG: \(.bug_brief | .[0:200])\nROOT_CAUSE: \(.root_cause // "unknown")\nSTRATEGIES_TRIED: \(.strategies_tried | tojson)\nNOTES: \(.notes // "")"' 2>/dev/null || \
  echo "No matching history found or Supabase unreachable."
