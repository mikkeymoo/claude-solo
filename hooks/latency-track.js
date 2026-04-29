#!/usr/bin/env node
/**
 * claude-solo latency tracking hook
 *
 * Runs after Claude executes any tool. Tracks tool execution times per session,
 * logs slow tool warnings, and outputs periodic performance summaries.
 *
 * Input (stdin): JSON { tool_name, tool_input, tool_response, start_time_ms }
 *
 * State: ~/.claude/logs/latency-state.json tracks last_tool_start for duration calculation
 * Log: ~/.claude/logs/latency-{date}.json stores { date, sessions: { [session_id]: { [tool_name]: [duration_ms, ...] } } }
 */

import { createInterface } from "readline";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "fs";
import { join } from "path";
import os from "os";

const LOG_DIR = join(os.homedir(), ".claude", "logs");
const DATE_STR = new Date().toISOString().slice(0, 10);
const LATENCY_FILE = join(LOG_DIR, `latency-${DATE_STR}.json`);
const STATE_FILE = join(LOG_DIR, "latency-state.json");

// Get or generate session ID
function getSessionId() {
  const envId = process.env.CLAUDE_SESSION_ID;
  if (envId) return envId;

  // Fallback: generate from date + hour (resets every hour)
  const now = new Date();
  const dateHour = now.toISOString().slice(0, 13); // YYYY-MM-DDTHH
  return dateHour;
}

// Load or initialize latency log
function loadLatencyLog() {
  try {
    if (existsSync(LATENCY_FILE)) {
      return JSON.parse(readFileSync(LATENCY_FILE, "utf8"));
    }
  } catch {
    /* ignore */
  }
  return {
    date: DATE_STR,
    sessions: {},
  };
}

// Save latency log
function saveLatencyLog(log) {
  try {
    mkdirSync(LOG_DIR, { recursive: true });
    writeFileSync(LATENCY_FILE, JSON.stringify(log, null, 2));
  } catch {
    /* not fatal */
  }
}

// Load state (tracks last tool start time)
function loadState() {
  try {
    if (existsSync(STATE_FILE)) {
      return JSON.parse(readFileSync(STATE_FILE, "utf8"));
    }
  } catch {
    /* ignore */
  }
  return {
    last_tool_start: Date.now(),
  };
}

// Save state
function saveState(state) {
  try {
    mkdirSync(LOG_DIR, { recursive: true });
    writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
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

  const { tool_name } = input;
  const now = Date.now();
  const sessionId = getSessionId();

  // Calculate duration from last tool call
  const state = loadState();
  const duration = Math.max(0, now - state.last_tool_start);
  state.last_tool_start = now;
  saveState(state);

  // ── Latency tracking ───────────────────────────────────────────────────
  const log = loadLatencyLog();

  if (!log.sessions[sessionId]) {
    log.sessions[sessionId] = {};
  }

  if (!log.sessions[sessionId][tool_name]) {
    log.sessions[sessionId][tool_name] = [];
  }

  log.sessions[sessionId][tool_name].push(duration);
  saveLatencyLog(log);

  // ── Slow tool warning (> 30s) ──────────────────────────────────────────
  if (duration > 30000) {
    const durationSec = (duration / 1000).toFixed(1);
    process.stderr.write(
      `⚠️  claude-solo: Slow tool detected — ${tool_name} took ${durationSec}s\n`,
    );
  }

  // ── Performance summary every 25 calls ─────────────────────────────────
  const allTools = Object.values(log.sessions[sessionId] || {});
  const totalCalls = allTools.reduce((sum, times) => sum + times.length, 0);

  if (totalCalls > 0 && totalCalls % 25 === 0) {
    // Find slowest tool
    let topSlowTool = "unknown";
    let topAvgMs = 0;

    for (const [name, times] of Object.entries(log.sessions[sessionId] || {})) {
      const avg = times.reduce((a, b) => a + b, 0) / times.length;
      if (avg > topAvgMs) {
        topAvgMs = avg;
        topSlowTool = name;
      }
    }

    const topAvgMsRounded = Math.round(topAvgMs);
    process.stderr.write(
      `📊 claude-solo perf: ${topSlowTool} avg ${topAvgMsRounded}ms | ${totalCalls} calls this session\n`,
    );
  }

  // Always exit cleanly
  process.exit(0);
});
