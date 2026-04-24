#!/usr/bin/env bash
# Usage: obsidian-append-identity.sh <file-slug> "<entry text>"
# Example: obsidian-append-identity.sh about-david "David mentioned preferring tmux over screen."
set -euo pipefail

source "$HOME/.openclaw/.env"
: "${OBSIDIAN_VAULT:?}"

SLUG="$1"
TEXT="$2"
SUNNY_ROOT="${OBSIDIAN_VAULT}/Sunny"
TARGET="${SUNNY_ROOT}/identity/${SLUG}.md"

[ -f "$TARGET" ] || { echo "identity file not found: ${TARGET}"; exit 1; }

NOW=$(date +%Y-%m-%d)
echo "" >> "$TARGET"
echo "- ${NOW}: ${TEXT}" >> "$TARGET"
echo "Appended to ${TARGET}"
