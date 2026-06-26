---
name: agent-loop
description: Use when about to run, design, or review any agent loop — classifies task complexity (lite/standard/deep), constructs an optimized structured prompt, and applies tier-specific rules. Auto-fires on signals like "loop this", "iterate until", "repeat until done".
---

## Overview

An agent loop is an LLM that calls tools, checks the result, and repeats toward a stated goal until done or stopped. Before running any loop, classify the task and construct an optimized prompt.

## Step 1: Classify Complexity

| Tier | Signals | Hard cap |
|------|---------|----------|
| **Lite** | ≤3 predictable steps · done-state machine-checkable in <30s · single tool · no irreversible ops · fits one context window | 5 iterations |
| **Standard** | 4–15 steps (some unknown) · multi-file but bounded · done-state functional or rubric · 2–4 tools · may need quality judgment | 10 iterations |
| **Deep** | 15+ steps or unknown horizon · may span context windows · irreversible ops present · parallel sub-tasks beneficial · multi-module scope | iterations + budget ceiling |

**When in doubt between tiers:** upgrade. It is cheaper to apply Standard rules to a Lite task than to under-govern a Deep task.

## Step 2: Construct the Loop Prompt

Before executing, build a structured prompt from the user's raw request using the tier template. Fill in all fields — do not leave placeholders.

**Lite template:**
```
Goal: [task in one sentence]
Done when: [machine-checkable condition]
Check by: [run tests / count / verify file]
Stop after: 5 tries
```

**Standard template:**
```
Goal: [task in one sentence]
Done when: [functional or rubric condition]
Plan: [3-step outline — write before acting]
One change per pass. Verify before next pass.
Log progress to PROGRESS.md after each meaningful change.
Stop after: 10 tries
```

**Deep template:**
```
Goal: [task in one sentence]
Plan: write plan.md before any action
Done when: [evaluator verdict — not self-assessment]
State: progress.md + git commit each pass
Pause before: [any irreversible ops in task]
Budget: [N] tries max
```

## Step 3: Apply Tier Rules

- **Lite** → follow `agent-loop-lite` rules
- **Standard** → follow `agent-loop-standard` rules
- **Deep** → follow `agent-loop-deep` rules

## Shared Invariants (all tiers, no exceptions)

1. Define "done" in externally verifiable terms before starting (functional preferred; judgment allowed only if rubric is written first)
2. Always set a hard stop — never run unbounded. Also stop when 2 consecutive passes produce no new information or the same failure repeats
3. Verify every action — observe the result, never assume it worked
4. Carry feedback into the next pass (tool result, test output, notes file)
5. No dangerous tools (merge, deploy, send, delete) without explicit scope

## 4 Done-Check Types

| Type | When to use | Example |
|------|-------------|---------|
| **Functional** | Machine answers yes/no | Tests pass, build compiles, file exists |
| **Visual** | Must be seen to judge | UI, thumbnail, layout |
| **Judgment** | Needs taste, but has a rubric | Score against checklist; second AI grades |
| **You decide** | Irreversible or pure taste | Loop pauses, you approve, then continues |

Start with Functional. Add Judgment only when Functional cannot capture the quality bar.

## When NOT to Loop

- Task has a fixed, fully predictable path → just prompt once (faster and cheaper)
- "Done" is not externally verifiable → fix the goal definition first
- Work is irreversible and you cannot review output → do it by hand
- A single prompt solves the problem → do not add loop overhead
- The loop would run with no stop condition → define one first
