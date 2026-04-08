---
name: mm:github-setup
description: "Set up Claude Code GitHub integration: install the GitHub App for PR @mentions and autonomous issue handling, or generate a GitHub Actions CI workflow."
---

Set up Claude Code's GitHub integration for this project.

First, detect what already exists:
```bash
ls .github/workflows/ 2>/dev/null && echo "workflows found" || echo "no workflows"
ls .github/workflows/claude*.yml 2>/dev/null || echo "no claude workflow"
```

Ask the user which they want:

**Option A — GitHub App (PR @mention + autonomous issue handling)**
**Option B — GitHub Actions CI workflow**
**Option C — Both**

---

## Option A: GitHub App

The Claude Code GitHub App lets you:
- `@claude` in any PR comment → Claude implements the request
- Assign issues to `claude` → Claude opens a PR
- Auto-review PRs on push

**Setup steps:**

1. Run the install command:
   ```
   /install-github-app
   ```
   Follow the prompts — it will guide you through GitHub OAuth.

2. After install, add this secret to your GitHub repo:
   - Go to Settings → Secrets and variables → Actions
   - Add `ANTHROPIC_API_KEY` with your API key

3. Verify it works:
   - Open any PR and comment `@claude what does this PR do?`
   - Claude should reply within ~30 seconds

**Alternative auth (if using Bedrock or Vertex):**
- Use `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` + `AWS_REGION` for Bedrock
- Use `GOOGLE_APPLICATION_CREDENTIALS` for Vertex AI

---

## Option B: GitHub Actions CI Workflow

Generate `.github/workflows/claude.yml`:

```yaml
name: Claude Code

on:
  pull_request:
    types: [opened, synchronize]
  issue_comment:
    types: [created]
  issues:
    types: [assigned]

jobs:
  claude:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      issues: write

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: anthropics/claude-code-action@v1
        with:
          api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          # Optional: customize what Claude does
          # allowed-tools: "Bash,Edit,Write,Read"
          # max-turns: 10
```

Write this file. Then:

1. Commit and push:
   ```bash
   git add .github/workflows/claude.yml
   git commit -m "feat: add Claude Code GitHub Actions workflow"
   git push
   ```

2. Add secret: repo Settings → Secrets → `ANTHROPIC_API_KEY`

3. Test: open a PR and comment `@claude review this for security issues`

**Optional: Scheduled autonomous tasks**

Add to the workflow `on:` block for weekly automated review:
```yaml
  schedule:
    - cron: '0 9 * * 1'  # Every Monday 9am UTC
```

And add a step:
```yaml
      - uses: anthropics/claude-code-action@v1
        if: github.event_name == 'schedule'
        with:
          api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: "Review all open PRs for security issues and post findings as comments."
```

---

## Option C: Both

Do Option A first (GitHub App), then generate the workflow file from Option B.

---

After setup, confirm with the user:
- Which option was completed
- Whether to run `/mm:ci` to review the full CI pipeline while here

End with: "GitHub integration ready. Try `@claude` in a PR comment to test."
