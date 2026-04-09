---
name: mm:stale
description: "Find stale code: dead functions, unused exports, TODO/FIXME older than 30 days, commented-out code blocks, and deprecated patterns. Produces a cleanup checklist."
---

Find and catalogue stale code: dead functions, forgotten TODOs, commented-out code, and deprecated patterns.

Run:
```bash
rtk git log --oneline -5
```

Scan the codebase for:

**1. TODOs and FIXMEs older than 30 days**
```bash
grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.js" --include="*.py" --include="*.rs" . | grep -v node_modules
```
For each hit: check `git log -1 -- <file>` to see when it was last touched.
Flag items that haven't been addressed in 30+ days.

**2. Commented-out code blocks**
```bash
grep -rn "^[[:space:]]*//.*[a-zA-Z_]\+\s*(" --include="*.ts" --include="*.js" . | grep -v node_modules | head -50
grep -rn "^[[:space:]]*#.*def \|^[[:space:]]*#.*class " --include="*.py" . | head -50
```
Commented-out functions and classes that are still present.

**3. Dead exports (unused)**
```bash
# Check for TypeScript exported symbols with no importers:
grep -rn "^export " --include="*.ts" . | grep -v node_modules | grep -v ".d.ts" | head -50
```
For each export, verify it's imported somewhere: `grep -r "import.*<name>" .`

**4. Deprecated usage patterns**
- `any` type in TypeScript (flag for review)
- `eval()` calls
- `var` declarations in JS/TS (prefer `const`/`let`)
- `console.log` in production code (not test files)
- Hardcoded localhost/127.0.0.1 URLs

**5. Unreachable code**
- Functions/branches that can never be reached given the logic flow
- Conditions that are always true or always false

**Output format:**

```markdown
## Stale Code Report

### Old TODOs (30+ days)
- `src/api/users.ts:45` — TODO: validate email format (last touched: 2024-01-15)

### Commented-out code
- `src/utils/crypto.ts:88-102` — commented-out hashPassword function

### Possibly dead exports
- `src/types/legacy.ts` — 3 exports with no importers found

### Deprecated patterns
- 12 uses of `console.log` in non-test files

### Recommended cleanup
1. [ ] ...
2. [ ] ...
```

Do not delete anything automatically — produce a checklist for human review.
