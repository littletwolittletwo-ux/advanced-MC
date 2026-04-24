#!/usr/bin/env bash
# Usage: obsidian-archive-message.sh <source: telegram|cli|other> <from> "<text>"
# Appends to today's message archive file.
set -euo pipefail

source "$HOME/.openclaw/.env"
: "${OBSIDIAN_VAULT:?}"

SOURCE="$1"
FROM="$2"
TEXT="$3"
TODAY=$(date +%Y-%m-%d)
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SUNNY_ROOT="${OBSIDIAN_VAULT}/Sunny"
ARCHIVE="${SUNNY_ROOT}/messages/${TODAY}-${SOURCE}.md"

mkdir -p "$(dirname "$ARCHIVE")"
[ -f "$ARCHIVE" ] || echo "# ${TODAY} — ${SOURCE}" > "$ARCHIVE"

cat >> "$ARCHIVE" << MSG_EOF

### ${NOW} — ${FROM}
${TEXT}
MSG_EOF
