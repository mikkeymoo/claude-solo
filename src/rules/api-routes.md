# API Route Rules

When writing or modifying API route handlers:

- Validate all user input at the route boundary — never trust request body, params, or headers
- Return consistent error shapes: `{ error: string, code?: string, details?: unknown }`
- Use HTTP status codes correctly: 400 (bad input), 401 (not authenticated), 403 (not authorized), 404 (not found), 422 (validation error), 500 (server error)
- Never return raw database errors or stack traces to clients in production
- Rate-limit mutation endpoints (POST, PUT, PATCH, DELETE) — at minimum note where rate-limiting should go
- Always handle the case where authenticated user is not found in the database (treat as 401, not 500)
- Use pagination for list endpoints — never return unbounded arrays
- Include `Content-Type: application/json` in all JSON responses
- Log request IDs on every request so errors can be correlated with traces
- Never expose internal implementation details (field names, table names, file paths) in error messages
