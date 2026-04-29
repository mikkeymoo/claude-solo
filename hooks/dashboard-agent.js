#!/usr/bin/env node
/**
 * claude-solo MultiAgentObservability hook
 *
 * Fires on SubagentStart, SubagentStop, and PostToolUse events.
 * POSTs event data to a local observability dashboard server at http://localhost:9876.
 * Fire-and-forget with 500ms timeout — never blocks the session.
 *
 * Input (stdin): JSON { type, agent_id, tool_name, timestamp, ... }
 * Output (stdout): JSON {} (always allow)
 */

import { createInterface } from "readline";
import { randomUUID } from "crypto";

const DASHBOARD_URL = "http://localhost:9876/event";
const TIMEOUT_MS = 500;

// Generate a session ID to track this Claude Code session's events
const SESSION_ID = randomUUID().substring(0, 8);

const rl = createInterface({ input: process.stdin });
let raw = "";
rl.on("line", (line) => (raw += line));

rl.on("close", async () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    // Invalid JSON — allow and exit
    process.stdout.write(JSON.stringify({}));
    process.exit(0);
  }

  // Extract relevant event data
  const event = {
    timestamp: new Date().toISOString(),
    session_id: SESSION_ID,
    type: input.type || "Unknown",
    agent_id: input.agent_id || SESSION_ID,
    tool_name: input.tool_name || null,
    tool_status: input.tool_status || null,
  };

  // Fire-and-forget POST with timeout
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);

    const response = await fetch(DASHBOARD_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(event),
      signal: controller.signal,
    });

    clearTimeout(timeout);
  } catch (err) {
    // Silently ignore errors — dashboard may not be running
    // Never block the session for observability
  }

  // Always allow and exit 0
  process.stdout.write(JSON.stringify({}));
  process.exit(0);
});
