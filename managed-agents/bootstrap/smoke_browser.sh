#!/usr/bin/env bash
set -euo pipefail

echo "=== agent-browser smoke ==="
agent-browser open https://example.com
agent-browser snapshot -i -c | head -50
agent-browser screenshot /tmp/smoke.png
test -s /tmp/smoke.png && echo "agent-browser OK"
agent-browser close

echo "=== patchright smoke ==="
python3 - <<'PY'
from patchright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(headless=True)
    pg = b.new_page()
    pg.goto("https://example.com")
    print("patchright title:", pg.title())
    b.close()
PY
echo "=== smoke done ==="
