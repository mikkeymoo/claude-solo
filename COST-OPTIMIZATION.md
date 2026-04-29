# Cost Optimization Guide

Claude Code token costs can vary 4-20x depending on caching behavior and session patterns.
This guide covers the key levers available in Ultimate-Windows v0.3.0.

---

## Cache TTL regression (CC v2.1.81+)

**Problem:** Claude Code v2.1.81 changed the default cache TTL from 1 hour to 5 minutes.
Resumed sessions and context window rebuilds now write 5m-TTL cache blocks instead of 1h-TTL,
increasing costs 4-20x for long or frequently-resumed sessions.

**Version timeline:**

- v2.1.80 and earlier: default 1h TTL — low cost
- v2.1.81 to v2.1.107: default 5m TTL — high cost (regression)
- v2.1.108+: `ENABLE_PROMPT_CACHING_1H=1` env var restores 1h TTL

**Fix option 1 — cache-fix-wrapper (recommended):**

```bash
# Install: https://github.com/cnighswonger/claude-code-cache-fix
# Wrapper sets CACHE_FIX_* env vars to force 1h TTL
# Detection: install.sh check_prereqs_ultimate() warns if missing on affected versions
```

**Fix option 2 — env var (CC v2.1.108+):**

```json
// In ~/.claude/settings.json env block:
"ENABLE_PROMPT_CACHING_1H": "1"
```

**How to check your version:**

```bash
claude --version
```

---

## Understanding the cost-summary output

The SessionStart `cost-summary.sh` hook emits:

```
[cost] today: 142k reads, 38k 5m-writes, 12k 1h-writes (78% hit) ~$1.84
```

| Field       | Meaning                                                       |
| ----------- | ------------------------------------------------------------- |
| `reads`     | Cache read tokens — cheapest ($0.30/1M)                       |
| `5m-writes` | Ephemeral 5-min cache writes — expensive ($3.75/1M)           |
| `1h-writes` | 1-hour cache writes — expensive but more effective ($3.75/1M) |
| `hit%`      | cache_read / (cache_read + writes + direct_input)             |
| `~$X.XX`    | Estimated cost at Sonnet 4.6 rates                            |

**Target:** hit ratio > 75%. Below 60% means you're rebuilding context too often.

---

## Session hygiene tips

1. **Keep sessions long** — longer sessions amortize the cache write cost across more reads
2. **Use /pre-compact-checkpoint** — saves state before compaction so the resumed session rebuilds less
3. **Avoid restarting Claude Code frequently** — each restart is a cold cache
4. **Prefer Serena LSP over Grep** — Grep loads file content into context; LSP returns structured symbols at ~20% token cost
5. **Use subagents for exploration** — Haiku subagents cost 10x less than Sonnet for read-only research

---

## Cost by operation type (approximate, Sonnet 4.6)

| Operation                           | Est. cost per 1000 invocations |
| ----------------------------------- | ------------------------------ |
| Read large file (10k tokens)        | $0.03 direct, $0.003 cached    |
| Grep search (5k token result)       | $0.015 direct                  |
| LSP symbol lookup (500 tokens)      | $0.0015                        |
| Bash command (2k tokens round-trip) | $0.006                         |
| Agent spawn (Haiku)                 | $0.0005/1k tokens              |

---

## Rate table (as of 2026-04, Sonnet 4.6)

| Token type             | Rate per 1M |
| ---------------------- | ----------- |
| Cache read             | $0.30       |
| Cache write (5m or 1h) | $3.75       |
| Direct input           | $3.00       |
| Output                 | $15.00      |

Haiku 4.5 is ~10x cheaper for subagent tasks. Wire `CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-4-5-20251001`
(already set in Ultimate-Windows `settings.json`).
