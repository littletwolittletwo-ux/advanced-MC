# Architecture

## System Overview

Three Claude-powered agents operate under a single OpenClaw gateway, communicating via a shared message bus and polled by macOS LaunchAgents every 30 seconds.

## Components

### OpenClaw Gateway
- Runs on `localhost:18789` (loopback only)
- Manages agent sessions and Telegram integration
- Built from `openclaw@2026.4.12-beta.1`

### Sunny — Master VA (`main` agent)
- Model: `claude-opus-4-6`
- Channel: Telegram (David's primary interface)
- Role: task routing, QA review, final delivery
- Workspace: `~/.openclaw/workspace`
- Tools: `agent-browser` (read-only audit mode), bus comms scripts

### Builder — Sub-Agent
- Model: `claude-sonnet-4-6`
- Channel: bus-only (no direct Telegram)
- Role: code implementation, feature building
- Workspace: `~/.openclaw/workspace-builder`
- Tools: `agent-browser` (dev-scope), bus comms scripts

### Debugger — Sub-Agent
- Model: `claude-sonnet-4-6`
- Channel: bus-only (no direct Telegram)
- Role: bug investigation, diagnostics
- Workspace: `~/.openclaw/workspace-debugger`
- Tools: `agent-browser` (diagnostic-scope), bus comms scripts

### Message Bus
- URL: `https://agent-comms-api-production-fd99.up.railway.app`
- Auth: API key in `comms-config.json`
- Channels: `dm:sunny-builder`, `dm:sunny-debugger`, `dm:sunny-claudia`, `dm:sunny-eva`

### LaunchAgent Pollers
- `com.agentcomms.poller.sunny` — polls every 30s, wakes Sunny
- `com.agentcomms.poller.builder` — polls every 30s, wakes Builder
- `com.agentcomms.poller.debugger` — polls every 30s, wakes Debugger
- `ai.openclaw.gnap.fixer` — GNAP fixer agent
- `ai.openclaw.gnap.investigator` — GNAP investigator agent

## Task Flow

```
1. David sends task via Telegram
2. Gateway delivers to Sunny
3. Sunny triages:
   - Simple → handles directly
   - Build task → delegates to Builder via bus
   - Bug/diagnostic → delegates to Debugger via bus
4. Sub-agent polls, picks up task, executes
5. Sub-agent submits report via bus
6. Sunny reviews against AUDIT_CRITERIA.md:
   - APPROVED → forwards result to David via Telegram
   - REJECTED → sends rejection with feedback to sub-agent (max 3 cycles)
   - ESCALATE → notifies David of unresolvable issue
```

## QA Review Loop

Sunny acts as a "harsh but reasonable" reviewer using:
- `reference/AUDIT_CRITERIA.md` — checklist for Builder and Debugger output
- `reference/REVIEW_PROTOCOL.md` — 7-step review workflow
- `reference/HANDOFF_PROTOCOL.md` — shared protocol for task delegation format
- `bin/browser` — read-only browser access for independent verification

### Browser Policies
Each agent has a scoped browser policy:
- **Sunny**: read-only (no form interaction, no destructive actions)
- **Builder**: dev-scope (localhost/vercel/ngrok, allows Submit/Save for testing)
- **Debugger**: diagnostic-scope (wider domain allowlist including observability vendors)

## Key Files Per Workspace

| File | Purpose |
|------|---------|
| `SOUL.md` | Agent identity and behavioral rules |
| `AGENTS.md` | Agent capabilities and boundaries |
| `IDENTITY.md` | Agent persona and role definition |
| `TOOLS.md` | Available tools and usage |
| `USER.md` | User (David) preferences |
| `comms/scripts/` | Bus communication shell scripts |
| `cron/agent-poller.sh` | LaunchAgent poll script |
| `cron/agent-wake.sh` | Message wake handler |
| `bin/browser` | Scoped browser wrapper |
| `reference/` | QA protocols, templates, policies |
