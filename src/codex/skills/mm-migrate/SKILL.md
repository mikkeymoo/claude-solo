---
name: mm-migrate
description: "Plan and execute a database migration safely: schema change, backfill, constraint tightening. Uses migration-specialist agent to prevent data loss."
---

# mm-migrate

Plan and execute a database migration safely: schema change, backfill, constraint tightening. Uses migration-specialist agent to prevent data loss.

## Instructions
Plan and execute a database migration safely using the migration-specialist agent.

## Usage

Describe what schema change you need. Examples:
- "Add `verified_at` column to users table"
- "Rename `user_id` to `customer_id` in orders"
- "Add foreign key from invoices.user_id → users.id"
- "Remove the deprecated `old_status` column"

## Workflow

The migration-specialist agent will:

1. **Check current state**
   ```bash
   rtk git status
   # Check migration history for your ORM
   ```

2. **Plan the migration**
   - Identify if the change requires multiple steps (add nullable → backfill → add constraint)
   - Flag any locking risks on large tables
   - Note if a rollback is possible

3. **Write the migration**
   - Forward migration with safety guards
   - Down/rollback migration
   - Backfill query if needed

4. **Test locally**
   - Apply the migration on dev
   - Confirm no errors
   - Test rollback

5. **Review the SQL** (not just ORM DSL)
   - Show the generated SQL for your approval before applying

6. **Apply and verify**
   - Apply migration
   - Verify schema matches expectation
   - Run existing tests to confirm no regressions

## Safety rules

- Never auto-apply a migration that drops data — always ask first
- For production: show migration plan, require explicit confirmation
- Always show generated SQL before applying
