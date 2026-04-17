#!/usr/bin/env bash
# validate-readonly-query.sh — PreToolUse guard scoped to the `db-reader` subagent.
#
# Purpose: db-reader is a read-only database subagent. It has Bash only; this script
# rejects ANY write SQL so the agent physically cannot mutate the database even if the
# prompt coerces it.
#
# Install to: ~/.claude/hooks/validate-readonly-query.sh  (or reference via $CLAUDE_PROJECT_DIR)
# Register it as a subagent-scoped hook (agents/db-reader.md has a `hooks:` block) OR
# as a top-level PreToolUse with matcher "Bash" and `if`-gate on agent_type=="db-reader".
#
# Emits the canonical PreToolUse deny JSON on any write keyword.

set -euo pipefail

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // ""' <<<"$INPUT")
AGENT_TYPE=$(jq -r '.agent_type // ""' <<<"$INPUT")

block() {
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# If this hook is registered globally, skip when not running as db-reader.
# If it is registered only under the agent's frontmatter.hooks, this gate is a no-op.
if [[ -n "$AGENT_TYPE" && "$AGENT_TYPE" != "db-reader" ]]; then
  exit 0
fi

# Quick passes — empty or whitespace-only commands
[[ -z "${CMD// /}" ]] && exit 0

# Normalize to uppercase for keyword detection but keep $CMD for logging
UP=$(echo "$CMD" | tr '[:lower:]' '[:upper:]')

# Explicit write keywords at statement position — not inside quoted strings of a SELECT.
# We err on the side of over-blocking: any of these tokens => deny.
# (Read-only queries with "DELETE" in a column comment are rare; a reviewer can whitelist.)
for KW in \
  "INSERT INTO" "UPDATE " "DELETE FROM" "MERGE INTO" "UPSERT " "REPLACE INTO" \
  "DROP " "TRUNCATE " "ALTER " "CREATE " "RENAME " \
  "GRANT " "REVOKE " \
  "LOCK TABLE" "VACUUM" "REINDEX" "CLUSTER " "ANALYZE " \
  "COPY " "\\COPY" "BULK INSERT" "LOAD DATA" \
  "BEGIN;" "START TRANSACTION" "COMMIT;" "ROLLBACK;" \
  "SET SESSION" "SET LOCAL" \
  "CALL " "EXEC " "EXECUTE "
do
  if echo " $UP " | grep -Fq " $KW"; then
    block "db-reader is read-only: keyword '$(echo "$KW" | xargs)' is not permitted"
  fi
done

# Shell-level write redirection to a SQL file
if echo "$CMD" | grep -Eq '(>|>>|tee)\s+[^|]+\.sql($|\s)'; then
  block "db-reader cannot write SQL files"
fi

# Disallow mysql/psql/sqlite3 invocations that take a --file or -f input (could be a write)
if echo "$CMD" | grep -Eq '^\s*(psql|mysql|sqlite3|mssql-cli|sqlcmd)\b.*(\s-f\s|\s--file\s|\s--execute\s|\s-c\s["\x27]+.*(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|TRUNCATE))'; then
  block "db-reader may only run SELECT-only queries via -c/--command"
fi

# Require that any -c/--command content starts with SELECT, WITH, EXPLAIN, SHOW, DESCRIBE, or \d
if echo "$CMD" | grep -Eq '^\s*(psql|mysql|sqlite3|mssql-cli|sqlcmd)\b'; then
  # Extract the inline query (best-effort)
  Q=$(echo "$CMD" | grep -oE '(-c|--command|--execute)\s+"[^"]+"' | head -1 | sed -E 's/^(-c|--command|--execute)\s+"//; s/"$//')
  if [[ -n "$Q" ]]; then
    FIRST=$(echo "$Q" | sed -E 's/^\s+//' | awk '{print toupper($1)}')
    case "$FIRST" in
      SELECT|WITH|EXPLAIN|SHOW|DESCRIBE|DESC|\\D|\\DT|\\L|\\D+|USE) ;;
      *) block "db-reader only permits SELECT/WITH/EXPLAIN/SHOW/DESCRIBE. Got: $FIRST" ;;
    esac
  fi
fi

exit 0
