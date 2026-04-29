# Security-Sensitive Code Rules

When working with authentication, authorization, cryptography, or security-sensitive code:

- Never roll your own crypto — use battle-tested libraries (`bcrypt`, `argon2`, `jose`, `cryptography`)
- Hash passwords with a work-factor algorithm (bcrypt, argon2) — never SHA-256/MD5 for passwords
- Use constant-time comparison for secret/token equality checks (prevent timing attacks)
- Never log passwords, tokens, API keys, or PII — even at DEBUG level
- Validate JWTs on every request — check signature, expiry (`exp`), issuer (`iss`), audience (`aud`)
- Apply defense-in-depth: authenticate then authorize separately
- Use parameterized queries or ORM methods — never string-interpolate user input into SQL
- Sanitize HTML output to prevent XSS — never `innerHTML = userContent`
- Set security headers: `Content-Security-Policy`, `X-Content-Type-Options`, `X-Frame-Options`
- Store secrets in environment variables or a secrets manager — never in source code or config files
- Require re-authentication for sensitive operations (password change, payment, account deletion)
