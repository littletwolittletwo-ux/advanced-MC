# SKILL.md — Code Execution Agent

> Version: 1.1 | Updated: 2026-04-11 | Applies to: Code Execution agents

> Technical reference for the Code Execution agent's toolchain and workflows.

---

## Environment Setup

### Required Environment Variables
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-key
VERCEL_TOKEN=your-vercel-token
VERCEL_ORG_ID=your-org-id
VERCEL_PROJECT_ID=your-project-id
SENTRY_DSN=your-sentry-dsn
SENTRY_AUTH_TOKEN=your-sentry-auth-token
SENTRY_ORG=your-sentry-org
SENTRY_PROJECT=your-sentry-project
GIT_REMOTE=origin
GIT_DEFAULT_BRANCH=main
```

These are loaded from the project's `.env` or environment config. Never create or modify these without instruction.

---

## Git Workflows

### Starting a New Task
```bash
git checkout main
git pull origin main
git checkout -b {{BRANCH_PREFIX}}/task-description
```

### Committing Work
```bash
git add -A
git commit -m "feat: description of what changed"
```

Conventional commit prefixes:
| Prefix | Use |
|--------|-----|
| `feat:` | New feature or functionality |
| `fix:` | Bug fix |
| `chore:` | Maintenance, deps, config |
| `refactor:` | Code restructuring without behaviour change |
| `docs:` | Documentation only |
| `test:` | Adding or updating tests |
| `style:` | Formatting, whitespace (no logic change) |

### Pushing & PRs
```bash
git push origin {{BRANCH_PREFIX}}/task-description
```
If asked to create a PR, use the GitHub CLI or provide the manual URL:
```
https://github.com/{{ORG}}/{{REPO}}/compare/main...{{BRANCH_PREFIX}}/task-description
```

### Handling Merge Conflicts
1. Pull latest main: `git fetch origin main`
2. Rebase: `git rebase origin/main`
3. Resolve conflicts file by file
4. Continue: `git rebase --continue`
5. Force push: `git push --force-with-lease`

If conflicts are complex, report them to your CEO before resolving.

---

## Supabase Operations

### Database Migrations
Always use migrations, never direct SQL in production:
```bash
supabase migration new description_of_change
# Edit the generated SQL file
supabase db push  # Apply to remote
```

### Common Patterns
```sql
-- Always enable RLS
ALTER TABLE your_table ENABLE ROW LEVEL SECURITY;

-- Create a policy
CREATE POLICY "Users can read own data" ON your_table
  FOR SELECT USING (auth.uid() = user_id);
```

### Edge Functions
```bash
supabase functions new function-name
supabase functions deploy function-name
```

### Checking Logs
```bash
supabase functions logs function-name --tail
```

---

## Vercel Operations

### Checking Deployment Status
```bash
vercel ls --token $VERCEL_TOKEN
```

### Viewing Build Logs
```bash
vercel logs <deployment-url> --token $VERCEL_TOKEN
```

### Environment Variables
```bash
# List
vercel env ls --token $VERCEL_TOKEN

# Add (follow prompts)
vercel env add VARIABLE_NAME --token $VERCEL_TOKEN
```

### Manual Deploy (if needed)
```bash
vercel --prod --token $VERCEL_TOKEN
```

### Common Build Failures
| Error | Likely Cause | Fix |
|-------|-------------|-----|
| Module not found | Missing dependency | `npm install` and push |
| Type error | TypeScript strict mode | Fix the type error |
| Out of memory | Large bundle or leak | Check imports, add `.vercelignore` |
| Function timeout | Serverless function > 10s | Optimise or increase timeout in `vercel.json` |

---

## Sentry Operations

### Pulling Error Details
When debugging a reported error, start here:
```bash
# List recent issues
sentry-cli issues list -p $SENTRY_PROJECT

# Get details on a specific issue
sentry-cli issues show <issue-id>
```

### Checking Events
Use the Sentry web UI or API:
```bash
curl -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/projects/$SENTRY_ORG/$SENTRY_PROJECT/issues/<issue-id>/events/"
```

### Uploading Source Maps
Ensure this runs on every deployment:
```bash
sentry-cli releases new <release-version>
sentry-cli releases files <release-version> upload-sourcemaps ./dist
sentry-cli releases finalize <release-version>
```

### Adding Context in Code
```typescript
import * as Sentry from "@sentry/nextjs"; // or your framework

Sentry.setContext("task", {
  taskId: "abc-123",
  action: "booking_sync",
});

Sentry.captureException(error);
```

---

## Debugging Protocol

When you encounter an error during task execution:

### Step 1: Read the Error
- Full stack trace
- Error message
- File and line number
- Any Sentry breadcrumbs

### Step 2: Reproduce
- Can you trigger the same error consistently?
- What input/state causes it?

### Step 3: Isolate
- Is it a code error, config error, or dependency error?
- Is it in your code or a third-party library?
- Does it happen locally, in preview, or in production?

### Step 4: Fix & Verify
- Make the minimal change that fixes the issue
- Run tests
- Verify the error no longer occurs
- Check Sentry to confirm no new errors

### Escalation
After 3 failed fix attempts, send your CEO:
```
ESCALATION: [task description]
Error: [exact error message]
Attempted fixes:
1. [what you tried] → [what happened]
2. [what you tried] → [what happened]
3. [what you tried] → [what happened]
Hypothesis: [what you think is wrong]
Blocker: [what you need to proceed]
```

---

## Pre-Completion Checklist

Before reporting a task as complete, verify all of the following:

- [ ] Code is on a named branch (not main)
- [ ] All changes are committed with conventional commit messages
- [ ] Linter passes with no errors
- [ ] Tests pass (if test suite exists)
- [ ] Build succeeds locally
- [ ] No hardcoded secrets or credentials
- [ ] New tables have RLS enabled (if Supabase)
- [ ] Vercel preview deployment succeeds (if frontend)
- [ ] Source maps uploaded to Sentry (if deployment)
- [ ] Completion report sent to CEO via message bus
