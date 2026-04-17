# Configuration File Rules

When creating or modifying configuration files (`tsconfig.json`, `eslint.config.*`, `prettier.config.*`, `vite.config.*`, `next.config.*`, etc.):

- Don't disable TypeScript strict mode (`strict: false`) — fix the type errors instead
- Don't add blanket `eslint-disable` comments — fix the lint error or add a targeted disable with a comment explaining why
- Pin tool versions in config files (e.g. `engines` field in `package.json`) to prevent silent breakage
- Don't add `skipLibCheck: true` to tsconfig unless you've documented why (it hides real bugs)
- When changing build config, run a full build locally before committing — CI surprises are expensive
- Keep config files at project root — don't scatter them in subdirectories unless monorepo structure requires it
- Document non-obvious config choices with inline comments
- When upgrading a major config version (e.g. ESLint flat config), update in a single dedicated commit
