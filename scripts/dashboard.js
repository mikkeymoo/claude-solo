#!/usr/bin/env node
/**
 * claude-solo Multi-Agent Observability Dashboard
 *
 * A lightweight Node.js HTTP server + HTML dashboard for observing agent activity
 * across multiple Claude Code sessions.
 *
 * Usage: node ~/.claude/scripts/dashboard.js
 * Then in another terminal, start a Claude session — agent activity streams live.
 * Dashboard available at: http://localhost:9876
 *
 * The dashboard tracks:
 * - Active agents (name, start time, elapsed)
 * - Recent tool calls (last 20 events)
 * - Session metadata
 *
 * Minimal styling: dark background, monospace font, auto-refreshes every 2 seconds.
 */

import http from "http";

const PORT = 9876;

// In-memory state
const state = {
  agents: {}, // { [session_id]: { name, started_at, last_activity } }
  events: [], // Last 20 events
  startTime: new Date().toISOString(),
};

// Parse event from POST body
async function parseJSON(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    req.on("data", (chunk) => (raw += chunk.toString("utf8")));
    req.on("end", () => {
      try {
        resolve(JSON.parse(raw));
      } catch (err) {
        reject(err);
      }
    });
  });
}

// Format milliseconds to human-readable elapsed time
function formatElapsed(ms) {
  if (ms < 1000) return `${Math.round(ms)}ms`;
  if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
  if (ms < 3600000) return `${(ms / 60000).toFixed(1)}m`;
  return `${(ms / 3600000).toFixed(1)}h`;
}

// HTML Dashboard
function renderDashboard() {
  const agents = Object.values(state.agents);
  const agentList = agents
    .map(
      (agent) =>
        `<tr>
      <td>${agent.session_id}</td>
      <td>${agent.started_at}</td>
      <td>${formatElapsed(Date.now() - new Date(agent.started_at).getTime())}</td>
      <td>${agent.last_activity || "-"}</td>
    </tr>`,
    )
    .join("");

  const eventList = state.events
    .slice(-20)
    .reverse()
    .map(
      (evt) =>
        `<tr>
      <td>${new Date(evt.timestamp).toLocaleTimeString()}</td>
      <td>${evt.session_id}</td>
      <td>${evt.type}</td>
      <td>${evt.tool_name || "-"}</td>
    </tr>`,
    )
    .join("");

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>claude-solo Multi-Agent Dashboard</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #0d1117;
      color: #e6edf3;
      font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
      font-size: 12px;
      line-height: 1.6;
      padding: 20px;
    }
    h1 { font-size: 24px; margin-bottom: 20px; color: #58a6ff; }
    h2 { font-size: 16px; margin-top: 30px; margin-bottom: 12px; color: #79c0ff; }
    .container { max-width: 1200px; }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 20px;
      background: #161b22;
      border: 1px solid #30363d;
    }
    th {
      background: #0d1117;
      color: #58a6ff;
      padding: 10px;
      text-align: left;
      border-bottom: 1px solid #30363d;
      font-weight: 600;
    }
    td {
      padding: 8px 10px;
      border-bottom: 1px solid #30363d;
    }
    tr:hover { background: #0d2149; }
    .idle { color: #8b949e; font-style: italic; }
    .stats {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 15px;
      margin-bottom: 30px;
    }
    .stat-box {
      background: #161b22;
      border: 1px solid #30363d;
      padding: 15px;
      border-radius: 4px;
    }
    .stat-label { color: #8b949e; font-size: 11px; text-transform: uppercase; }
    .stat-value { color: #79c0ff; font-size: 18px; margin-top: 5px; font-weight: 600; }
    .refresh-note {
      color: #8b949e;
      font-size: 11px;
      margin-bottom: 20px;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>claude-solo Multi-Agent Dashboard</h1>
    <div class="refresh-note">Auto-refreshes every 2 seconds</div>

    <div class="stats">
      <div class="stat-box">
        <div class="stat-label">Active Agents</div>
        <div class="stat-value">${agents.length}</div>
      </div>
      <div class="stat-box">
        <div class="stat-label">Total Events</div>
        <div class="stat-value">${state.events.length}</div>
      </div>
      <div class="stat-box">
        <div class="stat-label">Server Uptime</div>
        <div class="stat-value">${formatElapsed(Date.now() - new Date(state.startTime).getTime())}</div>
      </div>
    </div>

    <h2>Active Agents</h2>
    ${
      agents.length === 0
        ? `<p class="idle">No agents running</p>`
        : `<table>
      <thead>
        <tr><th>Session ID</th><th>Started</th><th>Elapsed</th><th>Last Activity</th></tr>
      </thead>
      <tbody>
        ${agentList}
      </tbody>
    </table>`
    }

    <h2>Recent Events (Last 20)</h2>
    ${
      state.events.length === 0
        ? `<p class="idle">No events yet</p>`
        : `<table>
      <thead>
        <tr><th>Time</th><th>Session</th><th>Type</th><th>Tool</th></tr>
      </thead>
      <tbody>
        ${eventList}
      </tbody>
    </table>`
    }
  </div>

  <script>
    // Auto-refresh every 2 seconds
    async function refresh() {
      try {
        const response = await fetch('/state');
        const newState = await response.json();
        if (newState) {
          location.reload();
        }
      } catch (err) {
        // Silently ignore errors
      }
    }

    setInterval(refresh, 2000);
  </script>
</body>
</html>`;
}

// Create HTTP server
const server = http.createServer(async (req, res) => {
  try {
    // POST /event - receive event data
    if (req.method === "POST" && req.url === "/event") {
      const event = await parseJSON(req);

      // Track agent
      const sessionId = event.session_id || "unknown";
      if (!state.agents[sessionId]) {
        state.agents[sessionId] = {
          session_id: sessionId,
          started_at: new Date().toISOString(),
        };
      }

      // Update agent last activity
      state.agents[sessionId].last_activity = event.tool_name || event.type;

      // Add event to list (keep last 20)
      state.events.push(event);
      if (state.events.length > 100) {
        state.events.shift();
      }

      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ ok: true }));
      return;
    }

    // GET /state - return JSON state
    if (req.method === "GET" && req.url === "/state") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify(state));
      return;
    }

    // GET / - serve HTML dashboard
    if (req.method === "GET" && req.url === "/") {
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      res.end(renderDashboard());
      return;
    }

    // 404
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Not found" }));
  } catch (err) {
    console.error("Request error:", err);
    res.writeHead(500, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Internal server error" }));
  }
});

server.listen(PORT, "localhost", () => {
  console.log(
    `[dashboard] Listening on http://localhost:${PORT} — start a Claude session to see agent activity`,
  );
});

// Graceful shutdown
process.on("SIGINT", () => {
  console.log("\n[dashboard] Shutting down...");
  server.close();
});
