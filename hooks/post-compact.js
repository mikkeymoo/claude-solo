#!/usr/bin/env node
/**
 * claude-solo PostCompact hook
 *
 * Fires after Claude compresses context. Re-injects the checkpoint saved
 * by PreCompact so Claude automatically recovers sprint state without the
 * user needing to manually run /session --resume.
 *
 * Input (stdin): JSON { session_id, cwd, summary }
 * Output (stdout): JSON { additionalContext: "..." }
 */

import { createInterface } from "readline";
import { existsSync, readFileSync } from "fs";
import { join } from "path";

const rl = createInterface({ input: process.stdin });
let raw = "";
rl.on("line", (line) => (raw += line));

rl.on("close", () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.stdout.write(JSON.stringify({}));
    return;
  }

  const cwd = input.cwd || process.cwd();
  const checkpointPath = join(cwd, ".planning", "CHECKPOINT.md");

  if (!existsSync(checkpointPath)) {
    // No checkpoint — nothing to inject
    process.stdout.write(JSON.stringify({}));
    return;
  }

  let checkpoint;
  try {
    checkpoint = readFileSync(checkpointPath, "utf8");
  } catch {
    process.stdout.write(JSON.stringify({}));
    return;
  }

  // Trim to avoid bloating context — first 2000 chars covers git state + sprint docs
  const trimmed = checkpoint.slice(0, 2000);
  const suffix =
    checkpoint.length > 2000
      ? "\n\n[checkpoint truncated — read .planning/CHECKPOINT.md for full content]"
      : "";

  const additionalContext = [
    "## Context Restored After Compaction",
    "",
    "The following checkpoint was auto-saved before context was compressed.",
    "You are already caught up — no need to run /session --resume.",
    "",
    trimmed + suffix,
  ].join("\n");

  process.stderr.write(
    "🔄 claude-solo: context restored from .planning/CHECKPOINT.md\n",
  );
  process.stdout.write(JSON.stringify({ additionalContext }));
});
