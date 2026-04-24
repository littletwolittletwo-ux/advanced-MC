#!/usr/bin/env bash
# Usage: log-to-supabase.sh <operation> <json-payload>
set -euo pipefail

[ -f "$HOME/.openclaw/.env" ] && source "$HOME/.openclaw/.env"

: "${BUILDER_SUPABASE_URL:?}"
: "${BUILDER_SUPABASE_SERVICE_KEY:?}"

OPERATION="$1"
PAYLOAD="$2"
ENDPOINT="${BUILDER_SUPABASE_URL}/rest/v1/builder_tasks"

case "$OPERATION" in
  insert)
    curl -sS -X POST "$ENDPOINT" \
      -H "apikey: $BUILDER_SUPABASE_SERVICE_KEY" \
      -H "Authorization: Bearer $BUILDER_SUPABASE_SERVICE_KEY" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "$PAYLOAD"
    ;;
  upsert)
    curl -sS -X POST "$ENDPOINT" \
      -H "apikey: $BUILDER_SUPABASE_SERVICE_KEY" \
      -H "Authorization: Bearer $BUILDER_SUPABASE_SERVICE_KEY" \
      -H "Content-Type: application/json" \
      -H "Prefer: resolution=merge-duplicates,return=representation" \
      -d "$PAYLOAD"
    ;;
  update)
    TASK_ID=$(echo "$PAYLOAD" | jq -r '.task_id')
    curl -sS -X PATCH "${ENDPOINT}?task_id=eq.${TASK_ID}" \
      -H "apikey: $BUILDER_SUPABASE_SERVICE_KEY" \
      -H "Authorization: Bearer $BUILDER_SUPABASE_SERVICE_KEY" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "$PAYLOAD"
    ;;
  *)
    echo "Unknown operation: $OPERATION" >&2
    exit 1
    ;;
esac
