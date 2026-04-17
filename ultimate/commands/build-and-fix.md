# /build-and-fix Command

Executes build process and automatically fixes all errors (when count is manageable).

## Usage
```
/build-and-fix [--max-errors 5] [--auto-commit]
```

## Workflow

### 1. Initial Build
```bash
npm run build
```

### 2. Error Analysis
- Captures all build errors
- Categorizes by type (TypeScript, Module, Syntax, etc.)
- Prioritizes fixes by impact

### 3. Automatic Fixing
If errors ≤ max-errors (default: 5):
1. Apply automated fixes
2. Re-run build to verify
3. Repeat until clean or manual intervention needed

### 4. Manual Intervention
If errors > max-errors or complex issues:
1. Generate detailed error report
2. Provide specific fix instructions
3. Create todo items for each fix

## Error Categories & Fixes

### TypeScript Errors
```typescript
// TS2307: Cannot find module
Fix: npm install @types/package-name

// TS2345: Type mismatch
Fix: Update type definitions

// TS2339: Property does not exist
Fix: Add property to interface
```

### Module Resolution
```javascript
// Cannot resolve path
Fix: Correct import path or install package
```

### Syntax Errors
```javascript
// Unexpected token
Fix: Correct syntax based on context
```

## Options

- `--max-errors [n]`: Maximum errors to auto-fix (default: 5)
- `--auto-commit`: Commit fixes automatically
- `--dry-run`: Show what would be fixed without applying
- `--verbose`: Detailed output of fix process
- `--no-install`: Skip package installations
- `--strict`: Fail if any manual fixes needed

## Example Session

```bash
/build-and-fix

🔨 Running build...
❌ Build failed with 3 errors

📋 Analyzing errors...
- 2 TypeScript errors
- 1 Module resolution error

🔧 Applying fixes...
✅ Fixed: Added missing type definition
✅ Fixed: Corrected import path
✅ Fixed: Installed missing package

🔨 Re-running build...
✅ Build successful!

📊 Summary:
- Errors fixed: 3
- Files modified: 2
- Packages installed: 1
- Build time: 12.3s
```

## Integration with Hooks

Works with:
- `build-checker.js`: Detects build errors
- `build-error-resolver`: Provides fix strategies
- `prettier-formatter.js`: Formats fixed files
- `file-edit-tracker.js`: Logs all modifications

## Advanced Features

### Incremental Fixing
```javascript
// Fix errors one at a time with verification
/build-and-fix --incremental
```

### Pattern-Based Fixes
```javascript
// Apply fix patterns from database
/build-and-fix --use-patterns
```

### Rollback Capability
```javascript
// Create restore point before fixing
/build-and-fix --with-rollback
```

## Configuration

```json
{
  "buildAndFix": {
    "maxAutoFix": 5,
    "autoCommit": false,
    "preserveFormatting": true,
    "backupBeforeFix": true,
    "fixPatterns": "./fix-patterns.json"
  }
}
```

## Best Practices

1. Review auto-fixes before committing
2. Run tests after fixing
3. Keep fix patterns updated
4. Document recurring issues
5. Use --dry-run for critical code

## Troubleshooting

### Build still fails after fixes
- Check for circular dependencies
- Verify node_modules integrity
- Clear TypeScript cache
- Check for configuration issues

### Fixes break other code
- Use --with-rollback option
- Fix incrementally
- Review dependency changes
- Run comprehensive tests