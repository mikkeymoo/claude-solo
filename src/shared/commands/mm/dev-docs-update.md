# /dev-docs-update Command

Refreshes the in-progress documentation set (plan, context, tasks) with the latest implementation details before compacting or switching sessions.

## Usage
```
/dev-docs-update [feature-name]
```

## What It Does
1. Reads the existing `[feature]-plan.md`, `[feature]-context.md`, and `[feature]-tasks.md` files.
2. Gathers recent decisions, file changes, and open questions from the active session.
3. Appends new context, marks completed checklist items, and queues newly discovered follow-up work.

## Workflow
- **Sync progress**: Checkbox tasks are marked complete when code lands.
- **Capture learnings**: Summaries of discoveries, risks, and TODOs are appended to the context file.
- **Prep next session**: Adds "Next Steps" to keep Claude anchored even after auto-compaction.

## Best Practices
- Run before ending any session or compacting context.
- Use alongside `/dev-docs` so plans stay authoritative.
- Mention the feature name explicitly to avoid updating the wrong docs.

## Example Invocation
```
/dev-docs-update onboarding-wizard
```
Outputs a short diff summary confirming which sections were updated and what next actions were recorded.
