#!/usr/bin/env node

/**
 * Build Checker Hook
 * Runs TypeScript builds and surfaces errors when count is under 5
 * Automatically suggests fixes for common build errors
 */

const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

const BUILD_COMMANDS = [
  // JavaScript/TypeScript
  { command: 'npm run build', type: 'npm', language: 'javascript' },
  { command: 'yarn build', type: 'yarn', language: 'javascript' },
  { command: 'pnpm build', type: 'pnpm', language: 'javascript' },
  { command: 'tsc --noEmit', type: 'typescript', language: 'typescript' },
  { command: 'npx tsc --noEmit', type: 'typescript-npx', language: 'typescript' },

  // Python
  { command: 'python -m py_compile', type: 'python-compile', language: 'python' },
  { command: 'python setup.py build', type: 'python-setup', language: 'python' },
  { command: 'pyinstaller --onefile', type: 'python-exe', language: 'python' },

  // PowerShell
  { command: 'pwsh -Command "Test-ModuleManifest"', type: 'powershell-module', language: 'powershell' },
  { command: 'pwsh -Command "Invoke-ScriptAnalyzer"', type: 'powershell-analyze', language: 'powershell' },

  // SQL
  { command: 'sqlfluff lint', type: 'sql-lint', language: 'sql' },
  { command: 'sqlfmt check', type: 'sql-format', language: 'sql' }
];

async function findProjectRoot(startPath = process.cwd()) {
  let currentPath = startPath;

  while (currentPath !== path.parse(currentPath).root) {
    // Check for common project indicators
    const indicators = ['package.json', 'tsconfig.json', '.git'];

    for (const indicator of indicators) {
      if (fs.existsSync(path.join(currentPath, indicator))) {
        return currentPath;
      }
    }

    currentPath = path.dirname(currentPath);
  }

  return startPath;
}

async function detectBuildCommand(projectRoot) {
  // Check package.json for build script
  const packageJsonPath = path.join(projectRoot, 'package.json');

  if (fs.existsSync(packageJsonPath)) {
    try {
      const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));

      if (packageJson.scripts && packageJson.scripts.build) {
        // Detect package manager
        if (fs.existsSync(path.join(projectRoot, 'yarn.lock'))) {
          return { command: 'yarn build', type: 'yarn' };
        } else if (fs.existsSync(path.join(projectRoot, 'pnpm-lock.yaml'))) {
          return { command: 'pnpm build', type: 'pnpm' };
        } else {
          return { command: 'npm run build', type: 'npm' };
        }
      }
    } catch (error) {
      // Continue to fallback
    }
  }

  // Check for TypeScript
  if (fs.existsSync(path.join(projectRoot, 'tsconfig.json'))) {
    return { command: 'npx tsc --noEmit', type: 'typescript-npx' };
  }

  return null;
}

function parseBuildErrors(output, buildType) {
  const errors = [];

  // TypeScript error parsing
  if (buildType.includes('typescript')) {
    const tsErrorPattern = /(.+?)\((\d+),(\d+)\): error (TS\d+): (.+)/g;
    let match;

    while ((match = tsErrorPattern.exec(output)) !== null) {
      errors.push({
        file: match[1],
        line: parseInt(match[2]),
        column: parseInt(match[3]),
        code: match[4],
        message: match[5],
        type: 'typescript'
      });
    }
  }

  // ESLint error parsing
  const eslintPattern = /(.+?):(\d+):(\d+)\s+error\s+(.+?)\s+(.+)/g;
  let eslintMatch;

  while ((eslintMatch = eslintPattern.exec(output)) !== null) {
    errors.push({
      file: eslintMatch[1],
      line: parseInt(eslintMatch[2]),
      column: parseInt(eslintMatch[3]),
      message: eslintMatch[4],
      rule: eslintMatch[5],
      type: 'eslint'
    });
  }

  // Generic error parsing as fallback
  if (errors.length === 0) {
    const lines = output.split('\n');
    lines.forEach(line => {
      if (line.toLowerCase().includes('error')) {
        errors.push({
          message: line.trim(),
          type: 'generic'
        });
      }
    });
  }

  return errors;
}

