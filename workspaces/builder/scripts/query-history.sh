#!/usr/bin/env bash
# Usage: query-history.sh <tag> [<tag> <tag> ...]
# Returns the last 10 completed tasks matching any of the given tags,
# with their briefs, outcomes, strategies tried, and failure modes.
set -euo pipefail

source "$HOME/.openclaw/.env"
: "${BUILDER_SUPABASE_URL:?}"
: "${BUILDER_SUPABASE_SERVICE_KEY:?}"

[ $# -eq 0 ] && { echo "Usage: query-history.sh <tag> [<tag>...]" >&2; exit 1; }

# Build PostgREST 'contains any of' filter:  tags=ov.{tag1,tag2}
TAGS_ARG=$(IFS=,; echo "$*")
FILTER="tags=ov.{${TAGS_ARG}}"

curl -sS "${BUILDER_SUPABASE_URL}/rest/v1/builder_tasks?${FILTER}&phase=in.(done,escalated,failed)&order=completed_at.desc&limit=10&select=task_id,brief,phase,tags,failure_modes,strategies_tried,completed_at,notes" \
  -H "apikey: $BUILDER_SUPABASE_SERVICE_KEY" \
  -H "Authorization: Bearer $BUILDER_SUPABASE_SERVICE_KEY" | \
  jq -r '.[] | "---\nTASK: \(.task_id)\nCOMPLETED: \(.completed_at)\nPHASE: \(.phase)\nTAGS: \(.tags | join(", "))\nFAILURE_MODES: \(.failure_modes | join(", "))\nBRIEF: \(.brief | .[0:200])\nSTRATEGIES_TRIED: \(.strategies_tried | tojson)\nNOTES: \(.notes // "")"' 2>/dev/null || \
  echo "No matching history found or Supabase unreachable."
