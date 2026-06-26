---
name: agent-loop-standard
description: Use when running a medium-complexity agent loop — 4–15 steps, multi-file scope, functional or rubric-based done-check, optional Maker→Checker quality gate, max 10 iterations.
---

## Tier 2 — Standard Loop Rules

For tasks: fix all failing tests in a module · refactor a component · implement a feature with tests · code review + fix pass · rewrite a section of documentation to a rubric

## Optimized Prompt Template

Fill this in before executing — do not skip:

```
Goal: [task in one sentence]
Done when: [functional or rubric-based condition]
Plan: [3-step outline — write before acting]
One change per pass. Verify before moving to next pass.
Log one line to PROGRESS.md after each meaningful change.
Stop after: 10 tries
```

## Rules

1. **Done-check:** Functional OR judgment-with-rubric. If judgment, write the rubric before starting — not during.
2. **Hard stop:** Max 10 iterations.
3. **Pattern:** Solo by default. Switch to **Maker→Checker** when quality matters (see below).
4. **Plan step:** Write a 3-step brief plan before acting. Required for multi-step tasks.
5. **State file:** Use PROGRESS.md if task likely needs >5 passes. One line per meaningful change.
6. **Git commits:** Commit meaningful progress checkpoints.
7. **One change per pass** — Anthropic's finding: "one feature at a time" is critical for convergence. Batching causes thrash.
8. **Verify step:** Mandatory, not optional. Run the checker before moving to the next pass.

## ReAct Cycle

```
[Pass N of max 10]
1. Reason  — what is the single next change?
2. Act     — make exactly one targeted change
3. Observe — run the verifier, read the actual result
4. Done?   → stop and report | Not done? → next pass
```

## Maker→Checker Pattern (when quality matters)

Use when: output needs to meet a quality bar that cannot be captured by a simple yes/no check.

```
Maker:   produce or fix the output
Checker: grade against the rubric → PASS or FAIL + feedback
If FAIL: Maker reruns with Checker's feedback
If PASS: done
```

**Rule:** The Maker never grades its own work. A separate Checker (second agent or second prompt) is required.

## Common Mistakes

- Skipping the plan step for multi-step tasks
- Letting the Maker grade its own work
- Making multiple changes per pass (causes thrash)
- Skipping the verify step
- No state file when task runs >5 passes (loses track of what was tried)
- Writing the rubric after starting instead of before
