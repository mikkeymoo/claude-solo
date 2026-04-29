---
name: test-gen
description: "Generate comprehensive tests for a file, function, or module. Use when you need test coverage for existing code."
argument-hint: "[path/to/file | --unit | --integration | --edge | --snapshot]"
---

# /test-gen — Test Suite Generation

Generate comprehensive test suites for existing code. Four modes:

- `--unit` (default) — pure function tests with isolated inputs/outputs
- `--integration` — API endpoint or database tests
- `--edge` — boundary cases, error paths, security inputs
- `--snapshot` — snapshot/golden file tests for UIs and data transformations

## Workflow

### 1. Analyze

1. Read the target file and understand its public API surface
2. Identify all exported functions, classes, and methods
3. Note any dependencies (external libraries, internal modules)
4. Check for existing tests to avoid duplication
5. Determine the project's test framework from `package.json` scripts or existing test files

### 2. Test Generation Chain

For each testable unit, generate tests covering:

**Happy Path** — the normal case that always works

- Example: `should return user profile when valid ID provided`

**Edge Cases** — boundary conditions

- Empty inputs, null values, max/min values, empty arrays
- Example: `should handle empty string input gracefully`

**Error Paths** — what happens when it fails?

- Missing required inputs, type mismatches, external service failures
- Are errors properly thrown or returned?
- Example: `should throw ValidationError when email is invalid`

**Security** — injection and traversal where applicable

- SQL injection patterns, XSS payloads, path traversal
- Example: `should reject malicious SQL in query parameter`

### 3. Explicit Instructions

**Framework detection**: Generate tests in the same framework already used by the project (detect from `package.json` scripts or existing test files). Don't introduce a new test framework.

**Naming**: Describe behavior, not implementation. Use pattern: `should <behavior> when <condition>`

**Assertions**: Each test has exactly one clear assertion that can fail for exactly one reason.

**Realism**: Use actual data fixtures when possible; avoid magic strings that don't match real usage.

## Mode Details

### --unit (default)

Pure function testing with isolated inputs/outputs.

1. Identify all public functions/methods
2. For each: happy path + edge cases + error handling
3. Mock external dependencies (API calls, database, filesystem)
4. Test each function in isolation

Use when: testing utility functions, validators, formatters, calculators.

### --integration

End-to-end testing through public interfaces: API endpoints, database operations, service methods.

1. Identify API endpoints or service entry points
2. Set up test database/fixtures
3. Make realistic requests through the public interface
4. Verify responses and side effects
5. Clean up after each test

Use when: testing API routes, database queries, multi-step workflows.

### --edge

Boundary and error condition testing.

1. List all edge cases: empty, null, very large, very small, invalid types
2. Test each with realistic error recovery
3. Verify error messages are helpful (not exposing internals)
4. Test rate limits, timeouts, resource exhaustion if applicable
5. Test security inputs (SQL injection, XSS, path traversal, command injection)

Use when: hardening code before production, testing error recovery, security validation.

### --snapshot

Golden file testing for UI components, data transformations, formatted output.

1. Identify outputs that should match a known-good reference (renders, JSON, formatted strings)
2. Generate snapshot files with expected output
3. Tests compare live output to snapshot
4. Review snapshot diffs carefully before committing

Use when: testing React/Vue/Angular renders, data format conversions, report generation.

## SELF-CHECK

Before returning, verify:

- [ ] Each test has exactly one clear assertion that can fail for one reason
- [ ] Tests use the project's existing test framework (not a new one)
- [ ] No test always passes (e.g., `assert True` without condition)
- [ ] Happy path, edge cases, AND error paths are all covered
- [ ] Test names describe behavior: `should <behavior> when <condition>`
- [ ] No test duplicates existing tests (checked via grep)
- [ ] Mocks are used only for external dependencies, not owned code
- [ ] Data fixtures are realistic, not magic strings

If any FAIL: revise before returning.

## SUCCESS CRITERIA

- [ ] Tests are written in the project's existing test framework (vitest, jest, pytest, etc.)
- [ ] Every test has a descriptive name following pattern: `should <behavior> when <condition>`
- [ ] Each test has one clear assertion; if multiple conditions exist, they're in separate tests
- [ ] Happy path tests exist and pass
- [ ] Edge case tests cover: empty/null inputs, boundary values, empty collections
- [ ] Error path tests verify: exceptions thrown, error messages clear, no stack trace exposure
- [ ] Security tests (if applicable) cover: SQL injection, XSS, path traversal patterns
- [ ] No mocks of owned code; external dependencies (HTTP, DB, filesystem) are mocked where appropriate
- [ ] No test always passes; all tests can fail for a specific reason
- [ ] Tests don't duplicate existing test coverage (verified via grep)
- [ ] Test file is in the project's standard test directory (e.g., `__tests__/`, `tests/`, `.test.ts`, `.spec.py`)

## EXAMPLE OUTPUT

For a function `calculateDiscount(price: number, couponCode: string): number`:

```typescript
describe("calculateDiscount", () => {
  // Happy path
  it("should return 10% discount when valid SUMMER10 coupon provided", () => {
    const result = calculateDiscount(100, "SUMMER10");
    expect(result).toBe(90);
  });

  // Edge cases
  it("should return original price when coupon code is empty string", () => {
    const result = calculateDiscount(100, "");
    expect(result).toBe(100);
  });

  it("should handle zero price correctly", () => {
    const result = calculateDiscount(0, "SUMMER10");
    expect(result).toBe(0);
  });

  // Error paths
  it("should throw ValidationError when price is negative", () => {
    expect(() => calculateDiscount(-50, "SUMMER10")).toThrow(ValidationError);
  });

  it("should throw CouponExpiredError when coupon is expired", () => {
    expect(() => calculateDiscount(100, "EXPIRED999")).toThrow(
      CouponExpiredError,
    );
  });
});
```
