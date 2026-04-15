---
name: mm-session
description: "Session management — save context, restore, or check token usage. Replaces handoff, pause, and resume in one command."
---

# mm-session

Session management — save context, restore, or check token usage. Replaces handoff, pause, and resume in one command.

## Instructions
Session lifecycle management. Save context before ending a session, restore in a fresh one, or check token burn.

Detect intent from argument or context:
- `save` (or no argument while working) → rich handoff
- `save --lite` → quick pause point
- `restore` → reload from last saved context
- `tokens` → show today's token usage

---

## save — Rich handoff

Write `.planning/HANDOFF.md` with:

1. **Status** — one sentence: what we're building and where we are in the pipeline
2. **Current stage** — which sprint stage (brief/plan/build/review/test/verify/ship/retro) + % complete
3. **What's done** — completed tasks with commit hashes
4. **What's in progress** — files being edited, half-finished work
5. **What's blocked** — unresolved decisions, missing deps, failing tests with suspected cause
6. **Next step** — specific next action (file, function, step) — not vague
7. **Key decisions** — architectural choices made this session and WHY
8. **Files to review** — 3-7 most important files with one-line descriptions
9. **Recommended command** — which `/mm:` command to run next

Then commit:
```bash
rtk git add .planning/HANDOFF.md && rtk git commit -m "chore: save handoff for next session"
```

Keep under 500 words. End with: "Handoff saved. Run `/mm:session restore` in your next session."

---

## save --lite — Quick pause

Write `.planning/PAUSE.md` with:
1. What we're building (one sentence)
2. Current stage
3. Completed tasks (with commit hashes)
4. Next task — exactly what file/function/step to resume on
5. Open questions
6. Relevant files (3-5)
7. Key decisions made and why

Then commit:
```bash
rtk git add .planning/PAUSE.md && rtk git commit -m "chore: save session pause point"
```

Keep under 400 words. End with: "Session paused. Run `/mm:session restore` to resume."

---

## restore — Resume from context

Check for resume files in priority order:
1. `.planning/HANDOFF.md`
2. `.planning/PAUSE.md`
3. `.planning/CHECKPOINT.md`
4. `.planning/SESSION-END.md`

Use the first one found. Then:
1. Read and absorb everything in it
2. Read the files listed under "Relevant files" or "Files to review"
3. Verify current git state matches — check `rtk git log --oneline -5`
4. Announce:
   ```
   Resumed: [what we're building]
   Stage: [current stage]
   Last completed: [last task done]
   Next up: [next task]
   Source: [which file was used]
   ```
5. Ask: "Ready to continue?" — wait for confirmation before working

If no file found, ask: "No resume context found. What are we working on?"

---

## tokens — Token usage

Run:
```bash
node -e "
const fs = require('fs'), path = require('path'), os = require('os');
const today = new Date().toISOString().slice(0,10);
const file = path.join(os.homedir(), '.claude', 'logs', \`tokens-\${today}.json\`);
if (!fs.existsSync(file)) { console.log('No token data yet for today.'); process.exit(0); }
const s = JSON.parse(fs.readFileSync(file));
const k = n => n >= 1000 ? (n/1000).toFixed(1)+'k' : String(n);
console.log(\`\nToken usage for \${s.date}\`);
console.log(\`  Total:  ~\${k(s.total_tokens)} tokens across \${s.calls} tool calls\`);
console.log(\`  Input:  ~\${k(s.input_tokens)}\`);
console.log(\`  Output: ~\${k(s.output_tokens)}\n\`);
console.log('By tool:');
Object.entries(s.by_tool).sort((a,b) => b[1].total_tokens - a[1].total_tokens)
  .forEach(([tool, t]) => console.log(\`  \${tool.padEnd(35)} \${k(t.total_tokens).padStart(6)} tok  (\${t.calls} calls)\`));
console.log('\nNote: estimates only (~4 chars/token).');
"
```
