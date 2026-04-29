#!/usr/bin/env bash
# start-cache-proxy.sh — SessionStart hook
# Ensures claude-code-cache-fix proxy is running on localhost:9801.
# Skips gracefully if package is not installed (npm install -g claude-code-cache-fix).
# ANTHROPIC_BASE_URL=http://127.0.0.1:9801 must be set in settings.json env block
# (install.sh does this automatically when it installs the package).
#
# Note: intentionally no set -e — curl/nc failures are expected when proxy is not yet up.
set -uo pipefail

# Locate proxy script via npm global root
NPM_ROOT=$(npm root -g 2>/dev/null || true)
PROXY_SCRIPT="${NPM_ROOT}/claude-code-cache-fix/proxy/server.mjs"

# Skip silently if package not installed
[[ -z "$NPM_ROOT" || ! -f "$PROXY_SCRIPT" ]] && exit 0

# Skip if node not available
command -v node >/dev/null 2>&1 || exit 0

# Check if proxy is already listening on :9801
if curl -s --max-time 1 http://127.0.0.1:9801 >/dev/null 2>&1; then
  exit 0
fi

# Start proxy in background; log to temp dir
LOG="${TMPDIR:-/tmp}/claude-cache-proxy.log"
nohup node "$PROXY_SCRIPT" >>"$LOG" 2>&1 &
PROXY_PID=$!

# Brief pause to let socket bind, then verify
sleep 0.5
if curl -s --max-time 1 http://127.0.0.1:9801 >/dev/null 2>&1; then
  echo "[cache-proxy] started on :9801 (pid ${PROXY_PID})"
else
  echo "[cache-proxy] warning: proxy may not be up yet (pid ${PROXY_PID}) — check ${LOG}"
fi

exit 0
