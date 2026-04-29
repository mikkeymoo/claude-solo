---
name: api-design
description: "Review API surfaces for REST conventions, consistency, error handling, pagination, and versioning. Use when designing or auditing APIs."
argument-hint: "[--review | --design | --breaking]"
---

# /api-design — API Design Review

Review and design REST APIs with consistent conventions, proper error handling, authentication, and versioning.

Three modes:

- `--review` (default) — audit existing API endpoints for REST compliance, consistency, and quality
- `--design` — design a new API from requirements or description
- `--breaking` — compare two API versions for breaking changes

## --review — API Audit

Systematically audit an existing API for REST compliance and best practices.

### Step 1: Inventory Endpoints

Search the codebase for all route definitions. Look for:

- `routes/`, `api/`, `controllers/` directories
- Files with route patterns: `router.`, `@app.route`, `@router.`, `express.Router`, `FastAPI router`
- Framework-specific patterns:
  - **Express.js**: `app.get()`, `app.post()`, `router.use()`
  - **FastAPI**: `@app.get()`, `@router.post()`, `@app.route()`
  - **Django**: `@app.route()`, `path()`, `re_path()`
  - **Ruby on Rails**: `resources :`, `match`, `get`, `post`
  - **Java Spring**: `@RequestMapping`, `@GetMapping`, `@PostMapping`

List every endpoint with: **method**, **path**, **handler function**, **file:line**.

### Step 2: REST Method Compliance

Verify HTTP methods match REST semantics:

| Method | Semantics                                   | Valid Endpoints                 | Invalid Pattern              |
| ------ | ------------------------------------------- | ------------------------------- | ---------------------------- |
| GET    | Read, safe, idempotent                      | `/users`, `/users/{id}`         | GET `/users` that creates    |
| POST   | Create, may not be idempotent               | `/users`, `/orders/{id}/pay`    | POST `/users/{id}` (use PUT) |
| PUT    | Replace, idempotent, requires full resource | `/users/{id}`, full body        | Partial updates (use PATCH)  |
| PATCH  | Partial update                              | `/users/{id}` with partial body | Replacing whole resource     |
| DELETE | Remove, idempotent                          | `/users/{id}`                   | DELETE `/users` (unbounded)  |
| HEAD   | Like GET, no body                           | `/users`, `/users/{id}`         | HEAD for state-changing ops  |

Issues found:

- 🔴 BREAKING if wrong method used for operation
- 🟡 INCONSISTENCY if related endpoints use different methods

### Step 3: HTTP Status Code Audit

Verify correct status codes for all response paths. Expected codes:

| Code | Use Case                         | Example                                                |
| ---- | -------------------------------- | ------------------------------------------------------ |
| 200  | GET success, PATCH success       | GET /users → 200 OK                                    |
| 201  | POST creates resource            | POST /users → 201 Created + Location header            |
| 204  | DELETE success, no body          | DELETE /users/{id} → 204 No Content                    |
| 400  | Bad request, invalid input       | POST /users with invalid email → 400                   |
| 401  | Not authenticated                | Missing/invalid auth token → 401 Unauthorized          |
| 403  | Authenticated but not authorized | User tries to access other user's data → 403 Forbidden |
| 404  | Resource not found               | GET /users/{id} where id doesn't exist → 404           |
| 422  | Validation error (semantic)      | Email format invalid → 422 Unprocessable Entity        |
| 429  | Rate limit exceeded              | Too many requests → 429 Too Many Requests              |
| 500  | Server error, unexpected         | Database connection fails → 500 Internal Server Error  |

Issues found:

- 🔴 BREAKING if status code contradicts contract (e.g., 200 instead of 201)
- 🟡 INCONSISTENCY if related endpoints return different codes for same scenario

### Step 4: Error Response Shape

All errors should follow a consistent format. Standard shape:

```json
{
  "error": "Human-readable message",
  "code": "OPTIONAL_ERROR_CODE",
  "details": {}
}
```

Examples:

```json
{
  "error": "Invalid email format",
  "code": "VALIDATION_ERROR"
}

{
  "error": "User not found",
  "code": "NOT_FOUND",
  "details": {
    "userId": "user-123"
  }
}
```

Issues found:

- 🔴 BREAKING if error shape changes or code field renamed
- 🟡 INCONSISTENCY if some endpoints return `{ error: "msg" }` and others return `{ message: "msg" }`
- 🟡 INCONSISTENCY if some use `code` field, others don't
- 🟡 INCONSISTENCY if error messages are raw database errors (leak internals)

