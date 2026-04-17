#!/usr/bin/env bash
# Install claude-solo into both Claude and Codex homes.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$REPO_DIR/setup.sh" "$@"
bash "$REPO_DIR/setup-codex.sh" "$@"

