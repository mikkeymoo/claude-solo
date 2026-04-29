#!/usr/bin/env node
/**
 * claude-solo large-file detection hook (PreToolUse)
 *
 * Warns when Write tool is used to write large files (>500 lines or >50KB).
 * Advisory only — never blocks the write.
 *
 * Input (stdin): JSON { tool_name, tool_input }
 * Output (stdout): { action: 'continue' }
 */

import { createInterface } from "readline";

const rl = createInterface({ input: process.stdin });
let raw = "";
rl.on("line", (line) => (raw += line));

rl.on("close", () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  const { tool_name, tool_input } = input;

  if (tool_name === "Write") {
    const content = tool_input?.content || "";
    const filePath = tool_input?.file_path || "";

    // Count lines and bytes
    const lineCount = content.split("\n").length - 1; // -1 because last empty split
    const sizeBytes = Buffer.byteLength(content, "utf8");
    const sizeKB = Math.round(sizeBytes / 1024);

    // Warn if >500 lines OR >50KB
    if (lineCount > 500 || sizeBytes > 50000) {
      process.stderr.write(
        `⚠️  claude-solo: Large file write detected — ${lineCount} lines, ${sizeKB}KB. Consider splitting into smaller files.\n`,
      );
    }
  }

  process.stdout.write(JSON.stringify({ action: "continue" }));
});
