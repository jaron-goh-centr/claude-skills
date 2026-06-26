---
name: agent-loop-lite
description: Use when running a short, simple agent loop — ≤3 predictable steps, machine-checkable done-state, fits in one context window, no irreversible operations, max 5 iterations.
---

## Tier 1 — Lite Loop Rules

For tasks: fix one failing test · rewrite a paragraph to word count · validate a config value · verify a file exists · rename a symbol across a small codebase

## Before Starting: Preflight (30 seconds)

1. **Is a loop even needed?** If the task has a fixed, fully predictable path — just prompt once.
2. **Quick risk check:** How many files touched? Is there a verifier? Is anything irreversible?
   - Multi-file + no clear verifier → upgrade to Standard
   - Any irreversible action → upgrade to Standard or Deep
   - Shared fixtures, public APIs, secrets, generated code → upgrade to Standard

## Optimized Prompt Template

Fill this in before executing — do not skip:

```
Goal: [task in one sentence]
Done when: [machine-checkable condition — tests pass / word count N / file exists]
Check by: [run tests / count words / verify file / grep for string]
Stop after: 5 tries
```

## Rules

1. **Done-check:** Functional only — machine answers yes/no with zero opinion. No rubric, no judgment at this tier.
2. **Hard stop:** Max 5 iterations OR stop early if 2 consecutive passes produce the same failure with no new information.
3. **Pattern:** Solo loop — one agent, no separate checker needed at this scale.
4. **State file:** None — task fits in one context window.
5. **Plan step:** None — but run the 30-second preflight above. If it reveals hidden scope, upgrade tier.
6. **One action per pass** — never batch multiple changes in one iteration.
7. **Verify each pass** — run the functional check before moving to the next iteration. Never assume it worked.

## Cycle

```
[Pass N of max 5]
1. Act   — take one targeted action
2. Check — run the functional test / count / verify
3. Done? → stop and report | Not done? → next pass
```

## Common Mistakes

- Running a loop when a single prompt would have worked (check first)
- Batching multiple fixes in one pass (causes thrash, hard to debug)
- Skipping the verify step ("it should be fine")
- Setting no iteration cap
- Using a judgment check when a functional check exists
