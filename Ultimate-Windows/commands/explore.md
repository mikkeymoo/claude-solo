---
name: mm:explore
description: "Map an unfamiliar codebase, feature area, or API. Returns a mental model, not just a file list."
argument-hint: "[area, feature, or question to explore]"
---

Map the specified area of the codebase and return a useful mental model.

1. **Entry points** — find the top-level files, routes, or modules for this area
2. **Data flow** — trace how data enters, transforms, and exits (ASCII diagram if helpful)
3. **Key abstractions** — name the 3-5 most important types, functions, or modules and what they do
4. **Gotchas** — anything non-obvious, surprising, or that would trip up someone new
5. **Gaps** — missing tests, undocumented behavior, or places the code doesn't match expectations

Use Serena LSP (`mcp__serena__find_symbol`, `find_referencing_symbols`, `get_symbols_overview`) over grep where possible for accuracy.

Return a summary I can act on — not a raw file listing.
