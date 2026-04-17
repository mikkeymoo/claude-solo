# Database Migration Rules

When working with database migration files (e.g. files in `migrations/`, `db/migrate/`, `prisma/migrations/`, `alembic/versions/`):

- Never modify an already-applied migration — create a new one instead
- Migration filenames must be timestamped and sequential (e.g. `20240101_add_users_table.sql`)
- Every migration must have a corresponding rollback/down migration unless irreversible
- Never DROP a column or table without confirming the data is backed up or truly unused
- Prefer `ALTER TABLE ... ADD COLUMN ... DEFAULT NULL` over NOT NULL columns in large tables (avoid long locks)
- Run `rtk prisma migrate status` or equivalent to check migration state before authoring a new one
- Always review the generated SQL before applying to production
