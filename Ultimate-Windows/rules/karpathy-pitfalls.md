# Karpathy Engineering Pitfalls

Condensed from Andrej Karpathy's AI coding guidance. Apply these rules when writing or reviewing code.

## Don't hallucinate libraries

- Only import packages that are verified to exist in the project's dependency manifest (`package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`)
- If a library is not in the manifest, say so — don't invent an import that looks plausible
- Verify function signatures by reading the source or docs, not from memory

## Prefer existing patterns in the codebase

- Before introducing a new abstraction, grep for how similar problems are already solved in this repo
- Match the style of the file you're editing — don't mix paradigms (e.g., don't introduce async where the rest of the module is sync)
- When unsure about a pattern, read two or three adjacent files before writing

## Don't invent test cases from thin air

- Test cases should reflect actual documented behavior or explicit user requirements
- If you're writing a test and you're not sure what the correct output should be, say so — don't hardcode a value you guessed
- Tests that always pass (e.g., `assert true`) are worse than no tests: delete them

## Be explicit about uncertainty

- When you're not sure something is correct, say "I'm not sure — verify this" rather than presenting it confidently
- Do not paper over gaps with confident-sounding filler. "I believe this should work" is a red flag phrase.
- If a fix might have side effects you haven't traced, say so explicitly

## Small, targeted edits

- Make the smallest change that fixes the problem
- Don't refactor surrounding code while fixing a bug — that's how regressions hide
- Each edit should be explainable in one sentence

## Don't overfit to the prompt

- If the user asks to fix a bug, fix the bug — don't reorganize the file
- If you see a different problem nearby, note it separately rather than fixing it silently
- Scope creep in code edits leads to unreviewed changes

## Verify before claiming success

- Don't say "this should work" without evidence
- Run the code, run the tests, or explicitly state what verification step is needed
- A failed build or test is information — read the error before responding
