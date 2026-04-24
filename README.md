# advanced-MC

Multi-agent workspace for OpenClaw — three AI agents (Sunny, Builder, Debugger) communicating over a shared message bus with launchd-managed polling and a browser-based QA review loop.

## Architecture

```
David (human)
  └─ Telegram ─► OpenClaw Gateway (localhost:18789)
                    └─► Sunny (Master VA)
                          ├─► Builder (sub-agent, via bus)
                          └─► Debugger (sub-agent, via bus)
```

- **Sunny** — Master VA and QA auditor. Routes tasks to sub-agents, reviews their output against strict criteria, forwards approved results to David.
- **Builder** — Implementation agent. Receives build/code tasks, executes, submits completion reports for Sunny's review.
- **Debugger** — Investigation agent. Receives bug/diagnostic tasks, investigates, submits investigation reports for Sunny's review.

## Message Bus

All inter-agent communication flows through a Railway-hosted REST API:
- `POST /messages` — send
- `GET /messages/poll?agent=<id>` — poll for new messages
- `GET /health` — bus health check

Each agent has a `comms-config.json` (not committed) that holds the bus URL and API key. See `comms-config.example.json` in each workspace for the template.

## Directory Structure

```
workspaces/
  sunny/          # Master VA workspace (~/.openclaw/workspace)
  builder/        # Builder workspace (~/.openclaw/workspace-builder)
  debugger/       # Debugger workspace (~/.openclaw/workspace-debugger)
launchd-plists/   # macOS LaunchAgent plists (${HOME} templated)
prompts/          # Master sequence prompts (setup/install phases)
docs/             # Architecture and reference documentation
```

## Setup

1. Install OpenClaw (`npm i -g openclaw@latest`)
2. Copy each `comms-config.example.json` to `comms-config.json` and fill in the API key
3. Copy workspace dirs to `~/.openclaw/workspace`, `~/.openclaw/workspace-builder`, `~/.openclaw/workspace-debugger`
4. Copy launchd plists to `~/Library/LaunchAgents/`, replacing `${HOME}` with your home directory
5. Load pollers: `launchctl load ~/Library/LaunchAgents/com.agentcomms.poller.*.plist`
6. Start OpenClaw gateway

## Environment

Create a `.env` file in each workspace with:

```
BUS_API_KEY=<your-bus-api-key>
ANTHROPIC_API_KEY=<your-anthropic-key>
```

See `.env.example` for the template.

## QA Review Loop

Sunny uses `agent-browser` to independently verify sub-agent work:
- Builder submits completion reports → Sunny audits against `AUDIT_CRITERIA.md`
- Debugger submits investigation reports → Sunny verifies evidence
- Max 3 rejection cycles before escalation to David

See `docs/ARCHITECTURE.md` for the full flow.
