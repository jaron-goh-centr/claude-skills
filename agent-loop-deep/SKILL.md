---
name: agent-loop-deep
description: Use when running a complex, lengthy, or multi-session agent loop — unknown step horizon, may span multiple context windows, irreversible operations present, parallel sub-agents beneficial, mandatory plan-first before any action.
---

## Tier 3 — Deep Loop Rules

For tasks: system-wide migration · architecture redesign · comprehensive audit · multi-session automation · long-running research synthesis · anything with irreversible operations

## Optimized Prompt Template

Fill this in before executing — do not skip:

```
Goal: [task in one sentence]
Plan: write plan.md before any action
Done when: [evaluator verdict — NOT self-assessment]
State: progress.md + git commit each pass
Pause before: [list each irreversible op in the task]
Budget: [N] tries max
```

## Rules

1. **Plan first:** Mandatory — write a plan file before taking any action. This is loop engineering: designing the loop system, not just the prompt.
2. **State to disk:** Write progress.md + git commit each meaningful pass. State must survive context window death. The next session should be able to pick up exactly where this one left off.
3. **Done-check:** Separate evaluator (can be a second agent or second prompt). The worker never grades its own work. Loop terminates on the evaluator's PASS verdict, not the worker's self-assessment.
4. **Hard stop:** Max iterations + token/budget ceiling. Log cost at each major checkpoint. Also stop early when 2 consecutive phases produce no new progress or the same evaluator failure repeats.
5. **Pattern:** Manager→Helpers — a lead agent decomposes the goal and hands independent chunks to sub-agents working in parallel.
6. **Human gate:** Pause and get explicit approval before any irreversible/one-way-door action: delete, deploy, send, merge, publish. Do not proceed on assumption.
7. **One change per pass** — defined per unit: each Helper makes one targeted change per its own pass; the Manager makes one orchestration decision per its pass (assign, collect, or integrate — not all three). Helpers work in parallel but each governs its own scope independently.
8. **Log every step:** Record thought, action, and result. You must be able to debug from logs at any point without reconstructing state.
9. **Loop engineering mindset:** Design the system (prompt file, state file, stop condition, human gates) before running. You are the loop architect; the agent runs inside what you design.
10. **Comprehension debt check:** After each major phase, verify you can still read and understand the output. If not, pause before continuing.
11. **Cross-trial memory:** If spanning multiple sessions, write reflections to disk. Never rely on context window continuity for Deep tasks.

## Deep Cycle

```
[Setup — once at the start]
1. Write plan.md (goal, phases, done-criteria, stop conditions, irreversibles list)
2. Identify all irreversible ops → set human gates for each

[Each Pass]
3. Read progress.md — what's done, what failed, what was tried
4. Act    — one targeted change
5. Verify — evaluator checks (separate agent or prompt)
6. Log    — write to progress.md (thought, action, result)
7. Commit — git commit if meaningful progress
8. Done?  → stop and report | Not done? → next pass
```

## Manager→Helpers Pattern

```
Manager: decompose goal into independent chunks with clear interfaces
Helpers: work chunks in parallel (no shared files between helpers)
Manager: collect results, verify cohesion, synthesize final output
```

## Evaluator Disagreement Protocol

When worker believes done but evaluator returns FAIL:

1. Capture evaluator's reason verbatim
2. Classify: **Defect** (real bug in output) | **Rubric issue** (rubric is wrong/incomplete) | **Out of scope** (evaluator exceeding brief)
3. If Defect: fix and rerun — counts as one more pass
4. If Rubric issue: revise rubric, document the change, rerun evaluator
5. If Out of scope: override evaluator, mark done, log the disagreement
6. After 2 consecutive Defect loops with no progress → escalate to human

Never loop indefinitely on evaluator disagreement.

## Irreversible Action Gate

Before any of these, stop the loop and show the planned action explicitly:
- delete (files, records, branches)
- deploy (to production or staging)
- send (email, message, notification)
- merge (PR, branch)
- publish (artifact, post, release)

Get explicit approval. Then continue.

## Common Mistakes

- Skipping the plan file (forces reconstruction mid-loop when the context window dies)
- No git commits (loses all progress on context window expiry)
- Self-grading — the worker saying "looks done" with no external verifier (Osmani's "cognitive surrender")
- No human gate on irreversibles
- Running past comprehension debt without pausing to review
- No cross-trial memory for tasks spanning multiple sessions
- Batch changes per pass — still wrong at this tier, still causes thrash
