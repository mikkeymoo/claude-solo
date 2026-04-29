# Recommended Skills & Tools

External skills and tools evaluated for integration with Ultimate-Windows.
Organized by category with install commands and integration notes.

---

## Cost optimization

### cache-fix (INTEGRATE — already bundled)

- **Repo:** https://github.com/cnighswonger/claude-code-cache-fix
- **Why:** Fixes the 5m→1h cache TTL regression in CC v2.1.81+. Without it, resumed sessions
  cost 4-20x more. This is the single highest-ROI tool for heavy Claude Code users.
- **Install:** See repo README — installs as a wrapper around the `claude` CLI
- **Integration:** `install.sh check_prereqs_ultimate()` warns if missing on affected CC versions.
  Do NOT set `CACHE_FIX_*` env vars yourself — the wrapper sets them.

### lean-ctx (RECOMMEND — opt-in)

- **Repo:** https://github.com/leanctx/lean-ctx
- **Why:** Caches file reads at ~13 tokens per re-read (vs full file content each time).
  Complements RTK; they handle different layers.
- **Install:** `cargo install lean-ctx` or `npm install -g lean-ctx-bin`
- **Integration:** `bash install.sh --windows --with-lean-ctx` (opt-in flag)

---

## Code navigation (token-saving)

### Serena MCP (INTEGRATE — already bundled)

- **Repo:** https://github.com/oraios/serena
- **Why:** LSP-based symbol navigation. 80% token savings on code exploration vs Grep.
  Returns structured results; Grep returns raw file content.
- **Install:** Bundled with Claude Code as an MCP server
- **Integration:** `compress-lsp-output.sh` hook trims verbose Serena output.
  `enforce-lsp-navigation.sh` hook nudges Grep→LSP for code symbol searches.

### lsp-enforcement-kit (EVALUATED — covered by serena)

- **Repo:** https://github.com/nesaminua/claude-code-lsp-enforcement-kit
- **Why evaluated:** Claims ~80% token savings for code navigation. Ultimate-Windows achieves
  the same via Serena + compress-lsp-output + enforce-lsp-navigation hooks.
- **Status:** Not adopted separately — redundant with existing setup.

---

## Skills worth cherry-picking

### addyosmani/agent-skills

- **Repo:** https://github.com/addyosmani/agent-skills
- **Picks:** `web-search`, `image-analysis`, `pdf-reader` — practical, well-scoped
- **Skip:** Anything that duplicates existing Ultimate-Windows skills

### mattpocock/skills

- **Repo:** https://github.com/mattpocock/skills
- **Picks:** TypeScript-specific skills, especially around `zod` schema generation and
  `ts-morph` code transformations
- **Skip:** React-specific if not using React in your projects

### vercel-labs/skills

- **Repo:** https://github.com/vercel-labs/skills
- **Picks:** Next.js deployment, Edge Runtime debugging, Vercel CLI integration
- **Audience:** Only relevant for Vercel-hosted projects

---

## Evaluated and rejected

These were assessed from the starred repos list and rejected for specific reasons:

| Repo                                                | Category              | Reason rejected                                                        |
| --------------------------------------------------- | --------------------- | ---------------------------------------------------------------------- |
| `claw-code`, `openclaude`, `oh-my-codex`            | Agent harnesses       | Wrong target — not Claude Code extensions                              |
| `tweakcc`                                           | Prompt injection      | Modifies CC internal system prompts; breaks on every update            |
| `ccs`, `cc-switch`, `CLIProxyAPI`                   | Multi-account routing | User has personal config; not claude-solo concern                      |
| `son-of-claude`                                     | Teams messaging       | Niche and gimmicky                                                     |
| `phantom`, `deer-flow`, `hermes-agent`, `OpenHands` | Agent platforms       | Full platforms, not CC extensions                                      |
| `AionUi`                                            | Multi-agent GUI       | Different ecosystem                                                    |
| `claude-video-vision`                               | Video input           | No documented use case for this user                                   |
| `chandra` (OCR)                                     | OCR pipeline          | 10GB models, heavyweight; revisit when eDiscovery OCR need is explicit |
| `gepa`, `hone`                                      | Prompt evolution      | Too early-stage for production use; watch for v1.0                     |
| `son-of-claude`                                     | Teams messaging       | Gimmicky — not core workflow                                           |

### chandra (OCR) — future eval

Worth revisiting for eDiscovery use cases (Relativity native OCR is expensive).
Model weights are large (~10GB) but the workflow could save significant Relativity processing costs.
Track: https://github.com/chandra-ocr (placeholder — verify actual repo name)

---

## Usage pattern notes

From analysis of 60+ starred Claude Code repos, the dominant themes are:

1. **Cost/cache/token optimization** — biggest signal. cache-fix + lean-ctx + session hygiene
2. **Observability/HUDs** — session-hud, cost-summary, quota-warmup all address this
3. **Plan-first workflows** — riper skill, plan-before-code CLAUDE.md guidance
4. **Skill libraries** — addyosmani, mattpocock for domain-specific work
5. **Windows compat** — addressed by bootstrap-encoding, validate-utf8-source, Setup-WindowsEncoding.ps1