function generateFixSuggestions(errors) {
  const suggestions = [];

  errors.forEach(error => {
    if (error.code === 'TS2307') {
      // Cannot find module
      suggestions.push(`Install missing module: npm install ${error.message.match(/'([^']+)'/)?.[1]}`);
    } else if (error.code === 'TS2345') {
      // Type mismatch
      suggestions.push(`Check type compatibility in ${error.file}:${error.line}`);
    } else if (error.code === 'TS2339') {
      // Property does not exist
      suggestions.push(`Add missing property or check spelling in ${error.file}:${error.line}`);
    } else if (error.code === 'TS1005') {
      // Syntax error
      suggestions.push(`Fix syntax error in ${error.file}:${error.line}`);
    }
  });

  return [...new Set(suggestions)]; // Remove duplicates
}

async function runBuildCheck() {
  try {
    const projectRoot = await findProjectRoot();
    const buildCommand = await detectBuildCommand(projectRoot);

    if (!buildCommand) {
      return {
        success: true,
        message: 'No build configuration detected'
      };
    }

    try {
      const { stdout, stderr } = await execPromise(buildCommand.command, {
        cwd: projectRoot,
        maxBuffer: 1024 * 1024 * 10 // 10MB buffer
      });

      return {
        success: true,
        message: 'Build successful',
        output: stdout
      };
    } catch (error) {
      const output = error.stdout + error.stderr;
      const errors = parseBuildErrors(output, buildCommand.type);

      if (errors.length > 0 && errors.length <= 5) {
        const suggestions = generateFixSuggestions(errors);

        return {
          success: false,
          errorCount: errors.length,
          errors: errors,
          suggestions: suggestions,
          command: buildCommand.command,
          output: output
        };
      }

      return {
        success: false,
        errorCount: errors.length,
        message: errors.length > 5 ? `Too many errors (${errors.length}), fix major issues first` : 'Build failed',
        command: buildCommand.command
      };
    }
  } catch (error) {
    return {
      success: false,
      message: `Build check failed: ${error.message}`
    };
  }
}

async function main() {
  let input = '';

  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => {
    input += chunk;
  });

  process.stdin.on('end', async () => {
    try {
      const data = JSON.parse(input);

      // Check if this response involved code changes
      const hasCodeChanges = data.tool_uses?.some(tool =>
        ['Edit', 'Write'].includes(tool.name)
      );

      // Trigger on code changes or if the prompt mentions build/compile
      const triggerWords = ['build', 'compile', 'tsc'];
      const hasTriggerWord = triggerWords.some(word => data.prompt?.toLowerCase().includes(word));

      if (hasCodeChanges || hasTriggerWord) {
        const buildResult = await runBuildCheck();

        if (!buildResult.success && buildResult.errorCount && buildResult.errorCount <= 5) {
          // Generate error report
          let errorReport = '\n\n📦 **Build Check Results**\n';
          errorReport += `❌ Build failed with ${buildResult.errorCount} error(s)\n\n`;

          buildResult.errors.forEach((error, index) => {
            errorReport += `**Error ${index + 1}:** `;
            if (error.file) {
              errorReport += `${error.file}:${error.line}:${error.column}\n`;
            }
            errorReport += `${error.message}\n`;
            if (error.code) {
              errorReport += `Code: ${error.code}\n`;
            }
            errorReport += '\n';
          });

          if (buildResult.suggestions.length > 0) {
            errorReport += '**Suggested fixes:**\n';
            buildResult.suggestions.forEach(suggestion => {
              errorReport += `• ${suggestion}\n`;
            });
          }

          // Add to response
          console.log(JSON.stringify({
            ...data,
            response: (data.response || '') + errorReport,
            metadata: {
              ...data.metadata,
              buildCheck: {
                success: false,
                errorCount: buildResult.errorCount
              }
            }
          }));
        } else {
          // Pass through with build status in metadata
          console.log(JSON.stringify({
            ...data,
            metadata: {
              ...data.metadata,
              buildCheck: {
                success: buildResult.success,
                message: buildResult.message
              }
            }
          }));
        }
      } else {
        // No code changes, pass through
        console.log(JSON.stringify(data));
      }
    } catch (error) {
      console.error(`Hook error: ${error.message}`);
      console.log(input);
    }
  });
}

if (require.main === module) {
  main();
}

module.exports = { runBuildCheck, parseBuildErrors };