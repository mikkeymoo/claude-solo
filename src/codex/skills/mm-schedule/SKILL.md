---
name: mm-schedule
description: "Create, list, and manage scheduled recurring tasks — daily PR reviews, weekly health checks, nightly test runs. Wraps Claude Code's built-in cron scheduling."
---

# mm-schedule

Create, list, and manage scheduled recurring tasks — daily PR reviews, weekly health checks, nightly test runs. Wraps Claude Code's built-in cron scheduling.

## Instructions
Manage scheduled recurring tasks for this project.

Detect what operation the user wants:
- **list** — show all scheduled tasks
- **add** — create a new scheduled task
- **remove** — delete a scheduled task
- **run** — run a scheduled task right now

---

## List scheduled tasks

Use the CronList tool to show all active schedules:

```
[use CronList tool]
```

Display them in a readable table:
```
ID          Schedule      Last run    Next run    Prompt
─────────────────────────────────────────────────────────────
abc123      0 9 * * 1     2026-04-07  2026-04-14  Weekly doctor...
def456      0 2 * * *     2026-04-07  2026-04-08  Nightly test run...
```

If no schedules exist, say so and offer to create one.

---

## Add a scheduled task

Ask the user:
1. **What should it do?** (natural language description)
2. **When?** — offer these presets or let them enter cron syntax:

| Preset | Cron | Description |
|--------|------|-------------|
| Hourly | `0 * * * *` | Every hour |
| Daily 9am | `0 9 * * *` | Every day at 9am UTC |
| Daily 2am | `0 2 * * *` | Every day at 2am UTC (good for tests) |
| Weekly Mon | `0 9 * * 1` | Every Monday at 9am UTC |
| Weekly Fri | `0 17 * * 5` | Every Friday at 5pm UTC |
| Custom | — | Enter cron expression directly |

3. **Prompt to run** — what Claude should do at that time.

Then create with CronCreate:
```
[use CronCreate tool with schedule and prompt]
```

**Pre-built schedules** (suggest these if user is unsure):

**Daily health check:**
- Cron: `0 9 * * *`
- Prompt: "Run /mm:doctor and report any issues found. If tests are failing or dependencies are outdated, open a GitHub issue summarizing the problems."

**Weekly PR review:**
- Cron: `0 9 * * 1`
- Prompt: "Review all open pull requests for security issues, test coverage, and code quality. Post a summary comment on each PR with findings."

**Nightly test run:**
- Cron: `0 2 * * *`
- Prompt: "Run the full test suite. If any tests fail, create a GitHub issue titled 'Nightly test failure [date]' with the failure details and affected files."

**Weekly dependency audit:**
- Cron: `0 10 * * 5`
- Prompt: "Check for outdated or vulnerable dependencies using npm audit / pip-audit / cargo audit. Report findings and suggest updates for critical vulnerabilities."

---

## Remove a scheduled task

List current schedules first, then ask which to remove.

Use CronDelete with the task ID:
```
[use CronDelete tool with task ID]
```

Confirm deletion before proceeding.

---

## Run a scheduled task now

Ask which schedule to run immediately (show the list).

Use the RemoteTrigger tool or instruct Claude to execute the prompt directly.

---

After any operation, show the updated schedule list.

End with the current schedule count: "X task(s) scheduled. They run automatically even when Claude Code is closed."