### Step 5: Pagination Audit

All list endpoints must be bounded (paginated). Check:

- Does endpoint return unbounded arrays?
- Are pagination params present? (`page`, `limit`, `offset`, `cursor`)
- Is there a default limit? (common: 20, 50, 100)
- Is there a max limit enforced? (e.g., max 1000 per request)
- Does response include metadata? (total count, has_more, next_cursor)

Correct pagination response:

```json
{
  "data": [...],
  "pagination": {
    "total": 500,
    "page": 1,
    "limit": 20,
    "has_more": true
  }
}
```

Or cursor-based:

```json
{
  "data": [...],
  "pagination": {
    "cursor": "eyJpZCI6IDEwMH0=",
    "has_more": true
  }
}
```

Issues found:

- 🔴 BREAKING if endpoint returns unbounded array (scalability risk)
- 🟡 INCONSISTENCY if some endpoints paginate, others don't
- 🟡 INCONSISTENCY if pagination param names differ (page vs offset)

### Step 6: Authentication & Authorization

Check every endpoint for auth:

- Is auth middleware applied?
- Are auth checks at route level or in handler?
- Is auth required everywhere it should be?
- Are there public endpoints? (clearly documented)

Pattern:

```typescript
// ✅ Auth middleware applied at route level
app.get("/api/v1/users/:id", authenticateToken, (req, res) => {
  // Auth check already done
});

// ❌ Auth check in handler (easy to forget)
app.get("/api/v1/users/:id", (req, res) => {
  if (!req.headers.authorization) return res.status(401).send();
  // ...
});
```

Issues found:

- 🔴 BREAKING if endpoints lose auth when they should have it
- 🟡 INCONSISTENCY if some endpoints check auth, others don't (when both should)

### Step 7: Versioning & Path Structure

Check API versioning strategy:

| Strategy    | Pattern                                      | Issue                        |
| ----------- | -------------------------------------------- | ---------------------------- |
| URL path    | `/api/v1/users`                              | Clear, standard              |
| Header      | `Accept: application/vnd.api+json;version=1` | Harder to test               |
| Query param | `/api/users?v=1`                             | Non-standard, easy to forget |
| Subdomain   | `v1.api.example.com`                         | Complex infrastructure       |

Issues found:

- 🔴 BREAKING if versioning strategy changes mid-API
- 🟡 INCONSISTENCY if some routes have `/v1/` and others don't
- 🟡 INCONSISTENCY if version not clearly documented

### Output Format

For each issue found, report:

```
🔴 BREAKING — [issue title] (file:line)
Description: Why this matters.
Severity: What breaks if not fixed.
Fix: Concrete solution.

---

🟡 INCONSISTENCY — [issue title] (file:line)
Description: How this differs from pattern.
Examples: Where you see it vs. expected behavior.
Fix: What to standardize on.

---

🔵 SUGGESTION — [issue title] (file:line)
Description: Why this would improve the API.
Rationale: Benefit and tradeoff.
Example: How it would look.
```

## --design — Design New API

Design a new REST API from requirements.

### Step 1: Understand Requirements

Ask clarifying questions if needed:

- What data model(s) will this API expose?
- What are the primary use cases?
- What rate of requests are expected?
- Are there auth requirements?
- What clients will use this API? (web, mobile, internal)

### Step 2: Design Resource Hierarchy

Identify resources and their relationships:

```
/users                        # Collection
/users/{userId}               # Single resource
/users/{userId}/posts         # Related collection
/users/{userId}/posts/{id}    # Related single resource
/orders/{orderId}/items       # Nested for convenience
/orders/{orderId}/items/{id}  # (use when parent-child coupling is strong)
```

Avoid deeply nested paths (>2 levels usually signals design issue).

### Step 3: Design Endpoints

For each resource, define CRUD operations:

```
GET    /api/v1/users           — List users (paginated)
POST   /api/v1/users           — Create user
GET    /api/v1/users/{id}      — Get user
PATCH  /api/v1/users/{id}      — Update user
DELETE /api/v1/users/{id}      — Delete user

GET    /api/v1/users/{id}/posts  — List user's posts
POST   /api/v1/users/{id}/posts  — Create post for user
```

For non-CRUD operations (actions), use POST:

```
POST   /api/v1/users/{id}/activate     — State change
POST   /api/v1/users/{id}/reset-password — Action
POST   /api/v1/orders/{id}/ship         — Action
```

### Step 4: Design Request/Response Bodies

