#!/usr/bin/env bash
# Usage: obsidian-append-daily.sh "<event text>"
# Appends a timestamped line to today's daily note. Creates the daily note if missing.
set -euo pipefail

source "$HOME/.openclaw/.env"
: "${OBSIDIAN_VAULT:?OBSIDIAN_VAULT not set}"

TEXT="$1"
TODAY=$(date +%Y-%m-%d)
NOW=$(date +%H:%M)
SUNNY_ROOT="${OBSIDIAN_VAULT}/Sunny"
DAILY_FILE="${SUNNY_ROOT}/daily/${TODAY}.md"

# Create if missing
if [ ! -f "$DAILY_FILE" ]; then
  mkdir -p "$(dirname "$DAILY_FILE")"
  cat > "$DAILY_FILE" << DAILY_EOF
# ${TODAY}

## Events
DAILY_EOF
fi

# Append under Events — if the section doesn't exist, add it
if ! grep -q '^## Events' "$DAILY_FILE"; then
  echo "" >> "$DAILY_FILE"
  echo "## Events" >> "$DAILY_FILE"
fi

echo "- ${TODAY} ${NOW} — ${TEXT}" >> "$DAILY_FILE"
echo "Appended to ${DAILY_FILE}"
