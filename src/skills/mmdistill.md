Compress a large document for LLM consumption without losing any information.

Usage: `/mm:distill [file path]` — or distill `.planning/PLAN.md` if no file given.

This is NOT summarization. Every fact, decision, constraint, and relationship must survive.
What gets removed: headers, padding, repetition, human-oriented prose LLMs don't need.

Process:

1. **Read** the target file
2. **Inventory** what must be preserved:
   - All decisions and their rationale
   - All constraints (technical, time, scope)
   - All task names, dependencies, and done-criteria
   - All schema/API/config changes
   - Any warnings or risk flags
3. **Distill** — rewrite in dense, structured prose or compact bullet form:
   - Remove: "In this section we will...", "As mentioned above...", redundant section intros
   - Preserve: every specific fact, number, file name, decision
   - Target: ≤40% of original token count
4. **Validate** — mentally reconstruct: could you answer any question about the original from the distillate alone?
5. **Write** to `.planning/[original-name].distilled.md`
6. **Report**:
   ```
   Distilled: PLAN.md
   Original: ~2400 tokens → Distilled: ~820 tokens (66% reduction)
   Validation: all tasks, decisions, and constraints preserved ✓
   ```

If the distilled version would be >5K tokens, shard it: one file per major section,
with a `_index.md` listing all shards.

Use the distilled version in future prompts instead of the original.
