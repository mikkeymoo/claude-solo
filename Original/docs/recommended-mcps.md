# Recommended MCP Servers for claude-solo

These are optional but useful. claude-solo ships a template at `src/mcp.json` — copy it to your project root as `.mcp.json` and enable the servers you need.

---

## Quick Start

```bash
# Copy the template to your project
cp ~/.claude/mcp.json .mcp.json

# Edit .mcp.json — set "disabled": false for servers you want
# Fill in any required env vars (GITHUB_TOKEN, etc.)
```

---

## Already Included in Claude Code

**Context7** (`@context7`) — official library documentation lookup.
Already bundled with Claude Code. No install needed. Use it when working with any framework or library.

---

## Included in the Template

### cclsp — LSP Code Intelligence

Use for: go-to-definition, find references, diagnostics, workspace symbol search — all semantic navigation.

```json
{
  "cclsp": {
    "command": "cclsp",
    "args": [],
    "env": { "CCLSP_CONFIG_PATH": "${CCLSP_CONFIG_PATH}" }
  }
}
```

Requires: `npm install -g cclsp`. See [ktnyt/cclsp](https://github.com/ktnyt/cclsp) for config.

### GitHub MCP — Full GitHub API

Use for: PRs, issues, Actions, code search, repo management — all without leaving Claude.

```json
{
  "github": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"],
    "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}" }
  }
}
```

Requires: `GITHUB_TOKEN` env var with repo scope.

---

## Best Practices

- **Keep it minimal.** Each active MCP server adds token overhead on every request.
- **All servers are disabled by default** in the template. Enable only what you need.
- **Keep credentials in env vars**, never in `.mcp.json` directly.
- **Add `.mcp.json` to `.gitignore`** if it contains project-specific credentials.

---

## Deliberately Excluded

| MCP | Why skipped |
|-----|-------------|
| Sequential-Thinking | Adds overhead; native reasoning handles most cases |
| Magic (21st.dev) | UI component generation — not needed for most projects |
| Playwright | Enable per-project when you need browser automation |
| PostgreSQL | Enable per-project when you need database access |
| Brave Search | Claude's built-in web search covers most cases |
| Memory | File-based memory system is sufficient |
| Sentry | Enable per-project when debugging production errors |
