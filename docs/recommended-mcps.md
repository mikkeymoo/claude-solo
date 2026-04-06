# Recommended MCP Servers for claude-solo

These are optional but useful. Install them separately — claude-solo doesn't manage MCPs.

---

## Already Included in Claude Code

**Context7** (`@context7`) — official library documentation lookup.
Already bundled with Claude Code. No install needed. Use it when working with any framework or library.

---

## Worth Installing

### Playwright MCP — Browser Automation & E2E Testing

Use for: testing UIs, scraping, visual validation, E2E test runs from within Claude Code.

**Install:**
```bash
# Add to your ~/.claude/settings.json mcpServers block:
npx @playwright/mcp@latest --help   # verify it's available
```

**settings.json entry:**
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"],
      "env": {}
    }
  }
}
```

**What it enables in claude-solo:**
- `/mm:test` can run real browser tests (not just unit/integration)
- `/mm:doctor` can validate UI health
- `/mm:autopilot` can include E2E validation before `/ship`

**Docs:** https://github.com/microsoft/playwright-mcp

---

## Deliberately Excluded

| MCP | Why skipped |
|-----|-------------|
| Tavily | Web search — Claude's built-in search is sufficient for most tasks |
| Sequential-Thinking | Interesting but adds overhead; native reasoning handles most cases |
| Magic (21st.dev) | UI component generation — not relevant for Python/backend-heavy work |
| Morphllm | Bulk edits — Edit tool handles this fine |

---

## What gstack Does Instead

gstack avoids MCP entirely for browser automation. They run a **Bun HTTP server** that Playwright talks to directly:

```
Claude Code → HTTP → Bun daemon → Playwright → Chromium
```

This is more token-efficient but requires running the daemon manually. For Claude Code integration, the Playwright MCP is simpler and officially supported.
