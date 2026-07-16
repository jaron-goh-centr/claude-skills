---
name: plan-consistency-check
description: Pre-draft consistency gate for implementation plans — verifies every spec requirement maps to a task BEFORE any plan is drafted. Use immediately before superpowers:writing-plans (which does drafting and post-hoc self-review, but only checks traceability AFTER writing). Trigger when about to turn a spec/brief/design doc into an implementation plan or task list. Not a planning skill itself — it gates one.
---

# Plan Consistency Check (pre-draft gate)

Run this BEFORE drafting any implementation plan. Then hand off to `superpowers:writing-plans` for the actual drafting.

## The gate

Before writing a single task, verify the spec and proposed implementation are coherent:

1. **Requirement traceability** — List every requirement from the spec. Every requirement must map to at least one planned task. Flag any that don't — they are either dropped scope or missing tasks.
2. **No scope creep** — Every task must trace back to a spec requirement. Tasks with no spec backing are out of scope unless the user explicitly adds them.
3. **Architecture alignment** — Does the proposed tech stack and architecture match the constraints stated in the spec? (e.g., spec says "no external dependencies" but plan uses a third-party library)
4. **Contradictions** — Any place where the spec says X but the plan does Y must be resolved before proceeding.

If gaps are found: resolve them now. Do not silently drop requirements or add tasks. If resolution requires user input, ask before proceeding.

**Only begin drafting once every spec requirement has a traceable task.** Then invoke `superpowers:writing-plans` for structure, task right-sizing, interfaces, and execution handoff.

## Why this exists separately

`superpowers:writing-plans` checks traceability only AFTER the plan is written (post-hoc self-review). By then, dropped requirements are baked into the structure and expensive to reconcile. This gate runs the same check up front, when fixing it costs one list, not a rewrite.

## Edge cases

- **No formal spec** (verbal brief only): reconstruct the requirement list from the conversation, show it to the user, get confirmation — THAT becomes the spec for tracing.
- **Spec conflicts with CLAUDE.md invariants**: the project constitution wins; surface the conflict rather than silently obeying the spec.
- **Requirement can't be scoped into a task yet** (needs research): create an explicit research task tracing to it — never leave a requirement unmapped.
