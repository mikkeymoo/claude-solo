# CI/CD Workflow Rules

When creating or editing GitHub Actions workflows or other CI/CD config:

- Pin all third-party actions to a full commit SHA, not a mutable tag (`uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`)
- Never echo secrets in run steps — use masked environment variables
- Use `GITHUB_TOKEN` (not a PAT) for repository operations whenever possible
- Set `permissions` explicitly at the job level — use least-privilege (e.g. `contents: read`)
- Cache dependencies (`node_modules`, `.venv`, cargo registry) keyed on lockfile hash
- Add `timeout-minutes` to every job to prevent runaway bills
- Use `continue-on-error: false` (default) for required checks — don't silently swallow failures
- Separate lint/typecheck steps from test steps so failures are diagnosed clearly
- Never `git push --force` in CI — if rewriting history is needed, use a separate protected workflow
- Add branch protection rules for `main`: require status checks, require PR review
