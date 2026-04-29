---
name: config
description: "Project and Claude Code configuration — path rules, scheduled tasks, GitHub integration, CI/CD workflow, or help guide. Use when setting up or modifying project config."
argument-hint: "[--rules | --schedule | --github | --ci | --help (default)]"
---

# /config — Configuration

- `--rules` — create and manage path-specific Claude rules in `.claude/rules/`
- `--schedule` — manage scheduled recurring tasks via CronList/CronCreate/CronDelete
- `--github` — set up Claude Code GitHub App + CI workflow
- `--ci` — review or generate GitHub Actions workflow
- No argument / `--help` — show the workflow guide

## --rules — Path-Specific Rules

Manage `.claude/rules/`. Detect intent: **list**, **create**, **edit**, **delete**, or **check** (which rules match a path).

Create: ask for paths, name, and what Claude should do differently. Write `.claude/rules/<name>.md` with frontmatter (description, globs).

## --schedule — Scheduled Tasks

**List**: readable table of active schedules.
**Add**: ask what and when (presets: hourly, daily 9am, weekly Mon, custom cron). Use CronCreate.
**Remove**: list, ask which, confirm, use CronDelete.

## --github — GitHub Integration

Offer: (A) GitHub App for PR @mentions, (B) GitHub Actions CI, or (C) both.

## --ci — CI/CD Workflow

If reviewing: check test coverage, branch protection, secrets, caching. Flag: 🔴 Missing | 🟡 Weak | ✅ Good.
If generating: ask language/runtime, test command, deploy target. Write `.github/workflows/ci.yml`.

## --help — Workflow Guide

Print all available skills, the sprint pipeline, and agent roster.
