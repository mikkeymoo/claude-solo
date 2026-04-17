---
name: mm:adversarial
description: "Adversarial logic review — poke holes in assumptions, find edge cases, broken invariants, state machine gaps, and logic paths the author didn't think about."
---

Adversarial logic review. Your job is to break the code's reasoning, not its security perimeter.

Read the changed code. For each component, interrogate the logic ruthlessly:

**Assumptions that aren't enforced**
- What does this function assume about its inputs that isn't validated?
- What does it assume about call order, initialization, or system state?
- What happens when a caller violates those assumptions? Does it fail loudly or silently corrupt state?
- Are there implicit preconditions that only hold in the happy path?

**Edge cases the author didn't think about**
- Empty collections, zero values, negative numbers, very large inputs
- First item / last item boundary conditions
- Off-by-one errors in loops, slices, pagination
- What happens when two things that "shouldn't" be equal are equal?
- What happens when a required dependency returns nothing instead of an error?

**State machine gaps**
- Draw the state machine. Are there transitions that are missing? Unreachable states? States you can get stuck in?
- Can state become inconsistent between two stores (DB + cache, memory + disk, parent + child)?
- What happens if an operation is interrupted halfway? Is the result a valid state or partial garbage?
- Is there any state that is written before it should be visible to other callers?

**Logic that doesn't compose**
- Functions that work correctly in isolation but produce wrong results when combined
- Operations that are not commutative but are treated as if they are
- Conditional branches that overlap or have gaps (missing `else`, unhandled enum variants)
- Code that handles one failure mode but leaves others silently unhandled

**Concurrency and ordering**
- Check-then-act patterns where the state can change between the check and the act
- Shared mutable state with no synchronization
- Operations that assume a specific execution order but nothing enforces it
- Caches or memoized values that can go stale mid-operation

**Data flow surprises**
- Where does data get mutated in place when the caller expects it unchanged?
- Where is a reference passed when a copy was intended (aliasing bugs)?
- Where does a function return a value the caller ignores, masking a real error?
- Where is an error swallowed (`catch {}`, `_ =`, `|| null`) hiding a failure?

**Contracts that drift**
- Does the function signature accurately reflect what it actually does?
- Are return types honest — or does a `string` sometimes come back as `null`?
- Does the documentation describe behavior that the code no longer implements?
- Are there callers that depend on undocumented side effects?

Orient yourself first:
```bash
rtk git diff HEAD~5 --stat
rtk git log --oneline -10
```

For each finding:
```
🔴 BREAKS: [what goes wrong]
   When: [the specific input/state/sequence that triggers it]
   Result: [what actually happens — wrong output, crash, silent data loss]
   Fix: [specific code change]
```

Then list your unverified assumptions — things you couldn't confirm without more context, that could be gaps if your assumption is wrong.

End with: "The weakest assumption in this code is [X] because [Y]. If that breaks, [Z] happens."
