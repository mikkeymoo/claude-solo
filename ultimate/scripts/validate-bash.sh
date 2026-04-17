#!/usr/bin/env bash
# validate-bash.sh — PreToolUse guard for Bash / Write / Edit / MultiEdit.
#
# Install to: ~/.claude/hooks/validate-bash.sh  (or keep in-repo and reference via $CLAUDE_PROJECT_DIR)
# Requires:   jq
#
# Emits the canonical Claude Code PreToolUse decision JSON:
#   {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#     "permissionDecision":"deny","permissionDecisionReason":"..."}}
# Exit 0 always; the JSON is the block mechanism. Exit 2 would also block but is coarser.
# PreToolUse "deny" from a hook cannot be overridden by --dangerously-skip-permissions.

set -euo pipefail

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // ""' <<<"$INPUT")
CMD=$(jq -r '.tool_input.command // ""' <<<"$INPUT")
FILE=$(jq -r '.tool_input.file_path // ""' <<<"$INPUT")

# Accumulate the relevant text to scan so we can write one set of patterns.
SCAN="$CMD"
[[ -n "$FILE" ]] && SCAN="$SCAN
$FILE"

block() {
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# ----------------------------------------------------------------------------
# Filesystem-destroying commands
# ----------------------------------------------------------------------------
# rm -rf / rm -fr / --recursive --force (both flags together = no prompts, no mercy)
# Plain `rm -r` is allowed — it still prompts on non-empty dirs.
if echo "$CMD" | grep -Eq '(^|[;&|`(]|&&|\|\|)\s*(sudo\s+)?rm\s+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*)'; then
  block "rm -rf pattern blocked — destructive and rarely recoverable"
fi
if echo "$CMD" | grep -Eq '(^|[;&|`(]|&&|\|\|)\s*(sudo\s+)?rm\s+(--recursive\s+--force|--force\s+--recursive)'; then
  block "rm --recursive --force blocked — destructive and rarely recoverable"
fi

# Wipe-home / wipe-root targets even without -rf
if echo "$CMD" | grep -Eq 'rm\s.*(\s|^)(/|~|\$HOME|/\*|\.\s*$)(\s|$)'; then
  block "rm targeting root/home blocked"
fi

# dd writing to a block device
echo "$CMD" | grep -Eq '\bdd\s+.*of=/dev/' && block "dd writing to /dev blocked"

# mkfs / format / fdisk / chmod -R 777 /
echo "$CMD" | grep -Eq '\b(mkfs\.|fdisk\s|parted\s)' && block "low-level disk tool blocked"
echo "$CMD" | grep -Eq 'chmod\s+-R\s+777\s+/' && block "chmod -R 777 on root blocked"

# Fork bomb
echo "$CMD" | grep -Fq ':(){ :|:& };:' && block "fork bomb blocked"

# curl | bash / wget | sh — pipe-to-shell remote execution
echo "$CMD" | grep -Eq '(curl|wget|fetch)\s[^|]*\|\s*(bash|sh|zsh|fish|python|node|ruby|pwsh|powershell)' \
  && block "pipe-to-shell from remote URL blocked — download and inspect first"

# ----------------------------------------------------------------------------
# Destructive SQL (whether run via psql, mysql, sqlite3, or ad-hoc pipes)
# ----------------------------------------------------------------------------
if echo "$CMD" | grep -Eiq 'DROP\s+(TABLE|DATABASE|SCHEMA|INDEX|USER|ROLE)'; then
  block "DROP statement blocked — run the migration flow instead"
fi
if echo "$CMD" | grep -Eiq 'TRUNCATE\s+TABLE'; then
  block "TRUNCATE blocked — use a WHERE-scoped DELETE or migration"
fi
# DELETE FROM <table>; without WHERE — unbounded wipe
if echo "$CMD" | grep -Eiq 'DELETE\s+FROM\s+[A-Za-z_."`]+\s*(;|$)' \
   && ! echo "$CMD" | grep -Eiq 'WHERE'; then
  block "DELETE FROM without WHERE blocked — would wipe the table"
fi
# UPDATE <table> SET ... without WHERE
if echo "$CMD" | grep -Eiq 'UPDATE\s+[A-Za-z_."`]+\s+SET\s[^;]*(;|$)' \
   && ! echo "$CMD" | grep -Eiq 'WHERE'; then
  block "UPDATE without WHERE blocked — would overwrite every row"
fi

# ----------------------------------------------------------------------------
# Git safety: force-push to protected branches, hard reset of published work
# ----------------------------------------------------------------------------
if echo "$CMD" | grep -Eq 'git\s+push(\s+--force(-with-lease)?|\s+-f)\s+.*\b(main|master|prod|production|release)\b'; then
  # --force-with-lease is safer but still denied on protected names to prevent accidents.
  block "git push --force to protected branch blocked"
fi
if echo "$CMD" | grep -Eq 'git\s+push\s+.*\s(\+[A-Za-z0-9_./-]+:(main|master|prod|release))\b'; then
  block "git push refspec force-update to protected branch blocked"
fi

# ----------------------------------------------------------------------------
# Secret / env file writes — applies to Bash redirects AND Edit/Write/MultiEdit file_path.
# ----------------------------------------------------------------------------
# Command writing to .env via redirect, tee, mv, cp, sed -i
if echo "$CMD" | grep -Eq '(>|>>)\s*[^|]*(^|/)\.env(\.[a-zA-Z0-9_-]+)?($|\s)'; then
  block ".env write via shell redirect blocked"
fi
if echo "$CMD" | grep -Eq '\btee\s+[^|]*(^|/)\.env'; then
  block ".env write via tee blocked"
fi
if echo "$CMD" | grep -Eq '\bsed\s+.*-i.*(^|/)\.env'; then
  block ".env in-place edit via sed blocked"
fi

# Edit/Write/MultiEdit targeting a .env or secret file
if [[ -n "$FILE" ]]; then
  case "$FILE" in
    *.env|*.env.*|*/.env|*/.env.*|*/secrets/*|*/credentials*|*/.aws/credentials|*/.ssh/id_*|*/*.pem|*/*.p12|*/service-account*.json)
      block "edit of secrets/credentials file blocked: $FILE"
      ;;
  esac
fi

# Prevent writing history-rewriting git scripts into .git/hooks silently
if [[ "$FILE" == *"/.git/hooks/"* ]]; then
  block "direct write to .git/hooks blocked — use pre-commit config instead"
fi

# ----------------------------------------------------------------------------
# Package-publish ops require human confirmation (no automated publishes)
# ----------------------------------------------------------------------------
if echo "$CMD" | grep -Eq '^\s*(sudo\s+)?(npm|pnpm|yarn|bun)\s+publish(\s|$)'; then
  block "package publish blocked — run from a shell with human confirmation"
fi
if echo "$CMD" | grep -Eq '^\s*cargo\s+publish(\s|$)'; then
  block "cargo publish blocked"
fi
if echo "$CMD" | grep -Eq '^\s*(gem\s+push|twine\s+upload)'; then
  block "package upload blocked"
fi

# All clear — no decision JSON = allow per default permission flow.
exit 0
