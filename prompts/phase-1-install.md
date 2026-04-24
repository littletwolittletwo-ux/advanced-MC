# Phase 1 — Install agent-browser globally

You are setting up the foundation for a three-agent QA system. This phase installs `agent-browser` globally, generates a shared encryption key for the auth vault, and verifies prerequisites. No agent-specific configuration yet — that happens in phases 2-4.

## Context you need

- This is macOS
- `~/.openclaw/workspace` is Sunny's workspace (master VA / reviewer)
- `~/.openclaw/workspace-builder` and `~/.openclaw/workspace-debugger` are sub-agent workspaces
- All three agents communicate via a pre-existing bus. Do not modify the bus.
- After this phase, you will be given separate phases to configure each agent.

## Tasks

### 1. Verify prerequisites

Check that all of the following exist. If any are missing, stop and report to the user — do not attempt to create them.

```bash
for path in \
  "$HOME/.openclaw/workspace" \
  "$HOME/.openclaw/workspace/SOUL.md" \
  "$HOME/.openclaw/workspace/comms/scripts/comms-send.sh" \
  "$HOME/.openclaw/workspace-builder" \
  "$HOME/.openclaw/workspace-builder/SOUL.md" \
  "$HOME/.openclaw/workspace-builder/comms-config.json" \
  "$HOME/.openclaw/workspace-debugger" \
  "$HOME/.openclaw/workspace-debugger/SOUL.md" \
  "$HOME/.openclaw/workspace-debugger/comms-config.json"; do
  if [ ! -e "$path" ]; then
    echo "MISSING: $path"
    exit 1
  fi
done
echo "All prerequisites present."

command -v node >/dev/null || { echo "node not installed"; exit 1; }
command -v npm  >/dev/null || { echo "npm not installed";  exit 1; }
node --version
```

### 2. Install agent-browser globally

```bash
if ! command -v agent-browser >/dev/null 2>&1; then
  npm install -g agent-browser
else
  echo "agent-browser already installed: $(agent-browser --version 2>/dev/null || echo unknown)"
fi

# Download Chrome for Testing (idempotent)
agent-browser install
```

If `npm install -g` fails with permission errors, stop and tell the user. Do not use `sudo` without asking.

### 3. Generate encryption key for the auth vault

```bash
KEY_FILE="$HOME/.agent-browser/.encryption-key"
if [ ! -f "$KEY_FILE" ]; then
  mkdir -p "$HOME/.agent-browser"
  openssl rand -hex 32 > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  echo "Encryption key generated at $KEY_FILE"
else
  echo "Encryption key already exists at $KEY_FILE — leaving untouched."
fi
```

This key encrypts all saved credentials across all three agent sessions. Do not regenerate it if it already exists — doing so would lock out every existing vault entry.

### 4. Create per-agent profile directories

```bash
for agent in sunny builder debugger; do
  mkdir -p "$HOME/.agent-browser/profiles/${agent}"
done
echo "Profile directories ready."
```

Profiles persist cookies, localStorage, and session state across browser restarts. Each agent gets an isolated profile — no cross-contamination.

### 5. Smoke-test the install

Run one trivial command to confirm the daemon starts cleanly:

```bash
agent-browser --session _install_test open https://example.com
agent-browser --session _install_test get title
agent-browser --session _install_test close
```

You should see `Example Domain` as the title. If you get errors about Chrome not being found, the user likely needs `agent-browser install --with-deps` (Linux only, skip on macOS).

### 6. Verification summary

Print the following summary to the user before finishing:

```
PHASE 1 COMPLETE

Installed:
  agent-browser version: <version>
  Chrome for Testing: <path>
  Encryption key:     ~/.agent-browser/.encryption-key (chmod 600)

Profile directories created:
  ~/.agent-browser/profiles/sunny
  ~/.agent-browser/profiles/builder
  ~/.agent-browser/profiles/debugger

Smoke test: PASS / FAIL

Prerequisites verified:
  Sunny workspace:    OK
  Builder workspace:  OK
  Debugger workspace: OK
  comms-send.sh:      OK
  node/npm:           OK

READY FOR PHASE 2.
```

If any check fails, report the specific failure and stop. Do not proceed to the next phase until the user confirms.

## Do NOT do in this phase

- Do NOT create any wrapper scripts yet (that's per-agent, phases 2-4)
- Do NOT create any reference docs yet (that's per-agent, phases 2-4)
- Do NOT modify any SOUL.md files yet
- Do NOT seed any auth vault entries (that's phase 5)
- Do NOT restart any agents or pollers

Phase 1 is install-only. Keep it boring.
