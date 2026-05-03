#!/usr/bin/env bash
set -euo pipefail

# Idempotency guard
if [ -f /tmp/.browser_env_ready ]; then
  echo "[bootstrap] ready"
  exit 0
fi

echo "[bootstrap] installing Chrome for Testing via agent-browser..."
agent-browser install

echo "[bootstrap] installing Chromium for Patchright..."
python3 -m patchright install chromium

# Persistent profile dir for stealth sessions
mkdir -p /root/.patchright-profiles

echo "[bootstrap] running doctor..."
agent-browser doctor --quick

touch /tmp/.browser_env_ready
echo "[bootstrap] done"
