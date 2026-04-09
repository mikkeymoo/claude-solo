---
name: mm-a11y
description: "Audit frontend components for accessibility (WCAG 2.1 AA): missing ARIA labels, keyboard traps, contrast issues, screen reader problems. Auto-fixes what it safely can."
---

# mm-a11y

Audit frontend components for accessibility (WCAG 2.1 AA): missing ARIA labels, keyboard traps, contrast issues, screen reader problems. Auto-fixes what it safely can.

## Instructions
Audit the frontend for accessibility issues and auto-fix what's safe to fix.

Delegate to the accessibility-auditor agent.

Scope:
1. Scan component files (React/Vue/Angular/HTML) for ARIA, semantic HTML, keyboard, and color issues
2. Auto-fix clear, low-risk issues: missing alt text, aria-label on icon buttons, aria-hidden on decorative SVGs
3. Present higher-risk fixes (role changes, structural changes) for approval
4. Report all WCAG 2.1 AA violations with file:line and fix

After the audit, produce a summary:

```markdown
## Accessibility Audit Results

### Auto-fixed (already committed)
- X issues fixed across Y files

### Needs your review
- [list structural changes needing approval]

### Remaining violations
| Severity | Count | Top issue |
|----------|-------|-----------|
| Critical | X     | ... |
| High     | X     | ... |
| Medium   | X     | ... |

### Next step
Run `/mm:a11y` again after fixes to confirm resolution.
```

If no frontend files found, report that this project has no auditable UI components.
