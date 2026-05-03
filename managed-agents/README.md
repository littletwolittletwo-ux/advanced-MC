# Claude Managed Agents — Three-Agent Setup

Three Claude Managed Agents: **CodeRunner** (code), **DevDebugger** (debug), **WebOps** (browser automation).

## Setup

```bash
# 1. Install deps
source .venv/bin/activate
pip install -r requirements.txt

# 2. Set your API key in .env
#    ANTHROPIC_API_KEY=sk-ant-...

# 3. Create environments
python envs/general.py
python envs/browser.py

# 4. Create agents
python agents/coder.py
python agents/debugger.py
python agents/browser.py
```

## Usage

```bash
source .venv/bin/activate

# CodeRunner — write and run code
python run.py --agent coder "write a quicksort and benchmark it on 100k ints"

# DevDebugger — diagnose and fix bugs
python run.py --agent debugger "fix segfault.py"

# WebOps — browser automation
python run.py --agent browser "open https://example.com and take a screenshot"

# Resume a session
python run.py --continue <session_id> "follow-up message"
```

## Architecture

- **CodeRunner**: Fast code iteration. Writes, runs, fixes. Uses `general-env`.
- **DevDebugger**: Systematic debugging with `trace_python` instrumentation. Uses `general-env`.
- **WebOps**: Drives web UIs via `agent-browser` CLI (default) or Patchright (stealth fallback). Uses `browser-env`.

### trace_python (DevDebugger)

The `trace_python` custom tool is defined at the agent level so the model has a clean schema. At runtime, the agent writes a helper script (`~/.tools/trace_python.py`) into the sandbox on first use and invokes it via bash. No client-side dispatch needed.

### WebOps bootstrap

The `browser-env` environment pre-installs `agent-browser` (npm) and `patchright` (pip) via the `packages` field. At session start, `run.py` sends a bootstrap message that runs `browser_env_setup.sh` to download Chrome/Chromium binaries (idempotent).

## Cleanup

```bash
source .venv/bin/activate
python -c "
import json
from anthropic import Anthropic
from dotenv import load_dotenv
load_dotenv('.env')
c = Anthropic()
s = json.load(open('state.json'))
for aid in s.get('agents', {}).values():
    c.beta.agents.delete(aid); print(f'Deleted agent {aid}')
for eid in s.get('environments', {}).values():
    c.beta.environments.delete(eid); print(f'Deleted env {eid}')
"
```

## Costs

- Token rates per model (claude-opus-4-7)
- $0.08/session-hour active runtime
- $10/1,000 web_search calls
- Idle sessions are free

## Warnings

1. `unrestricted` networking is open on both envs — narrow to hostname allowlist before pointing WebOps at anything sensitive.
2. Credential-handling rules in WebOps' system prompt are model-enforced, not sandbox-enforced. Review session logs before trusting no key leaked.
