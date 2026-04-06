---
name: mm:tokens
description: "Show estimated token usage breakdown for today — total, by tool, and session cost estimate."
---

Show estimated token usage for today's Claude Code session.

Run this:
```bash
node -e "
const fs = require('fs') ; const path = require('path') ; const today = new Date().toISOString().slice(0,10) ; const file = path.join(os.homedir(), '.claude', 'logs', \`tokens-\${today}.json\`) ; const os = require('os') ; if (!fs.existsSync(file)) { console.log('No token data yet for today.') ; process.exit(0) ; }
const s = JSON.parse(fs.readFileSync(file)) ; const k = n => n >= 1000 ? (n/1000).toFixed(1)+'k' : String(n) ; console.log('') ; console.log(\`Token usage for \${s.date}\`) ; console.log(\`  Total:  ~\${k(s.total_tokens)} tokens across \${s.calls} tool calls\`) ; console.log(\`  Input:  ~\${k(s.input_tokens)}\`) ; console.log(\`  Output: ~\${k(s.output_tokens)}\`) ; console.log('') ; console.log('By tool:') ; Object.entries(s.by_tool)
  .sort((a,b) => b[1].total_tokens - a[1].total_tokens)
  .forEach(([tool, t]) => {
    console.log(\`  \${tool.padEnd(35)} \${k(t.total_tokens).padStart(6)} tok  (\${t.calls} calls)\`) ; }) ; console.log('') ; console.log('Note: estimates only (~4 chars/token). Actual API usage may differ.') ; "
```

These are estimates from the post-tool-use hook (tool input + output sizes, ~4 chars/token). They track tool call overhead, not full conversation context. Use them to spot which tools are heaviest, not as exact billing numbers.
