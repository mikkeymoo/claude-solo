#!/usr/bin/env bash
# claude-solo PreToolUse hook: auto-rewrite Bash commands through rtk
# (Rust Token Killer) so its output filters apply with no manual prefixing.
#
# Why this exists: `rtk init -g` refuses to wire its own hook on native Windows
# ("Hook install requires Unix"). But Claude Code runs Bash tool calls AND hooks
# through Git Bash on Windows, so a shell hook works fine here. This is that hook
# — cross-platform, using rtk's documented `rtk rewrite` interface
# (https://github.com/rtk-ai/rtk: `REWRITTEN=$(rtk rewrite "$CMD") || exit 0`).
#
# Contract (verified against Claude Code hook docs):
#   stdin  : {"tool_name":"Bash","tool_input":{"command":"git status"}, ...}
#   stdout : {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#                                   "updatedInput":{"command":"rtk git status"}}}
#   exit 0 + no stdout = pass the command through unchanged.
#
# Fail-safe by design: ANY uncertainty -> exit 0 (run the original command).
# Never blocks, never errors out a command.

set -uo pipefail

# Need rtk and jq; without either, do nothing.
command -v rtk >/dev/null 2>&1 || exit 0
command -v jq  >/dev/null 2>&1 || exit 0

input="$(cat)" || exit 0
[[ -z "$input" ]] && exit 0

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)" || exit 0
[[ -z "$cmd" ]] && exit 0

# Already routed through rtk — leave it alone (prevents `rtk rtk ...`).
[[ "$cmd" == rtk\ * || "$cmd" == "rtk" ]] && exit 0

# Only rewrite SIMPLE commands. rtk's rewrite naively prepends `rtk` to the whole
# string, which mangles pipes/redirects/chains (e.g. `rtk curl x | bash`). Skip
# anything with shell metacharacters; correctness over coverage.
case "$cmd" in
  *'|'* | *'&'* | *';'* | *'>'* | *'<'* | *'`'* | *'$('* | *$'\n'*) exit 0 ;;
esac

# rtk rewrite: prints the rtk-equivalent and exits 0 if supported; exits 1 with
# no output if the command has no rtk filter.
rewritten="$(rtk rewrite "$cmd" 2>/dev/null)" || exit 0
[[ -z "$rewritten" || "$rewritten" == "$cmd" ]] && exit 0

jq -cn --arg cmd "$rewritten" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    updatedInput: { command: $cmd }
  }
}'
exit 0
