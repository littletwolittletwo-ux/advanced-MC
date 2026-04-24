#!/usr/bin/env bash
# Usage: log-to-supabase.sh <table> <operation> <json-payload>
# Example: log-to-supabase.sh debugger_runs upsert '{"run_id":"...", "phase":"triaging"}'
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

TABLE="$1"
OPERATION="$2"
PAYLOAD="$3"

ENDPOINT="${DEBUGGER_SUPABASE_URL}/rest/v1/${TABLE}"

case "$OPERATION" in
  insert)
    curl -sS -X POST "$ENDPOINT" \
      -H "apikey: $DEBUGGER_SUPABASE_SERVICE_KEY" \
      -H "Authorization: Bearer $DEBUGGER_SUPABASE_SERVICE_KEY" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "$PAYLOAD"
    ;;
  upsert)
    curl -sS -X POST "$ENDPOINT" \
      -H "apikey: $DEBUGGER_SUPABASE_SERVICE_KEY" \
      -H "Authorization: Bearer $DEBUGGER_SUPABASE_SERVICE_KEY" \
      -H "Content-Type: application/json" \
      -H "Prefer: resolution=merge-duplicates,return=representation" \
      -d "$PAYLOAD"
    ;;
  update)
    # expects PAYLOAD to have a "run_id" field for filtering
    RUN_ID=$(echo "$PAYLOAD" | jq -r '.run_id')
    curl -sS -X PATCH "${ENDPOINT}?run_id=eq.${RUN_ID}" \
      -H "apikey: $DEBUGGER_SUPABASE_SERVICE_KEY" \
      -H "Authorization: Bearer $DEBUGGER_SUPABASE_SERVICE_KEY" \
      -H "Content-Type: application/json" \
      -H "Prefer: return=representation" \
      -d "$PAYLOAD"
    ;;
  *)
    echo "Unknown operation: $OPERATION" >&2
    exit 1
    ;;
esac
