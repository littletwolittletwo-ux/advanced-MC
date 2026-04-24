#!/usr/bin/env bash
# Shared env loader for gnap heartbeat scripts
set -euo pipefail

# Load OpenClaw secrets
[ -f "$HOME/.openclaw/.env" ] || { echo "missing ~/.openclaw/.env"; exit 1; }
set -a
source "$HOME/.openclaw/.env"
set +a

# Required vars
: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY not set}"
: "${GITHUB_PAT:?GITHUB_PAT not set}"
: "${DEBUGGER_SUPABASE_URL:?DEBUGGER_SUPABASE_URL not set}"
: "${DEBUGGER_SUPABASE_SERVICE_KEY:?DEBUGGER_SUPABASE_SERVICE_KEY not set}"

REPO_DIR="$HOME/projects/debugger-sandbox"
[ -d "$REPO_DIR/.git" ] || { echo "debugger-sandbox repo missing"; exit 1; }

# Always pull before heartbeat
cd "$REPO_DIR"
git pull --rebase origin main >/dev/null 2>&1 || echo "[gnap] warning: pull failed, continuing"
