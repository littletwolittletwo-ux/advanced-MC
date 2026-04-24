# SKILL_BROWSER.md — Builder's browser tool

You have `bin/browser` available. It wraps `agent-browser` with your session, profile, domain allowlist, and action policy already configured. Do not call `agent-browser` directly.

## When to use

- **Verify your own work**: after implementing a change, drive the affected flow(s) and confirm behaviour
- **Visual regression**: take screenshots before/after a UI change, compare with `diff screenshot`
- **Smoke-test forms and interactions**: after wiring up a form, submit it and watch the response
- **Read docs not in your context**: open the documentation page, snapshot, answer your question
- **Check that a dev server or preview deploy is actually working**: open, snapshot, confirm
- **Produce evidence for your completion report**: screenshots, HAR, console output

## When NOT to use

- **Scraping or data extraction**: not your job. If a task devolves into scraping, escalate to Sunny.
- **Testing production**: your allowlist does not include production. If testing requires prod, escalate.
- **Destructive actions** (delete, deploy, publish, pay, transfer): policy will deny. Do not retry with different wording — escalate.
- **Sites you have no vault credentials for**: do not manually type passwords. Use `browser auth login <name>` or escalate to Sunny for a new vault entry.

## Standard flow (the happy path)

```
browser open <url>
browser wait --load networkidle
browser snapshot -i --json             # see interactive elements, get refs
browser click @eN                      # interact by ref
browser fill @eN "value"
browser screenshot ./evidence/<task>/<step>.png
```

## Evidence capture (required for every completion report)

For any task that touches UI:

```
# Before-state screenshots (take these BEFORE making code changes if possible)
browser open <url-of-affected-page>
browser screenshot ./evidence/<task-id>/before-<page-name>.png

# After-state screenshots (after changes, server restarted)
browser open <url-of-affected-page>
browser screenshot ./evidence/<task-id>/after-<page-name>.png

# Console and errors during the verification drive-through
browser console > ./evidence/<task-id>/console.txt
browser errors  > ./evidence/<task-id>/errors.txt

# Network trace of the happy-path flow
browser network har start
# ... drive the flow end-to-end ...
browser network har stop ./evidence/<task-id>/flow.har
```

File the paths in your completion report's EVIDENCE section. Do not inline contents — reference paths.

## Authentication

Never type passwords inline into form fields. Always use the vault:

```
browser auth login <vault-name>
```

If the vault does not contain the credentials you need, DM Sunny on `dm:sunny-builder`:

```
NEED_VAULT_ENTRY
Site: <url>
Purpose: <why you need it for this task>
```

Sunny provisions credentials. You never handle raw passwords.

## Escalation triggers — DM Sunny on dm:sunny-builder

- 2FA code prompt appears (Sunny relays from David)
- Captcha (human required)
- Login form with no vault entry yet
- Policy denied an action you believe is legitimate for this task
- Allowlist blocks a domain you need (propose which one and why)
- Flow behaves unexpectedly and might affect real systems
- Verification reveals a bug outside the scope of your current task (report it, do not silently fix)

## Timeout behaviour

Default operation timeout is 25s. For slow pages (`load networkidle` can be slow on heavy apps), chain an explicit wait:

```
browser open <url>
browser wait --load networkidle     # explicit wait
browser snapshot -i
```

If 25s is genuinely not enough for legitimate operations, ask Sunny — do not self-modify the wrapper.

## Sessions are isolated

Your session name is `builder`. State (cookies, localStorage, logins) persists in `~/.agent-browser/profiles/builder`. You do not see Debugger's or Sunny's session state and they do not see yours. If you need to share artifacts with them, put files under `~/.openclaw/workspace-builder/evidence/<task-id>/` and reference the paths in bus messages.
