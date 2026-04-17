<!-- claude-solo-codex:start -->
## claude-solo Codex Compatibility

This project supports the same /mm workflow in Codex using generated skills.

Command routing:
- `/mm:brief` -> use `$mm-brief`
- `/mm:build` -> use `$mm-build`
- `/mm:cleanup` -> use `$mm-cleanup`
- `/mm:config` -> use `$mm-config`
- `/mm:docs` -> use `$mm-docs`
- `/mm:doctor` -> use `$mm-doctor`
- `/mm:plan` -> use `$mm-plan`
- `/mm:quality` -> use `$mm-quality`
- `/mm:release` -> use `$mm-release`
- `/mm:retro` -> use `$mm-retro`
- `/mm:review` -> use `$mm-review`
- `/mm:scaffold` -> use `$mm-scaffold`
- `/mm:search` -> use `$mm-search`
- `/mm:security` -> use `$mm-security`
- `/mm:session` -> use `$mm-session`
- `/mm:ship` -> use `$mm-ship`
- `/mm:test` -> use `$mm-test`
- `/mm:troubleshoot` -> use `$mm-troubleshoot`
- `/mm:verify` -> use `$mm-verify`
- `/mm:workflow` -> use `$mm-workflow`

Hook wrappers (Claude-like behavior):
- Session start: `node .codex/hooks/mm-hook.js session-start`
- Prompt submit transform: `node .codex/hooks/mm-hook.js prompt-submit < payload.json`
- Pre tool warning: `node .codex/hooks/mm-hook.js pre-tool-use < payload.json`
- Permission decision: `node .codex/hooks/mm-hook.js permission-request < payload.json`
- Post tool telemetry: `node .codex/hooks/mm-hook.js post-tool-use < payload.json`
- Pre compact checkpoint: `node .codex/hooks/mm-hook.js pre-compact < payload.json`
- Subagent capture: `node .codex/hooks/mm-hook.js subagent-stop < payload.json`
- Session end summary: `node .codex/hooks/mm-hook.js session-end < payload.json`

When a user asks for an `/mm:*` command, run the mapped `$mm-*` skill automatically.
<!-- claude-solo-codex:end -->
