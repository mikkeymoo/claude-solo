---
name: session
description: "Session management — save context, restore, or check token usage. Use when pausing work, resuming, or checking burn rate."
argument-hint: "[save | save --lite | restore | tokens]"
---

# /session — Session Lifecycle

## save — Rich handoff

Write `.planning/HANDOFF.md`: status, current stage, done tasks with commits, in-progress work, blocked items, next step, key decisions, files to review, recommended next command. Commit it. Under 500 words.

## save --lite — Quick pause

Write `.planning/PAUSE.md`: what we're building, stage, completed tasks, next task, open questions, relevant files. Commit it. Under 400 words.

## restore — Resume

Check in order: `HANDOFF.md`, `PAUSE.md`, `CHECKPOINT.md`, `SESSION-END.md`. Read it, read listed files, verify git state, announce status. Ask "Ready to continue?"

## tokens — Usage check

Parse today's token log and show total/input/output breakdown by tool.
