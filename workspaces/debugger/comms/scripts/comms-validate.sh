#!/bin/bash
# Usage: comms-validate.sh
# Validates that the comms skill is correctly configured and can reach the API

PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" -eq 0 ]; then
    echo "  OK  $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "Agent Comms Skill Validation"
echo "============================"
echo ""

# Locate config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -n "$COMMS_CONFIG" ] && [ -f "$COMMS_CONFIG" ]; then
  CONFIG="$COMMS_CONFIG"
elif [ -f "$SCRIPT_DIR/comms-config.json" ]; then
  CONFIG="$SCRIPT_DIR/comms-config.json"
elif [ -f "$SCRIPT_DIR/../comms-config.json" ]; then
  CONFIG="$SCRIPT_DIR/../comms-config.json"
else
  echo "  FAIL  comms-config.json not found"
  echo ""
  echo "Results: 0 passed, 1 failed"
  exit 1
fi

# 1. Check config exists and is valid JSON
if command -v jq &>/dev/null; then
  jq . "$CONFIG" > /dev/null 2>&1
  check "Config is valid JSON ($CONFIG)" $?
elif command -v python3 &>/dev/null; then
  python3 -c "import json; json.load(open('$CONFIG'))" 2>/dev/null
  check "Config is valid JSON ($CONFIG)" $?
else
  # Just check the file exists
  test -f "$CONFIG"
  check "Config file exists ($CONFIG)" $?
fi

# 2. Check agent_id is set
AGENT_ID=$(cat "$CONFIG" | grep -o '"agent_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
if [ -n "$AGENT_ID" ] && [ "$AGENT_ID" != "REPLACE_WITH_YOUR_AGENT_ID" ]; then
  check "agent_id is set ($AGENT_ID)" 0
else
  check "agent_id is set (still placeholder or empty)" 1
fi

# 3. Check api_url is set
API_URL=$(cat "$CONFIG" | grep -o '"api_url"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
API_KEY=$(cat "$CONFIG" | grep -o '"api_key"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
if [ -n "$API_URL" ]; then
  check "api_url is set ($API_URL)" 0
else
  check "api_url is set" 1
fi

# 4. Check API reachable
if [ -n "$API_URL" ]; then
  HEALTH=$(curl -s --connect-timeout 5 --max-time 10 ${API_KEY:+-H "X-API-Key: $API_KEY"} "${API_URL}/health" 2>/dev/null)
  if echo "$HEALTH" | grep -q '"status":"ok"'; then
    check "API is reachable (${API_URL}/health)" 0
  else
    check "API is reachable (${API_URL}/health)" 1
  fi
else
  check "API is reachable (no api_url)" 1
fi

# 5. Check agent exists
if [ -n "$API_URL" ] && [ -n "$AGENT_ID" ]; then
  AGENT_RES=$(curl -s --connect-timeout 5 --max-time 10 ${API_KEY:+-H "X-API-Key: $API_KEY"} "${API_URL}/agents/${AGENT_ID}" 2>/dev/null)
  if echo "$AGENT_RES" | grep -q "\"id\":\"${AGENT_ID}\""; then
    check "Agent exists in API ($AGENT_ID)" 0
  else
    check "Agent exists in API ($AGENT_ID)" 1
  fi
else
  check "Agent exists in API (skipped)" 1
fi

# 6. Check channels
if [ -n "$API_URL" ] && [ -n "$AGENT_ID" ]; then
  CHANNELS_RES=$(curl -s --connect-timeout 5 --max-time 10 ${API_KEY:+-H "X-API-Key: $API_KEY"} "${API_URL}/channels?agent=${AGENT_ID}" 2>/dev/null)
  if echo "$CHANNELS_RES" | grep -q '"channels"'; then
    COUNT=$(echo "$CHANNELS_RES" | grep -o '"count":[0-9]*' | head -1 | sed 's/.*://')
    check "Agent has channels (${COUNT:-0} found)" 0
  else
    check "Agent has channels" 1
  fi
else
  check "Agent has channels (skipped)" 1
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
