#!/usr/bin/env node
/**
 * claude-solo post-tool-use hook
 *
 * Runs after Claude executes any tool. Tracks estimated token usage,
 * logs commands, and surfaces RTK hints when raw commands are run.
 *
 * Input (stdin): JSON { tool_name, tool_input, tool_response }
 */

import { createInterface } from "readline";
import {
  appendFileSync,
  readFileSync,
  writeFileSync,
  mkdirSync,
  existsSync,
} from "fs";
import { join } from "path";
import os from "os";

const LOG_DIR = join(os.homedir(), ".claude", "logs");
const DATE_STR = new Date().toISOString().slice(0, 10);
const LOG_FILE = join(LOG_DIR, `session-${DATE_STR}.log`);
const TOKEN_FILE = join(LOG_DIR, `tokens-${DATE_STR}.json`);

// Rough token estimator: ~4 chars per token (good enough for logging)
function estimateTokens(value) {
  if (!value) return 0;
  const str = typeof value === "string" ? value : JSON.stringify(value);
  return Math.ceil(str.length / 4);
}

function loadTokenStats() {
  try {
    if (existsSync(TOKEN_FILE)) {
      return JSON.parse(readFileSync(TOKEN_FILE, "utf8"));
    }
  } catch {
    /* ignore */
  }
  return {
    date: DATE_STR,
    calls: 0,
    input_tokens: 0,
    output_tokens: 0,
    total_tokens: 0,
    by_tool: {},
  };
}

function saveTokenStats(stats) {
  try {
    mkdirSync(LOG_DIR, { recursive: true });
    writeFileSync(TOKEN_FILE, JSON.stringify(stats, null, 2));
  } catch {
    /* not fatal */
  }
}

const rl = createInterface({ input: process.stdin });
let raw = "";
rl.on("line", (line) => (raw += line));

rl.on("close", () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    return;
  }

  const { tool_name, tool_input, tool_response } = input;
  const timestamp = new Date().toISOString();

  // ── Token tracking (all tools) ──────────────────────────────────────────
  const inputTokens = estimateTokens(tool_input);
  const outputTokens = estimateTokens(tool_response);
  const totalTokens = inputTokens + outputTokens;

  const stats = loadTokenStats();
  stats.calls++;
  stats.input_tokens += inputTokens;
  stats.output_tokens += outputTokens;
  stats.total_tokens += totalTokens;

  if (!stats.by_tool[tool_name]) {
    stats.by_tool[tool_name] = {
      calls: 0,
      input_tokens: 0,
      output_tokens: 0,
      total_tokens: 0,
    };
  }
  stats.by_tool[tool_name].calls++;
  stats.by_tool[tool_name].input_tokens += inputTokens;
  stats.by_tool[tool_name].output_tokens += outputTokens;
  stats.by_tool[tool_name].total_tokens += totalTokens;

  saveTokenStats(stats);

  // ── Bash: command log ───────────────────────────────────────────────────
  if (tool_name === "Bash" && tool_input?.command) {
    const cmd = tool_input.command;
    try {
      mkdirSync(LOG_DIR, { recursive: true });
      appendFileSync(
        LOG_FILE,
        `[${timestamp}] Bash (~${totalTokens}tok): ${cmd.slice(0, 200)}\n`,
      );
    } catch {
      /* not fatal */
    }
  }

  // ── Session summary to stderr every 50 calls ────────────────────────────
  if (stats.calls % 50 === 0) {
    const k = (n) => (n >= 1000 ? `${(n / 1000).toFixed(1)}k` : String(n));
    process.stderr.write(
      `\n📊 claude-solo tokens today: ${k(stats.total_tokens)} est. (~${k(stats.input_tokens)} in / ~${k(stats.output_tokens)} out) across ${stats.calls} tool calls\n`,
    );
  }
});
