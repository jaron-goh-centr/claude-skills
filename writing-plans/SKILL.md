---
name: writing-plans
description: Creates comprehensive implementation plans before writing code. Use when there is an approved design, spec, or multi-step task to execute.
---

# Writing Implementation Plans

## When to use this skill
- User requests an implementation plan, spec, or breakdown of a task.
- When continuing from a design document or after brainstorming is complete.
- Before touching code for any multi-step task.

## Approach
Write comprehensive implementation plans assuming the executing agent has zero context for the codebase. Document everything they need to know: which files to touch for each task, code snippets, tests to write, and docs to check.
- **Bite-Sized Tasks:** Each step is one action (2-5 minutes). Apply Test-Driven Development (TDD) principles.
- **Absolute Clarity:** Assume zero context. Use exact file paths and fully qualified shell commands.

## Workflow

1. **Acknowledge** — State you are creating the implementation plan.
2. **Cross-artifact consistency check** — Audit spec vs. plan vs. tasks before drafting (see below).
3. **Draft Plan Document** — Use the template below for `docs/plans/YYYY-MM-DD-<feature-name>.md`.
4. **Handoff** — After saving the plan, offer execution options (e.g., step-by-step review or batch execution).

## Cross-Artifact Consistency Check

Before writing a single task, verify the spec and proposed implementation are coherent:

1. **Requirement traceability** — List every requirement from the spec. Every requirement must map to at least one task. Flag any that don't — they are either dropped scope or missing tasks.
2. **No scope creep** — Every task must trace back to a spec requirement. Tasks with no spec backing are out of scope unless the user explicitly adds them.
3. **Architecture alignment** — Does the proposed tech stack and architecture match the constraints stated in the spec? (e.g., spec says "no external dependencies" but plan uses a third-party library)
4. **Contradictions** — Any place where the spec says X but the plan does Y must be resolved before proceeding.

If gaps are found: resolve them now. Do not silently drop requirements or add tasks. If resolution requires user input, ask before proceeding.

Only begin drafting tasks once every spec requirement has a traceable task.

## Instructions

### Output Template: Plan Document Header
```markdown
# [Feature Name] Implementation Plan

**Goal:** [One sentence describing what this builds]
**Architecture:** [2-3 sentences about approach]
**Tech Stack:** [Key technologies/libraries]
```

### Output Template: Task Structure
For each task, structure the steps logically:
```markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`

**Step 1: Write the failing test**
```python
def test_specific_behavior():
    ...
```

**Step 2: Run test to verify it fails**
Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL

**Step 3: Write minimal implementation**
```python
def function(input):
    ...
```

**Step 4: Run test to verify it passes**
Run: `pytest ...`
Expected: PASS

**Step 5: Commit**
```bash
git add ...
git commit -m "feat: add specific feature"
```
```

## Reminders
- Address DRY, YAGNI, TDD, and frequent commits.
- Exact commands with expected output.
- Complete code in plan, avoid vague references.
