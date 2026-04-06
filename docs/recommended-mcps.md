# Recommended MCP Servers for claude-solo

These are optional but useful. claude-solo ships a template at `src/mcp.json` — copy it to your project root as `.mcp.json` and enable the servers you need.

---

## Quick Start

```bash
# Copy the template to your project
cp ~/.claude/mcp.json .mcp.json

# Edit .mcp.json — set "disabled": false for servers you want
# Fill in any required env vars (GITHUB_TOKEN, DATABASE_URL, etc.)
```

---

## Already Included in Claude Code

**Context7** (`@context7`) — official library documentation lookup.
Already bundled with Claude Code. No install needed. Use it when working with any framework or library.

---

## Tier 1 — Recommended for All Projects

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

### Playwright MCP — Browser Automation & E2E Testing

Use for: testing UIs, visual validation, E2E test runs, accessibility checks.

```json
{
  "playwright": {
    "command": "npx",
    "args": ["-y", "@playwright/mcp@latest"]
  }
}
```

No credentials needed. Pairs with `/mm:test` and `/mm:verify`.

---

## Tier 2 — When You Need Them

### PostgreSQL MCP — Read-Only Database Access

Use for: exploring schemas, running queries, debugging data issues.

```json
{
  "postgres": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-postgres"],
    "env": { "POSTGRES_CONNECTION_STRING": "${DATABASE_URL}" }
  }
}
```

Read-only by default — safe to enable in development.

### Sentry MCP — Production Error Tracking

Use for: querying errors, stack traces, issue management from within Claude.

```json
{
  "sentry": {
    "command": "npx",
    "args": ["-y", "@sentry/mcp-server"],
    "env": { "SENTRY_AUTH_TOKEN": "${SENTRY_AUTH_TOKEN}", "SENTRY_ORG": "${SENTRY_ORG}" }
  }
}
```

Pairs with `/mm:incident` for production debugging.

### Brave Search MCP — Web Search

Use for: real-time web search when Claude's knowledge isn't enough. Free tier: 2000 queries/month.

```json
{
  "brave-search": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-brave-search"],
    "env": { "BRAVE_API_KEY": "${BRAVE_API_KEY}" }
  }
}
```

### Memory MCP — Persistent Knowledge Graph

Use for: cross-session context that goes beyond file-based memory.

```json
{
  "memory": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-memory"]
  }
}
```

No credentials needed.

---

## Tier 3 — Specialized

| MCP Server | Use Case | Setup |
|------------|----------|-------|
| Terraform MCP | IaC with real provider schemas | `@hashicorp/terraform-mcp-server` |
| Atlassian MCP | Jira + Confluence integration | `sooperset/mcp-atlassian` |
| Linear MCP | Sprint/ticket context | `tacticlaunch/mcp-linear` |
| Notion MCP | Product docs and wikis | Various implementations |

---

## Best Practices

- **3 servers is the sweet spot.** 5 is the max before token overhead hurts performance.
- **Start with GitHub + Playwright.** Add others only when you have a concrete need.
- **All servers are disabled by default** in the template. Enable one at a time.
- **Keep credentials in env vars**, never in `.mcp.json` directly.
- **Add `.mcp.json` to `.gitignore`** if it contains project-specific credentials.

---

## Deliberately Excluded

| MCP | Why skipped |
|-----|-------------|
| Sequential-Thinking | Adds overhead; native reasoning handles most cases |
| Magic (21st.dev) | UI component generation — not needed for most projects |
| Morphllm | Bulk edits — Edit tool handles this fine |
