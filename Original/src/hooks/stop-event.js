#!/usr/bin/env node

/**
 * Stop Event Hook
 * Runs after Claude responds, checking for risky patterns and potential issues
 */

const fs = require('fs');
const path = require('path');

const RISKY_PATTERNS = [
  // File operations
  { pattern: /rm\s+-rf\s+\//, risk: 'HIGH', message: 'Dangerous recursive deletion detected' },
  { pattern: /sudo\s+rm/, risk: 'HIGH', message: 'Sudo deletion command detected' },
  { pattern: />\s*\/dev\/sda/, risk: 'CRITICAL', message: 'Direct disk write detected' },

  // Git operations
  { pattern: /git\s+push\s+--force/, risk: 'MEDIUM', message: 'Force push detected' },
  { pattern: /git\s+reset\s+--hard/, risk: 'MEDIUM', message: 'Hard reset detected' },

  // Database operations
  { pattern: /DROP\s+DATABASE/i, risk: 'HIGH', message: 'Database drop command detected' },
  { pattern: /DELETE\s+FROM\s+\w+\s*;/i, risk: 'HIGH', message: 'Unfiltered DELETE detected' },
  { pattern: /TRUNCATE\s+TABLE/i, risk: 'MEDIUM', message: 'Table truncation detected' },

  // Security concerns
  { pattern: /password\s*=\s*["'][^"']+["']/i, risk: 'MEDIUM', message: 'Hardcoded password detected' },
  { pattern: /api[_-]?key\s*=\s*["'][^"']+["']/i, risk: 'MEDIUM', message: 'Hardcoded API key detected' },
  { pattern: /eval\s*\([^)]+\)/, risk: 'MEDIUM', message: 'Eval usage detected' },

  // Exception handling
  { pattern: /catch\s*\([^)]*\)\s*{\s*}/, risk: 'LOW', message: 'Empty catch block detected' },
  { pattern: /catch\s*\([^)]*\)\s*{\s*\/\/\s*TODO/i, risk: 'LOW', message: 'Unimplemented error handling' },

  // Performance concerns
  { pattern: /SELECT\s+\*\s+FROM/i, risk: 'LOW', message: 'SELECT * detected - consider specific columns' },
  { pattern: /for\s*\([^)]+\)\s*{\s*for\s*\([^)]+\)/, risk: 'LOW', message: 'Nested loops detected - check performance' }
];

function checkForRiskyPatterns(response) {
  const issues = [];

  for (const check of RISKY_PATTERNS) {
    if (check.pattern.test(response)) {
      issues.push({
        risk: check.risk,
        message: check.message,
        pattern: check.pattern.toString()
      });
    }
  }

  return issues;
}

function generateWarning(issues) {
  const highRisk = issues.filter(i => i.risk === 'HIGH' || i.risk === 'CRITICAL');
  const mediumRisk = issues.filter(i => i.risk === 'MEDIUM');
  const lowRisk = issues.filter(i => i.risk === 'LOW');

  let warning = '\n\n⚠️ **Code Review Alert**\n';

  if (highRisk.length > 0) {
    warning += '\n🔴 **HIGH RISK PATTERNS DETECTED:**\n';
    highRisk.forEach(issue => {
      warning += `   • ${issue.message}\n`;
    });
  }

  if (mediumRisk.length > 0) {
    warning += '\n🟡 **Medium Risk Patterns:**\n';
    mediumRisk.forEach(issue => {
      warning += `   • ${issue.message}\n`;
    });
  }

  if (lowRisk.length > 0) {
    warning += '\n🟢 **Suggestions:**\n';
    lowRisk.forEach(issue => {
      warning += `   • ${issue.message}\n`;
    });
  }

  warning += '\nPlease review these patterns before execution.';

  return warning;
}

function main() {
  let input = '';

  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => {
    input += chunk;
  });

  process.stdin.on('end', () => {
    try {
      const data = JSON.parse(input);
      const response = data.response || '';

      // Check for risky patterns
      const issues = checkForRiskyPatterns(response);

      if (issues.length > 0) {
        // Log issues to file for tracking
        const logPath = path.join(__dirname, '../logs/risk-detections.log');
        const logDir = path.dirname(logPath);

        if (!fs.existsSync(logDir)) {
          fs.mkdirSync(logDir, { recursive: true });
        }

        const logEntry = {
          timestamp: new Date().toISOString(),
          issues: issues,
          responseSnippet: response.substring(0, 200)
        };

        fs.appendFileSync(logPath, JSON.stringify(logEntry) + '\n');

        // Add warning to response
        const warning = generateWarning(issues);
        console.log(JSON.stringify({
          response: response + warning,
          metadata: {
            risksDetected: issues.length,
            highRiskCount: issues.filter(i => i.risk === 'HIGH' || i.risk === 'CRITICAL').length
          }
        }));
      } else {
        // Pass through unchanged
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

module.exports = { checkForRiskyPatterns };