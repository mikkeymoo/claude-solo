# Environment File Rules

When working with `.env` files or environment configuration:

- Never commit `.env` files with real values — only commit `.env.example` with placeholder values
- Validate all required env vars at application startup, not lazily at call-site
- Use a schema validator (e.g. `zod`, `pydantic`) to parse and type-check env vars at startup
- Group related vars with a shared prefix (e.g. `DB_HOST`, `DB_PORT`, `DB_NAME`)
- Document every variable in `.env.example` with a comment explaining its purpose and format
- Never use `process.env.VAR` directly in deep business logic — inject via config objects
- Treat all env vars as strings until explicitly coerced (booleans are strings in env)
- Rotate secrets immediately if they are accidentally committed — don't just delete and rewrite history
- Use `.env.local` for per-developer overrides, `.env.production` for production values (never commit either)
