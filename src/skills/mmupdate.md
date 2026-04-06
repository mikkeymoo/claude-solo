---
name: mm:update
description: "Pull the latest version of claude-solo from GitHub and reinstall hooks, skills, agents, and settings."
---

Pull the latest version of claude-solo from GitHub and reinstall.

1. **Find the repo** — check where claude-solo was cloned from:
   ```bash
   cat ~/.claude/.claude-solo-source 2>/dev/null || echo "Source unknown"
   ```
   If unknown, ask: "Where is your claude-solo repo? (full path or GitHub URL)"

2. **Pull latest**:
   ```bash
   cd [repo-path] && rtk git pull origin main
   ```

3. **Reinstall** (use the same scope as original install):
   ```bash
   # Windows:
   .\setup.ps1       # or: .\setup.ps1 --project / --both
   # Linux/WSL:
   bash setup.sh     # or: bash setup.sh --project / --both
   ```

4. **Verify** — list installed skills and agents:
   ```bash
   ls ~/.claude/skills/
   ls ~/.claude/agents/
   ```

5. **Report** — show what changed:
   ```bash
   git log --oneline HEAD@{1}..HEAD
   ```

If the pull fails (conflicts, network error), stop and report the error — don't force anything.

End with: "claude-solo updated to [commit hash]. Restart Claude Code to pick up changes."
