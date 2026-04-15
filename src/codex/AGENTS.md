<!-- claude-solo-codex:start -->
## claude-solo Codex Compatibility

This project supports the same /mm workflow in Codex using generated skills.

Command routing (20 skills):

Sprint pipeline:
- `/mm:brief` -> use `$mm-brief`
- `/mm:plan` -> use `$mm-plan`
- `/mm:build` -> use `$mm-build`
- `/mm:review` -> use `$mm-review`
- `/mm:test` -> use `$mm-test`
- `/mm:verify` -> use `$mm-verify`
- `/mm:ship` -> use `$mm-ship`
- `/mm:retro` -> use `$mm-retro`

Power skills:
- `/mm:troubleshoot` -> use `$mm-troubleshoot`
- `/mm:workflow` -> use `$mm-workflow`
- `/mm:session` -> use `$mm-session`
- `/mm:doctor` -> use `$mm-doctor`
- `/mm:search` -> use `$mm-search`
- `/mm:cleanup` -> use `$mm-cleanup`

Specialized:
- `/mm:security` -> use `$mm-security`
- `/mm:quality` -> use `$mm-quality`
- `/mm:release` -> use `$mm-release`
- `/mm:docs` -> use `$mm-docs`
- `/mm:scaffold` -> use `$mm-scaffold`
- `/mm:config` -> use `$mm-config`

Legacy aliases (map old commands to new skills):
- `/mm:handoff` -> use `$mm-session` (save mode)
- `/mm:resume` -> use `$mm-session` (restore mode)
- `/mm:pause` -> use `$mm-session` (save --lite mode)
- `/mm:doctor` -> use `$mm-doctor`
- `/mm:deepsearch` -> use `$mm-search`
- `/mm:quick` -> use `$mm-workflow` (--quick mode)
- `/mm:autopilot` -> use `$mm-workflow` (--auto mode)
- `/mm:tdd` -> use `$mm-workflow` (--tdd mode)
- `/mm:security` -> use `$mm-security`
- `/mm:deps` -> use `$mm-quality` (--deps mode)
- `/mm:a11y` -> use `$mm-quality` (--a11y mode)
- `/mm:migrate` -> use `$mm-quality` (--migrate mode)
- `/mm:changelog` -> use `$mm-release`
- `/mm:pr` -> use `$mm-release`
- `/mm:docsync` -> use `$mm-docs` (sync mode)
- `/mm:incident` -> use `$mm-troubleshoot`

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
