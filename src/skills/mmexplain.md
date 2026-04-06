Deep code explanation — traces data flow, explains decisions, answers "why" not just "what".

Usage: `/mm:explain [file, function, or concept]`

Structure your explanation as:

1. **What it does** — one sentence. What is the observable behavior?

2. **Why it exists** — what problem does this solve? What would break without it?

3. **How it works** — walk through the logic step by step:
   - Trace the data: what comes in, what transforms, what goes out
   - Explain each non-obvious line or decision
   - Call out: design patterns used, performance trade-offs, known limitations

4. **Key dependencies** — what does this rely on? What relies on it?

5. **Edge cases handled** — what special inputs or states does it account for?

6. **What to watch out for** — gotchas, things that have caused bugs, things that could break under load or on a different platform

Format: plain prose paragraphs, not bullet lists. Explain it the way a senior dev would explain it to someone who needs to maintain it.

Depth calibration:
- For a single function: 150-300 words
- For a file/module: 400-600 words
- For a system/architecture: 600-1000 words with ASCII diagram

Don't explain things that are obvious from reading the code. Focus on intent and non-obvious reasoning.
