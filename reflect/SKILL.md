---
name: reflect
description: Auto-retry loop that feeds exact error output back to the model for self-correction. Use when code fails to run, tests fail, lint errors appear, or a previous fix attempt didn't resolve the issue.
when_to_invoke: Any time code fails to run, tests fail, lint errors appear, or a previous fix attempt didn't resolve the issue. Also invoked as escalation path when direct fixes stall after 1-2 attempts.
---

# Reflect — Bounded Self-Correction Loop

Ported from Aider's `reflected_message` pattern (`aider/coders/base_coder.py`). When an attempt fails, the exact error is fed back verbatim as the next prompt context — not summarized, not paraphrased. Model retries with full diagnostic information. Hard cap: 3 iterations.

## When to use this skill

- Code just threw an error (runtime, compile, lint, type-check)
- Tests are failing
- A previous fix attempt didn't resolve the problem
- Output doesn't match expected behavior and there's a concrete failure signal
- User says: "it broke", "not working", "still failing", "same error"

## Workflow

### Iteration structure

```
Attempt N:
  1. Run the code / test / lint
  2. Capture EXACT output (stdout + stderr + exit code)
  3. If success → done, report result
  4. If failure and N < 3 → extract error block (see below), retry as Attempt N+1
  5. If failure and N = 3 → escalate (see Escalation)
```

### Step 1 — Capture error block

Extract a structured error block from output. Format exactly:

```
[REFLECT ERROR — Attempt N/3]
Command: <exact command run>
Exit code: <code>
File: <file>:<line> (if present)
Error: <exact error message — no paraphrase>
Relevant output:
<last 20 lines of stdout/stderr>
```

### Step 2 — Feed back verbatim

Prepend the error block to the next attempt prompt. Do NOT summarize. The model needs the exact text to pattern-match against its training data.

### Step 3 — Targeted fix only

Each retry makes the minimal change implied by the error. Do not refactor surrounding code. Do not "improve" things while fixing. Fix the one thing the error points to.

### Step 4 — Escalation (after 3 failures)

If 3 iterations haven't resolved it:
1. Present all 3 error blocks side-by-side
2. Identify what changed between attempts
3. State the root hypothesis clearly
4. Invoke `troubleshooting-applications` skill for deeper diagnosis
5. Ask user whether to continue or change approach

## Rules

- **Never paraphrase errors** — exact text only. Model self-correction depends on exact token matching.
- **Never expand scope** — fix only what the error names. Scope creep across retries compounds failure.
- **Always show iteration count** — tell user "Attempt 2/3" so they know where in the loop we are.
- **Stop at 3** — infinite loops waste tokens and mask root cause. Hard stop, then escalate.
- **Distinguish error types** — lint errors need different fixes than runtime errors. Read the error type before attempting a fix.

## Error type quick-reference

| Error signal | Likely fix |
|-------------|-----------|
| `TypeError`, `AttributeError` | Wrong type passed — check call site |
| `ModuleNotFoundError`, `Cannot find module` | Missing import or wrong path |
| `SyntaxError`, `Unexpected token` | Malformed code — check the line cited |
| `AssertionError`, `FAILED` in test output | Logic error — check test expectation vs implementation |
| `ESLint`, `tsc`, lint errors | Formatting or type violation — fix at flagged line |
| `ENOENT`, `FileNotFoundError` | Wrong path — check file existence |
| Non-zero exit, no error text | Run with verbose flag (`--verbose`, `-v`) to get more output |

## Interaction with other skills

- **After reflect exhausts 3 attempts** → invoke `troubleshooting-applications`
- **Before reflect** → if the error is in a test, consider whether `centr-test-debug` applies first
- **During reflect** → do not invoke `brainstorming-ideas` (that's planning, not fixing)
