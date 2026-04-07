---
name: mm-ci
description: "Review or generate GitHub Actions CI/CD workflows. Detects existing config and suggests improvements or creates new pipelines."
---

# mm-ci

Review or generate GitHub Actions CI/CD workflows. Detects existing config and suggests improvements or creates new pipelines.

## Instructions
Review or generate CI/CD pipeline configuration for the current project.

First, detect what's already there:
```bash
ls .github/workflows/ 2>/dev/null || echo "No GitHub Actions workflows found"
ls .gitlab-ci.yml Jenkinsfile .circleci/ 2>/dev/null || true
```

**If reviewing existing workflows:**

Check for:
1. **Test coverage** — do all PRs run the full test suite?
2. **Branch protection** — does main require passing CI before merge?
3. **Secret handling** — are secrets in GitHub Secrets, not hardcoded?
4. **Caching** — are dependencies cached? (pip, npm, cargo)
5. **Matrix testing** — if cross-platform, tested on Windows AND Linux?
6. **Fail fast** — does a test failure stop the pipeline immediately?
7. **Deploy safety** — is prod deploy gated on staging passing?
8. **Notifications** — do failures notify someone?

Flag issues as: 🔴 Missing entirely | 🟡 Present but weak | ✅ Good

**If generating a new workflow:**

Ask:
1. What language/runtime? (Python, Node, .NET)
2. What test command? (`pytest`, `vitest`, `dotnet test`)
3. Deploy target? (none, Azure, AWS, Fly.io, Docker Hub, PyPI, npm)
4. Trigger: PRs only, or PRs + main push?

Then generate `.github/workflows/ci.yml` with:
- Trigger on: push to main, pull_request to main
- Checkout + setup runtime with caching
- Install dependencies
- Run linter (if configured)
- Run tests with coverage
- Upload coverage report (Codecov if configured)
- Deploy step (only on main, only if tests pass)

Write the file — don't just show it.

End with: "CI workflow written to `.github/workflows/ci.yml`. Push to GitHub to activate."