Example request (POST /users):

```json
{
  "email": "user@example.com",
  "name": "John Doe",
  "role": "admin"
}
```

Example response (201 Created):

```json
{
  "id": "user-123",
  "email": "user@example.com",
  "name": "John Doe",
  "role": "admin",
  "created_at": "2024-04-29T10:00:00Z",
  "updated_at": "2024-04-29T10:00:00Z"
}
```

Include:

- Unique ID (uuid or snowflake)
- Timestamps (created_at, updated_at)
- Relevant relationships (foreign keys or references)
- Immutable fields marked in docs

### Step 5: Error Scenarios

Document error responses for each endpoint:

```
POST /api/v1/users

400 Bad Request
{
  "error": "Invalid email format",
  "code": "VALIDATION_ERROR",
  "details": {
    "field": "email",
    "value": "not-an-email"
  }
}

409 Conflict
{
  "error": "Email already registered",
  "code": "EMAIL_EXISTS",
  "details": {
    "email": "user@example.com"
  }
}
```

### Step 6: Authentication & Authorization

Document:

- Auth mechanism (Bearer token, OAuth, API key)
- Which endpoints are public vs. protected
- Required permissions/scopes
- Example auth header: `Authorization: Bearer <token>`

### Step 7: Pagination & Filtering

For list endpoints, document:

```
GET /api/v1/users?page=1&limit=20&role=admin

Response:
{
  "data": [...],
  "pagination": {
    "total": 150,
    "page": 1,
    "limit": 20,
    "pages": 8
  }
}
```

Filters supported? Sorting options?

### Step 8: OpenAPI Specification

Provide OpenAPI/Swagger snippet for key endpoints:

```yaml
openapi: 3.0.0
info:
  title: User API
  version: 1.0.0

paths:
  /api/v1/users:
    get:
      summary: List users
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
      responses:
        "200":
          description: Success
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: "#/components/schemas/User"
                  pagination:
                    $ref: "#/components/schemas/Pagination"

    post:
      summary: Create user
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/CreateUserRequest"
      responses:
        "201":
          description: User created
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/User"
        "400":
          description: Validation error

components:
  schemas:
    User:
      type: object
      properties:
        id:
          type: string
        email:
          type: string
        name:
          type: string
        created_at:
          type: string
          format: date-time

    CreateUserRequest:
      type: object
      required:
        - email
        - name
      properties:
        email:
          type: string
          format: email
        name:
          type: string
```

## --breaking — Breaking Change Analysis

Compare two API versions for breaking changes.

### Approach

Get the old and new API definitions (code, docs, or OpenAPI specs). Compare:

1. **Endpoint removal** — 🔴 BREAKING if endpoint is gone
2. **Method change** — 🔴 BREAKING if GET becomes POST
3. **Path change** — 🔴 BREAKING if `/users/{id}` becomes `/users/{userId}`
4. **Required params** — 🔴 BREAKING if optional param becomes required
5. **Response shape** — 🔴 BREAKING if required field removed or renamed
6. **Status codes** — 🔴 BREAKING if success code changes or new required error code added
7. **Auth requirement** — 🔴 BREAKING if public endpoint becomes private
8. **Pagination** — 🔴 BREAKING if unbounded list becomes paginated

### Output Format

```
## Breaking Changes: v1 → v2

🔴 BREAKING — Endpoint removed: DELETE /api/v1/users/{id}
Clients using this endpoint will fail with 404.
Migration: Use POST /api/v2/users/{id}/archive instead.

🔴 BREAKING — Required field added: POST /api/v2/users
Request body now requires 'role' field (was optional).
Migration: Provide role='user' as default for existing clients.

🔴 BREAKING — Response field removed: GET /api/v2/users/{id}
Field 'legacy_id' no longer present in response.
Migration: Use 'id' instead; legacy_id was deprecated in v1.1.

🟡 DEPRECATION — Status code changed: POST /api/v2/orders
Now returns 202 Accepted instead of 201 Created.
Migration: Treat 202 same as 201; documentation updated.

---

## Non-Breaking Changes

✅ New endpoint added: POST /api/v2/users/{id}/deactivate
✅ New optional parameter: GET /api/v2/users?include_deleted=true
✅ New response field (optional): includes created_by field
```

## SUCCESS CRITERIA

