# MASTER SEQUENCE — Agent QA System Build Plan

Feed these phases to Claude Code **one at a time**, in order. Do not skip ahead. Each phase ends with a verification step — confirm it passes before moving to the next.

## What this builds

A three-agent quality assurance loop where:

- **Builder** writes code and submits completion reports with evidence
- **Debugger** investigates bugs and submits investigation reports with evidence
- **Sunny** is the final reviewer — she independently verifies every submission against a harsh-but-reasonable audit criteria before anything is reported to David

All three agents get `agent-browser` with policies scoped to their role. Sunny's policy is read-only / audit-only; Builder's and Debugger's allow interaction within their own dev scope. Escalation flows upward through the existing `dm:sunny-builder` and `dm:sunny-debugger` bus channels — no new infrastructure.

## Prerequisites (required before Phase 1)

- [ ] `~/.openclaw/workspace` exists (Sunny)
- [ ] `~/.openclaw/workspace-builder` exists with comms wired
- [ ] `~/.openclaw/workspace-debugger` exists with comms wired
- [ ] `dm:sunny-builder` and `dm:sunny-debugger` channels live on the bus
- [ ] Launchd pollers running for builder and debugger
- [ ] Node.js >= 20 and npm available
- [ ] You are on macOS (some install details assume it)

If any of the above is missing, stop and fix it first. The rest of this plan assumes your existing Sunny/Builder/Debugger mesh is operational.

## Phase map

| Phase | File | What happens | Who does it |
|-------|------|--------------|-------------|
| 1 | `phase-1-install.md` | Install agent-browser globally, generate encryption key | Claude Code |
| 2 | `phase-2-sunny.md` | Configure Sunny as reviewer (audit criteria, protocols, read-only browser) | Claude Code |
| 3 | `phase-3-builder.md` | Configure Builder (dev-scope browser, completion reports, handoff protocol) | Claude Code |
| 4 | `phase-4-debugger.md` | Configure Debugger (diagnostic browser, investigation reports, handoff protocol) | Claude Code |
| 5 | `phase-5-smoke-and-audit.md` | Seed test credentials, run two round-trip drills, final audit | Claude Code + you |

## How to run each phase

1. Open a fresh Claude Code session in a sensible working directory (e.g. `~/openclaw-qa-build`)
2. Paste the entire contents of the phase file as the first message
3. Let CC execute it end-to-end
4. At the end of each phase, CC will print a **verification summary**. Read it carefully
5. If verification fails, do not advance — feed the failure back to CC, let it fix, then re-verify
6. Only when verification passes cleanly, open a new session and run the next phase

Fresh sessions between phases are deliberate — they prevent context bleed and keep each phase's instructions crisp.

## Success criteria for the whole package

When all five phases pass cleanly, you should have:

1. `agent-browser` installed globally with encrypted vault at `~/.agent-browser/.encryption-key`
2. Three wrappers: `~/.openclaw/workspace/bin/browser` (Sunny, read-only), `~/.openclaw/workspace-builder/bin/browser`, `~/.openclaw/workspace-debugger/bin/browser`
3. Three policy files appropriate to each role
4. `HANDOFF_PROTOCOL.md` identical in all three workspaces' `reference/` dirs
5. `AUDIT_CRITERIA.md` and `REVIEW_PROTOCOL.md` in Sunny's `reference/`
6. `SKILL_BROWSER.md` tuned per-role in Builder and Debugger workspaces
7. Report templates (`COMPLETION_REPORT_TEMPLATE.md` for Builder, `INVESTIGATION_REPORT_TEMPLATE.md` for Debugger)
8. SOUL.md updates in all three agents referencing the new protocol
9. Two successful round-trip drills (a trivial build task and a trivial investigation)
10. Final audit checklist returning all green

## Rollback

Everything in this plan is file-based and additive. To roll back:

```bash
# Remove wrappers
rm -f ~/.openclaw/workspace{,-builder,-debugger}/bin/browser

# Remove new reference docs
rm -f ~/.openclaw/workspace/reference/{AUDIT_CRITERIA,REVIEW_PROTOCOL,HANDOFF_PROTOCOL}.md
rm -f ~/.openclaw/workspace-builder/reference/{HANDOFF_PROTOCOL,SKILL_BROWSER,COMPLETION_REPORT_TEMPLATE,browser-policy.json}
rm -f ~/.openclaw/workspace-debugger/reference/{HANDOFF_PROTOCOL,SKILL_BROWSER,INVESTIGATION_REPORT_TEMPLATE,browser-policy.json}

# Revert SOUL.md changes — sections are appended with clear markers,
# delete everything between "## Browser Tool / Review Protocol" and the next ---
```

The `agent-browser` global install and Chrome for Testing download remain — those are harmless and re-usable.

## Timing estimate

- Phase 1: ~5 minutes (just installs)
- Phase 2: ~10-15 minutes (writes multiple reference docs)
- Phase 3: ~10 minutes
- Phase 4: ~10 minutes
- Phase 5: ~20-30 minutes (includes two live smoke tests)

Total: under an hour of CC time, plus a few minutes of your attention between phases.

---

Proceed to `phase-1-install.md`.
