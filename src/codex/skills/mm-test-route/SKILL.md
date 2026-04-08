---
name: mm-test-route
description: "Claude-solo command skill"
---

# mm-test-route

Claude-solo command skill

## Instructions
# /test-route Command

Tests authenticated backend routes with automatic token management and comprehensive request validation.

## Usage
```
/test-route [method] [endpoint] [--data '{json}'] [--auth-type jwt|oauth|basic]
```

## Features
- Automatic authentication token retrieval
- Support for multiple auth types (JWT, OAuth, Basic)
- Request/response validation
- Performance metrics
- Error simulation
- Batch testing

## Authentication Handling

### JWT Authentication
```javascript
// Automatic token retrieval and refresh
const token = await getJWTToken({
  username: process.env.TEST_USER,
  password: process.env.TEST_PASSWORD
});

headers['Authorization'] = `Bearer ${token}`;
```

### OAuth 2.0
```javascript
// OAuth flow handling
const token = await getOAuthToken({
  clientId: process.env.OAUTH_CLIENT_ID,
  clientSecret: process.env.OAUTH_CLIENT_SECRET,
  scope: 'read write'
});
```

### Keycloak Integration
```javascript
// Keycloak-specific token handling
const keycloakToken = await getKeycloakToken({
  realm: 'my-realm',
  clientId: 'my-client',
  username: 'test-user'
});
```

## Test Examples

### Simple GET Request
```bash
/test-route GET /api/users
```

### POST with Data
```bash
/test-route POST /api/users --data '{"name":"John","email":"john@example.com"}'
```

### Complex Authentication Test
```bash
/test-route GET /api/admin/users --auth-type jwt --role admin
```

### Batch Testing
```bash
/test-route --batch routes.json
```

## Route Test Configuration

```json
{
  "routes": [
    {
      "method": "GET",
      "path": "/api/users",
      "auth": true,
      "expectedStatus": 200,
      "expectedSchema": "./schemas/users.json"
    },
    {
      "method": "POST",
      "path": "/api/users",
      "auth": true,
      "data": {
        "name": "Test User",
        "email": "test@example.com"
      },
      "expectedStatus": 201
    }
  ]
}
```

## Test Script Integration

```javascript
// test-auth-route.js
const axios = require('axios');
const jwt = require('jsonwebtoken');

class RouteTest {
  constructor(config) {
    this.baseURL = config.baseURL || 'http://localhost:3000';
    this.authType = config.authType || 'jwt';
  }

  async getAuthToken() {
    switch (this.authType) {
      case 'jwt':
        return this.getJWTToken();
      case 'oauth':
        return this.getOAuthToken();
      case 'keycloak':
        return this.getKeycloakToken();
      default:
        throw new Error(`Unknown auth type: ${this.authType}`);
    }
  }

  async testRoute(method, path, data = null) {
    const token = await this.getAuthToken();

    const config = {
      method,
      url: `${this.baseURL}${path}`,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    };

    if (data) {
      config.data = data;
    }

    try {
      const response = await axios(config);
      return {
        success: true,
        status: response.status,
        data: response.data,
        headers: response.headers,
        timing: response.timing
      };
    } catch (error) {
      return {
        success: false,
        status: error.response?.status,
        error: error.message,
        data: error.response?.data
      };
    }
  }

  async getJWTToken() {
    const response = await axios.post(`${this.baseURL}/auth/login`, {
      username: process.env.TEST_USER || 'testuser',
      password: process.env.TEST_PASSWORD || 'testpass'
    });
    return response.data.token;
  }

  async getKeycloakToken() {
    const params = new URLSearchParams();
    params.append('grant_type', 'password');
    params.append('client_id', process.env.KEYCLOAK_CLIENT_ID);
    params.append('username', process.env.KEYCLOAK_USER);
    params.append('password', process.env.KEYCLOAK_PASSWORD);

    const response = await axios.post(
      `${process.env.KEYCLOAK_URL}/realms/${process.env.KEYCLOAK_REALM}/protocol/openid-connect/token`,
      params
    );
    return response.data.access_token;
  }
}

// Export for command use
module.exports = RouteTest;
```

## Output Format

```
🔐 Testing Route: GET /api/users
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Authentication: JWT token obtained
📤 Request sent to: http://localhost:3000/api/users
⏱️ Response time: 127ms

📥 Response:
Status: 200 OK
Headers:
  - Content-Type: application/json
  - X-Total-Count: 42

Body:
{
  "users": [...],
  "pagination": {
    "page": 1,
    "total": 42
  }
}

✅ Validation:
- Status code matches expected (200)
- Response schema valid
- Performance within limits (<500ms)

📊 Summary:
- Test: PASSED
- Auth: SUCCESS
- Validation: PASSED
- Performance: GOOD
```

## Advanced Features

### Performance Testing
```bash
/test-route GET /api/users --perf --requests 100 --concurrent 10
```

### Error Simulation
```bash
/test-route GET /api/users --simulate-error 401
```

### Response Validation
```bash
/test-route GET /api/users --validate-schema ./schemas/user.json
```

### Rate Limit Testing
```bash
/test-route GET /api/users --test-rate-limit --requests 100
```

## Integration with CI/CD

```yaml
# .github/workflows/api-test.yml
- name: Test API Routes
  run: |
    npm run test:routes
    /test-route --batch production-routes.json --exit-on-fail
```

## Troubleshooting

### Token Expiry
- Automatic refresh before expiry
- Configurable refresh threshold
- Fallback to re-authentication

### SSL/TLS Issues
```bash
/test-route GET /api/users --ignore-ssl
```

### Debugging
```bash
/test-route GET /api/users --debug --verbose
```
