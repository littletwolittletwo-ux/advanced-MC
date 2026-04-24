#!/bin/bash
# install-cron.sh — install the polling and sync crons for this agent
# Usage: bash install-cron.sh <workspace-path> [--with-sync]

set -e

WORKSPACE="${1:?Usage: install-cron.sh <workspace-path> [--with-sync]}"
WITH_SYNC=false
if [ "$2" = "--with-sync" ]; then WITH_SYNC=true; fi

WORKSPACE="$(cd "$WORKSPACE" && pwd)"  # absolutize

if [ ! -f "$WORKSPACE/comms-config.json" ]; then
  echo "ERROR: $WORKSPACE/comms-config.json not found"
  exit 1
fi

AGENT_ID=$(python3 -c "import json; print(json.load(open('$WORKSPACE/comms-config.json'))['agent_id'])")
POLLER_SCRIPT="$WORKSPACE/cron/agent-poller.sh"
SYNC_SCRIPT="$WORKSPACE/memory-sync.mjs"

echo "Installing cron for agent: $AGENT_ID"
echo "Workspace: $WORKSPACE"
echo "With sync: $WITH_SYNC"

install_launchd() {
  LAUNCHD_DIR="$HOME/Library/LaunchAgents"
  mkdir -p "$LAUNCHD_DIR"

  # Poller — every 30s
  POLLER_PLIST="$LAUNCHD_DIR/com.agentcomms.poller.$AGENT_ID.plist"
  cat > "$POLLER_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.agentcomms.poller.$AGENT_ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>$POLLER_SCRIPT</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>AGENT_WORKSPACE</key>
    <string>$WORKSPACE</string>
    <key>AGENT_LOG_DIR</key>
    <string>$WORKSPACE/logs</string>
    <key>AGENT_IDLE_TIMEOUT</key>
    <string>300</string>
    <key>PATH</key>
    <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$HOME/.npm-global/bin:$HOME/Library/pnpm</string>
    <key>HOME</key>
    <string>$HOME</string>
  </dict>
  <key>StartInterval</key>
  <integer>30</integer>
  <key>StandardOutPath</key>
  <string>$WORKSPACE/logs/poller.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>$WORKSPACE/logs/poller.stderr.log</string>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF

  launchctl unload "$POLLER_PLIST" 2>/dev/null || true
  launchctl load "$POLLER_PLIST"
  echo "Poller installed (30s interval): $POLLER_PLIST"

  if [ "$WITH_SYNC" = "true" ]; then
    SYNC_PLIST="$LAUNCHD_DIR/com.agentcomms.sync.$AGENT_ID.plist"
    cat > "$SYNC_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.agentcomms.sync.$AGENT_ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/node</string>
    <string>$WORKSPACE/memory-sync.mjs</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>MEMORY_SYNC_CONFIG</key>
    <string>$WORKSPACE/memory-sync-config.json</string>
    <key>PATH</key>
    <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
  </dict>
  <key>StartInterval</key>
  <integer>120</integer>
  <key>StandardOutPath</key>
  <string>$WORKSPACE/logs/sync.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>$WORKSPACE/logs/sync.stderr.log</string>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF
    launchctl unload "$SYNC_PLIST" 2>/dev/null || true
    launchctl load "$SYNC_PLIST"
    echo "Sync installed (2min interval): $SYNC_PLIST"
  fi
}

install_cron_linux() {
  TMP_CRON=$(mktemp)
  crontab -l 2>/dev/null > "$TMP_CRON" || true

  # Remove existing entries for this agent
  grep -v "# agent-comms: $AGENT_ID" "$TMP_CRON" > "${TMP_CRON}.clean" || true
  mv "${TMP_CRON}.clean" "$TMP_CRON"

  # Add poller (every 30s — requires trick since cron min is 1 min)
  cat >> "$TMP_CRON" <<EOF
# agent-comms: $AGENT_ID poller
* * * * * AGENT_WORKSPACE=$WORKSPACE $POLLER_SCRIPT
* * * * * sleep 30 && AGENT_WORKSPACE=$WORKSPACE $POLLER_SCRIPT
EOF

  # Add sync if requested
  if [ "$WITH_SYNC" = "true" ]; then
    cat >> "$TMP_CRON" <<EOF
# agent-comms: $AGENT_ID sync
*/2 * * * * MEMORY_SYNC_CONFIG=$WORKSPACE/memory-sync-config.json node $SYNC_SCRIPT >> $WORKSPACE/logs/sync.log 2>&1
EOF
  fi

  crontab "$TMP_CRON"
  rm "$TMP_CRON"

  echo "Cron installed for $AGENT_ID (30s poll + 2min sync)"
  echo "View: crontab -l"
}

# Detect OS and install
if [[ "$OSTYPE" == "darwin"* ]]; then
  install_launchd
elif [[ "$OSTYPE" == "linux"* ]]; then
  install_cron_linux
else
  echo "ERROR: Unsupported OS: $OSTYPE"
  exit 1
fi

echo ""
echo "Done. The agent will now auto-wake on new messages."
echo "Monitor:"
echo "  tail -f $WORKSPACE/logs/poller.log"
echo "  tail -f $WORKSPACE/logs/wake.log"
if [ "$WITH_SYNC" = "true" ]; then
  echo "  tail -f $WORKSPACE/logs/sync.log"
fi
