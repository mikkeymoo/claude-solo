#!/usr/bin/env node

/**
 * Error Handling Reminder Hook
 * Gentle self-assessment for exception handling
 */

const fs = require('fs');
const path = require('path');

const ERROR_HANDLING_PATTERNS = {
  good: [
    /try\s*{\s*[\s\S]+?}\s*catch\s*\([^)]+\)\s*{\s*[\s\S]+?\S[\s\S]+?}/,
    /\.catch\s*\(\s*[^)]+\s*=>\s*{\s*[\s\S]+?\S[\s\S]+?}\s*\)/,
    /\.catch\s*\(\s*function\s*\([^)]*\)\s*{\s*[\s\S]+?\S[\s\S]+?}\s*\)/,
    /if\s*\(\s*error\s*\)\s*{\s*[\s\S]+?}/,
    /throw\s+new\s+Error\s*\(/
  ],
  problematic: [
    /catch\s*\([^)]*\)\s*{\s*}\s*$/m, // Empty catch block
    /catch\s*\([^)]*\)\s*{\s*\/\/\s*TODO/i, // TODO in catch
    /catch\s*\([^)]*\)\s*{\s*console\.log/i, // Only console.log in catch
    /\.catch\s*\(\s*\(\)\s*=>\s*{}\s*\)/, // Empty arrow function catch
    /\/\/\s*@ts-ignore.*error/i, // Ignoring TypeScript errors
    /eslint-disable.*no-unused-vars.*catch/i // Disabling linting for catch
  ]
};

function analyzeErrorHandling(code) {
  const analysis = {
    hasErrorHandling: false,
    goodPractices: [],
    issues: [],
    suggestions: []
  };

  // Check for good error handling patterns
  for (const pattern of ERROR_HANDLING_PATTERNS.good) {
    if (pattern.test(code)) {
      analysis.hasErrorHandling = true;
      analysis.goodPractices.push('Proper error handling detected');
      break;
    }
  }

  // Check for problematic patterns
  for (const pattern of ERROR_HANDLING_PATTERNS.problematic) {
    if (pattern.test(code)) {
      if (pattern.toString().includes('Empty catch')) {
        analysis.issues.push('Empty catch block detected');
        analysis.suggestions.push('Add proper error handling or logging in catch blocks');
      } else if (pattern.toString().includes('TODO')) {
        analysis.issues.push('Unfinished error handling (TODO) detected');
        analysis.suggestions.push('Complete the error handling implementation');
      } else if (pattern.toString().includes('console.log')) {
        analysis.issues.push('Only console.log in catch block');
        analysis.suggestions.push('Consider proper error recovery or re-throwing');
      }
    }
  }

  // Check for async functions without try-catch
  const asyncFunctionPattern = /async\s+function\s+\w+\s*\([^)]*\)\s*{([^}]+)}/g;
  const asyncArrowPattern = /\w+\s*=\s*async\s*\([^)]*\)\s*=>\s*{([^}]+)}/g;

  let asyncMatch;
  while ((asyncMatch = asyncFunctionPattern.exec(code)) !== null) {
    const functionBody = asyncMatch[1];
    if (!functionBody.includes('try') && !functionBody.includes('.catch')) {
      analysis.issues.push('Async function without error handling detected');
      analysis.suggestions.push('Add try-catch blocks to async functions');
    }
  }

  // Check for Promise chains without catch
  const promisePattern = /\.\s*then\s*\([^)]+\)(?!\s*\.\s*catch)/g;
  if (promisePattern.test(code)) {
    analysis.issues.push('Promise chain without .catch() detected');
    analysis.suggestions.push('Add .catch() to handle Promise rejections');
  }

  // Check for unchecked array access
  const arrayAccessPattern = /\w+\[\d+\](?!\s*\?\.)(?!\s*&&)/g;
  if (arrayAccessPattern.test(code)) {
    analysis.suggestions.push('Consider checking array bounds before accessing elements');
  }

  // Check for unchecked object property access
  const deepPropertyPattern = /\w+\.\w+\.\w+(?!\s*\?\.)(?!\s*&&)/g;
  if (deepPropertyPattern.test(code)) {
    analysis.suggestions.push('Consider using optional chaining (?.) for deep property access');
  }

  return analysis;
}

function generateReminder(analysis) {
  if (analysis.issues.length === 0 && analysis.goodPractices.length > 0) {
    return null; // Good error handling, no reminder needed
  }

  let reminder = '\n\n💭 **Error Handling Self-Check**\n';

  if (analysis.issues.length > 0) {
    reminder += '\nPotential issues:\n';
    analysis.issues.forEach(issue => {
      reminder += `• ${issue}\n`;
    });
  }

  if (analysis.suggestions.length > 0) {
    reminder += '\nConsider:\n';
    analysis.suggestions.forEach(suggestion => {
      reminder += `• ${suggestion}\n`;
    });
  }

  reminder += '\n*Remember: Robust error handling improves code reliability and debugging.*';

  return reminder;
}

async function extractCode(data) {
  let code = '';

  // Extract code from tool uses
  if (data.tool_uses) {
    for (const toolUse of data.tool_uses) {
      if (toolUse.name === 'Write' && toolUse.input?.content) {
        code += toolUse.input.content + '\n';
      } else if (toolUse.name === 'Edit' && toolUse.input?.new_string) {
        code += toolUse.input.new_string + '\n';
      }
    }
  }

  // Extract code blocks from response for all languages
  const codeBlockPattern = /```(?:javascript|typescript|js|ts|jsx|tsx|python|py|powershell|ps1|sql|java|csharp|cs|go|rust|php|ruby|swift|kotlin|bash|sh)\n([\s\S]+?)\n```/g;
  let match;
  while ((match = codeBlockPattern.exec(data.response || '')) !== null) {
    code += match[1] + '\n';
  }

  return code;
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
      const code = await extractCode(data);

      if (code) {
        const analysis = analyzeErrorHandling(code);
        const reminder = generateReminder(analysis);

        if (reminder) {
          // Add gentle reminder
          console.log(JSON.stringify({
            ...data,
            response: (data.response || '') + reminder,
            metadata: {
              ...data.metadata,
              errorHandlingAnalysis: {
                hasIssues: analysis.issues.length > 0,
                issueCount: analysis.issues.length,
                suggestionCount: analysis.suggestions.length
              }
            }
          }));
        } else {
          // Good error handling detected
          console.log(JSON.stringify({
            ...data,
            metadata: {
              ...data.metadata,
              errorHandlingAnalysis: {
                status: 'good',
                message: 'Proper error handling detected'
              }
            }
          }));
        }
      } else {
        // No code to analyze, pass through
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

module.exports = { analyzeErrorHandling };