<!-- claude-solo-codex:start -->
## claude-solo Codex Compatibility

This project supports the same /mm workflow in Codex using generated skills.

Command routing:
- `/mm:adversarial` -> use `$mm-adversarial`
- `/mm:aislopcleaner` -> use `$mm-aislopcleaner`
- `/mm:autopilot` -> use `$mm-autopilot`
- `/mm:brief` -> use `$mm-brief`
- `/mm:build` -> use `$mm-build`
- `/mm:changelog` -> use `$mm-changelog`
- `/mm:ci` -> use `$mm-ci`
- `/mm:compliance` -> use `$mm-compliance`
- `/mm:deepsearch` -> use `$mm-deepsearch`
- `/mm:distill` -> use `$mm-distill`
- `/mm:docsync` -> use `$mm-docsync`
- `/mm:doctor` -> use `$mm-doctor`
- `/mm:estimate` -> use `$mm-estimate`
- `/mm:explain` -> use `$mm-explain`
- `/mm:handoff` -> use `$mm-handoff`
- `/mm:incident` -> use `$mm-incident`
- `/mm:parallel` -> use `$mm-parallel`
- `/mm:pause` -> use `$mm-pause`
- `/mm:plan` -> use `$mm-plan`
- `/mm:pr` -> use `$mm-pr`
- `/mm:quick` -> use `$mm-quick`
- `/mm:ready` -> use `$mm-ready`
- `/mm:release` -> use `$mm-release`
- `/mm:resume` -> use `$mm-resume`
- `/mm:retro` -> use `$mm-retro`
- `/mm:review` -> use `$mm-review`
- `/mm:security` -> use `$mm-security`
- `/mm:ship` -> use `$mm-ship`
- `/mm:tdd` -> use `$mm-tdd`
- `/mm:test` -> use `$mm-test`
- `/mm:tokens` -> use `$mm-tokens`
- `/mm:update` -> use `$mm-update`
- `/mm:verify` -> use `$mm-verify`

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
