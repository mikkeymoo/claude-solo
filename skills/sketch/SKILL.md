---
name: sketch
description: "Rapidly scaffold a working prototype from a description. Use for spikes, experiments, and throwaway code. Faster but less complete than /scaffold."
argument-hint: "[description | --api | --cli | --ui | --script]"
---

# /sketch — Quick Prototype

Rapidly scaffold a working prototype from a description. Built for speed over completeness — generate something runnable in < 2 minutes.

Use for: spikes, proof-of-concept code, throwaway experiments, learning new libraries.
Don't use for: production systems, long-lived features, anything security-sensitive.

Four modes:

- `--script` (default) — Standalone script that does one thing
- `--api` — REST endpoint prototype (auto-detects framework)
- `--cli` — Command-line tool with argument parsing
- `--ui` — React component with props and basic styling

## Philosophy

- Skip tests, skip docs, skip complex error handling unless critical
- Mark everything: `// PROTOTYPE - not production ready`
- Default to simplest choice (vanilla JS, plain Python, no frameworks unless asked)
- Output must be runnable immediately — no compilation, no setup

## Default — Standalone Script

Generate a single-file script that solves the described problem.

1. **Understand** — restate what the script should do in one sentence
2. **Skeleton** — main() function + minimal imports
3. **Implement** — core logic only; skip edge cases
4. **Test command** — output a `python script.py` or `node script.js` command to run it
5. **Label** — add `// PROTOTYPE` comment at top of file

Output:

```
Created: <filename>
Run it: python <filename> <args>
```

Example: `sketch "read CSV and count rows"`
→ Creates `count_rows.py` with CSV read + row count, accepts filename as arg.

## --api — REST Endpoint

Generate a single endpoint in a minimal REST framework.

1. **Detect framework** — check project for package.json or requirements.txt; default to Express (Node) or FastAPI (Python)
2. **Generate** — single route file + handler function + basic input validation
3. **Output test** — provide a `curl` command to test the endpoint
4. **Label** — add `// PROTOTYPE` comment

Output:

```
Created: <route_file>
Framework: <detected>
Test: curl -X POST http://localhost:3000/endpoint -d '{"key": "value"}'
```

Example: `sketch --api "endpoint that sums two numbers"`
→ Creates route with POST handler, validates input, returns sum. Includes curl test.

## --cli — Command-Line Tool

Generate a CLI script with argument parsing.

1. **Parse args** — argparse (Python) or yargs (Node) or minimal argv parsing
2. **Implement** — main function that handles arguments
3. **Usage string** — `--help` should work and describe all flags
4. **Test command** — output a `<script> --help` and example invocation

Output:

```
Created: <script_name>
Test: python <script_name> --help
Example: python <script_name> --input file.txt --output result.txt
```

Example: `sketch --cli "tool that transforms JSON to CSV"`
→ Creates CLI with `--input` and `--output` flags, implements JSON→CSV conversion.

## --ui — React Component

Generate a functional component with props and one visual state.

1. **Detect React** — check for React in project; if missing, use minimal React (no TypeScript unless in tsconfig)
2. **Component** — functional component with typed props
3. **State** — one useState for a visual demo (button click, toggle, form input)
4. **Styling** — inline styles or basic CSS-in-JS; no tailwind unless found in project
5. **Label** — add `// PROTOTYPE` comment

Output:

```
Created: <ComponentName>.tsx (or .jsx)
Usage: <ComponentName name="value" />
```

Example: `sketch --ui "button that increments a counter"`
→ Creates `Counter.tsx` with useState, increment handler, display count.

## Success Criteria

- ✓ Generates valid, runnable code in < 2 minutes
- ✓ Single file (or minimal file set) with no missing dependencies
- ✓ Clearly marked as prototype in code comments
- ✓ Includes working test/invocation command
- ✓ No external API calls or database dependencies required
- ✓ No build step required (or minimal `node script.js` / `python script.py`)

## After Prototyping

Once the prototype works and you want to make it production-ready:

```
Prototype created. To make production-ready:
- Add error handling (/fix for bugs)
- Add tests (/tdd for coverage)
- Add validation (/quality --gate for verification)
- Consider architecture (/riper --plan for structure)
```

## Notes

- If the user's description is ambiguous, ask for clarification in one sentence before generating
- If the project has package.json/requirements.txt, use existing tech stack for `--api`; otherwise default to vanilla
- Don't add authentication, database connections, or external service calls — keep it local and simple
- If generation would require > 50 lines and multiple files, suggest using `/scaffold` instead
