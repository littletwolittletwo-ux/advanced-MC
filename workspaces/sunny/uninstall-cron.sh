#!/bin/bash
# uninstall-cron.sh — remove the polling and sync crons for an agent
# Usage: bash uninstall-cron.sh <workspace-path>

WORKSPACE="${1:?Usage: uninstall-cron.sh <workspace-path>}"
AGENT_ID=$(python3 -c "import json; print(json.load(open('$WORKSPACE/comms-config.json'))['agent_id'])" 2>/dev/null)

if [ -z "$AGENT_ID" ]; then
  echo "ERROR: Could not read agent_id from $WORKSPACE/comms-config.json"
  exit 1
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  LAUNCHD_DIR="$HOME/Library/LaunchAgents"
  for PLIST in "com.agentcomms.poller.$AGENT_ID" "com.agentcomms.sync.$AGENT_ID"; do
    FILE="$LAUNCHD_DIR/$PLIST.plist"
    if [ -f "$FILE" ]; then
      launchctl unload "$FILE" 2>/dev/null || true
      rm "$FILE"
      echo "Removed $PLIST"
    fi
  done
elif [[ "$OSTYPE" == "linux"* ]]; then
  TMP_CRON=$(mktemp)
  crontab -l 2>/dev/null | grep -v "# agent-comms: $AGENT_ID" > "$TMP_CRON"
  crontab "$TMP_CRON"
  rm "$TMP_CRON"
  echo "Removed cron entries for $AGENT_ID"
fi

# Remove lock file if present
rm -f "$WORKSPACE/.wake.lock"

echo "Done."
