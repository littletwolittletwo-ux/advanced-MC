# SKILL_BROWSER.md — Debugger's browser tool

You have `bin/browser`. This is your **primary investigation instrument** — default to reproducing web bugs in the browser, not to reading logs remotely. Logs tell you what the system recorded; the browser tells you what the user experienced.

## When to use

- **Reproduction** — every web-facing bug starts here
- **Evidence capture** — HAR, console, errors, screenshots, traces
- **Hypothesis validation** — does changing <condition> change the symptom?
- **Fix verification** — after Builder claims a fix, drive the same repro and confirm
- **Regression hunting** — when a bug reappears, compare current HAR against original HAR

## When NOT to use

- **Production mutations** — policy denies destructive clicks, and you should not override this. If reproduction genuinely requires a destructive action (e.g., "the bug only appears on delete"), DM Sunny on `dm:sunny-debugger` and request explicit approval with a test account.
- **Data extraction at volume** — not your role. Investigation → short, focused HAR captures, not mass scraping.
- **Any action on a domain outside your allowlist** — escalate, don't override.

## Reproduction workflow (the canonical flow)

Assume you are investigating bug `<bug-id>`. Create a workspace for it:

```
mkdir -p ./gnap/<bug-id>
cd ./gnap/<bug-id>
```

Then capture the full repro:

```
# 1. Start HAR capture BEFORE you open the page
browser network har start

# 2. Navigate and drive the failing flow
browser open <url>
browser wait --load networkidle
browser snapshot -i --json > snapshot-before.json
browser screenshot before.png

# ... drive the steps that trigger the bug (click, fill, etc) ...

browser screenshot failure.png
browser snapshot -i --json > snapshot-after.json

# 3. Stop HAR and capture diagnostics
browser network har stop ./failure.har
browser console > console.txt
browser errors  > errors.txt

# 4. Capture failing network calls specifically
browser network requests --status 4xx,5xx --json > failing-requests.json
browser network requests --type xhr,fetch --json  > all-xhr.json
```

Every file in `./gnap/<bug-id>/` goes in your investigation report's EVIDENCE section.

## Diagnostic commands

```
# Console and errors
browser console                        # all console messages
browser console --clear                # clear before starting a new repro pass
browser errors                         # uncaught exceptions

# Network
browser network requests                             # all tracked requests
browser network requests --filter <substr>           # narrow by URL substring
browser network requests --status 4xx,5xx            # failing calls only
browser network requests --method POST               # filter by method
browser network request <requestId>                  # full req/resp detail

# HAR
browser network har start
# ... drive flow ...
browser network har stop <path>.har

# Traces and profiles (use sparingly — large files)
browser trace start
# ... drive flow ...
browser trace stop <path>

browser profiler start
# ...
browser profiler stop <path>.json

# Comparison
browser diff snapshot --baseline snapshot-before.json
browser diff screenshot --baseline before.png
browser diff url <prod-url> <staging-url> --screenshot    # cross-env diff
```

## Fix verification (post-Builder handoff)

When Builder claims a fix, repeat your own original repro verbatim. The fix is verified if and only if:

1. The original repro steps no longer reproduce the failure
2. The network trace shows the previously-failing call now succeeds (or the call pattern has legitimately changed)
3. `browser errors` is clean where it was previously exceptions
4. No new errors or warnings have appeared in `browser console`

Capture this as verification evidence:

```
mkdir -p ./gnap/<bug-id>/fix-verification
browser network har start
# ... re-run the original repro exactly ...
browser network har stop ./gnap/<bug-id>/fix-verification/post-fix.har
browser console > ./gnap/<bug-id>/fix-verification/console.txt
browser errors  > ./gnap/<bug-id>/fix-verification/errors.txt
browser screenshot ./gnap/<bug-id>/fix-verification/post-fix.png
browser diff screenshot --baseline ./gnap/<bug-id>/before.png \
  -o ./gnap/<bug-id>/fix-verification/diff.png
```

## Authentication

Same as Builder — never type passwords inline. Use `browser auth login <n>`. If the vault doesn't have the credentials for the site you need to investigate, DM Sunny on `dm:sunny-debugger` with:

```
NEED_VAULT_ENTRY
Site: <url>
Purpose: reproducing <bug-id>
Test account needed: <y/n, if a separate test account should be created>
```

## Escalation triggers — DM Sunny on dm:sunny-debugger

- Repro requires a destructive action → need explicit approval for a test account
- Bug is only reproducible in production → need confirmation to investigate there
- Repro requires credentials not in the vault
- Allowlist doesn't cover a domain you need (e.g., a new third-party service)
- You've identified a root cause that's outside the system's codebase (third-party bug, platform issue)
- You find a second unrelated bug during investigation — report it, do not silently pursue it

## Output size

HAR files can be multi-MB. Traces and profiles can be 10+MB. Store them under `./gnap/<bug-id>/` and reference paths — never inline. If a HAR is >10MB, capture a narrower slice by trimming the repro to the minimum failing sequence.

## Cleanup

After a bug is closed and verified:

```
# Archive rather than delete (keeps forensic record)
tar -czf ./gnap/archive/<bug-id>-<yyyymmdd>.tar.gz ./gnap/<bug-id>/
rm -rf ./gnap/<bug-id>/
```

Cron sweeps `./gnap/archive/` quarterly.