- [ ] Every endpoint is inventoried with method, path, handler location (file:line)
- [ ] Each finding has severity label (🔴 BREAKING / 🟡 INCONSISTENCY / 🔵 SUGGESTION), file:line location, description, and concrete fix
- [ ] Breaking issues listed first, then inconsistencies, then suggestions
- [ ] Error response shapes checked for consistency across all endpoints
- [ ] All list endpoints verified to have pagination with default and max limits documented
- [ ] All endpoints with sensitive operations verified to have auth middleware
- [ ] API versioning strategy verified to be consistent across all routes
- [ ] For --design mode: includes OpenAPI snippet for at least the primary resource
- [ ] For --breaking mode: lists all changes with migration guidance for clients

## SELF-CHECK

Before returning, verify:

- [ ] Every endpoint is covered in the review
- [ ] Each finding has severity label, location, and concrete fix
- [ ] Breaking issues listed first
- [ ] OpenAPI snippet provided (for --design mode)
- [ ] Status codes verified against REST standards
- [ ] Error shapes are consistent
- [ ] Pagination is bounded with documented limits
- [ ] Auth is applied where needed
- [ ] Versioning is consistent

If any FAIL: revise before returning.

## EXAMPLES

### Example 1: --review output (excerpt)

````markdown
## API Audit: User Service

### Inventory

- GET /api/v1/users (src/routes/users.ts:10)
- POST /api/v1/users (src/routes/users.ts:25)
- GET /api/v1/users/{id} (src/routes/users.ts:45)
- PATCH /api/v1/users/{id} (src/routes/users.ts:60)
- DELETE /api/v1/users/{id} (src/routes/users.ts:75)
- GET /api/v1/users/{id}/posts (src/routes/posts.ts:12)

### Findings

🔴 BREAKING — GET /api/v1/users returns unbounded array
File: src/routes/users.ts:15-20
The endpoint returns all users without pagination:

```json
{
  "data": [{ id: 1, name: "Alice" }, { id: 2, name: "Bob" }, ...]
}
```
````

With thousands of users, this will fail. All list endpoints must paginate.

Fix: Add pagination with `page`, `limit` params:

```typescript
app.get("/api/v1/users", async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = Math.min(parseInt(req.query.limit) || 20, 100);
  const offset = (page - 1) * limit;

  const users = await db.query("SELECT * FROM users LIMIT ? OFFSET ?", [
    limit,
    offset,
  ]);
  const total = await db.query("SELECT COUNT(*) FROM users");

  res.json({
    data: users,
    pagination: { total, page, limit },
  });
});
```

---

🟡 INCONSISTENCY — Error responses inconsistent
File: src/routes/users.ts:30, src/routes/posts.ts:50
When email is invalid:

- Line 30 returns: `{ error: "Invalid email" }`
- Line 50 returns: `{ message: "Bad email format", code: "INVALID_EMAIL" }`

Standardize on shape: `{ error, code? }`. Example fix:

```typescript
res.status(400).json({
  error: "Invalid email format",
  code: "VALIDATION_ERROR",
});
```

---

🔵 SUGGESTION — Add OpenAPI documentation
File: root
Generating OpenAPI spec will help clients (web, mobile) auto-generate SDKs.
Consider using express-jsdoc or fastapi's built-in OpenAPI support.

````

### Example 2: --design output (excerpt)

```markdown
## API Design: Order Management Service

### Resource Hierarchy

````

/api/v1/orders # Orders collection
/api/v1/orders/{id} # Single order
/api/v1/orders/{id}/items # Order items
/api/v1/orders/{id}/ship # Ship action

```

### Endpoints

```

GET /api/v1/orders — List orders (paginated)
POST /api/v1/orders — Create order
GET /api/v1/orders/{id} — Get order
PATCH /api/v1/orders/{id} — Update order
DELETE /api/v1/orders/{id} — Cancel order
POST /api/v1/orders/{id}/ship — Ship order (action)

````

### Response Schema

Order resource:

```json
{
  "id": "ord-12345",
  "user_id": "user-999",
  "status": "pending",
  "total": 99.99,
  "items": [
    {
      "id": "item-1",
      "product_id": "prod-456",
      "quantity": 2,
      "price": 49.99
    }
  ],
  "created_at": "2024-04-29T10:00:00Z",
  "updated_at": "2024-04-29T10:05:00Z"
}
````

### Error Scenarios

POST /api/v1/orders with invalid data:

```json
{
  "error": "Order total exceeds maximum",
  "code": "ORDER_TOO_EXPENSIVE",
  "details": {
    "maximum": 1000.0,
    "provided": 1500.0
  }
}
```

### OpenAPI Snippet

[OpenAPI spec provided above...]

```

```
