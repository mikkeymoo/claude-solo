---
name: zoom-out
description: "Get a higher-level perspective on code, or systematic deep-dive exploration (--explore). Use when unfamiliar with code or need to understand how something fits together."
---

# /zoom-out — Codebase Exploration

## Default — Quick Context

I don't know this area of code well. Go up a layer of abstraction. Give me a map of all the relevant modules and callers, using the project's domain glossary vocabulary.

## --explore — Systematic Deep-Dive

Map the specified area and return a useful mental model.

1. **Entry points** — top-level files, routes, or modules for this area
2. **Data flow** — how data enters, transforms, and exits (ASCII diagram if helpful)
3. **Key abstractions** — the 3-5 most important types, functions, or modules
4. **Gotchas** — anything non-obvious or surprising
5. **Gaps** — missing tests, undocumented behavior, code/expectation mismatches

Use Serena LSP over grep where possible. Return a summary you can act on — not a raw file listing.
