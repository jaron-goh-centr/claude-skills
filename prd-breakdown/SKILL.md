---
name: prd-breakdown
description: Parses a product brief or feature description into a structured task hierarchy with acceptance criteria, dependencies, and complexity estimates. Use when user describes a feature to build, pastes a product brief, or asks to plan/break down new work.
when_to_invoke: When user describes a feature to build, pastes a product brief, asks to plan a sprint, or kicks off a new module. Activates before any implementation begins to ensure work is decomposed into actionable units.
---

# PRD Breakdown — Brief to Task Hierarchy

Ported from Hamster's Task Master pattern (`eyaltoledano/claude-task-master`). Converts high-level feature descriptions into structured, machine-actionable task lists with acceptance criteria. Directly feeds into `TaskCreate` calls or sprint planning.

## When to use this skill

- User says: "I want to build X", "add feature Y", "plan this sprint", "new module for LIFE"
- User pastes a multi-paragraph feature description
- Before any significant implementation work begins
- When breaking a large feature into parallel workstreams

## Workflow

### Phase 1 — Extract intent

Read the brief. Identify:
- **Goal**: What user outcome does this deliver?
- **Scope boundary**: What's explicitly NOT included?
- **Constraints**: Tech stack, performance, deadlines, dependencies on existing modules
- **Success signal**: How will we know it works?

If any of these are ambiguous, ask ONE clarifying question before proceeding.

### Phase 2 — Decompose into tasks

Break into atomic tasks. Each task must be completable in one focused session (roughly 1-4 hours of focused work). Rules:

- Tasks are **independent** where possible — minimize blocking dependencies
- Each task has a single clear output (a file, a function, a passing test suite)
- Group by layer: DB schema → API → hooks → UI → tests
- Name tasks with verb + noun: "Create events table migration", "Build useEvents hook", not "Events work"

### Phase 3 — Output format

Produce a task hierarchy in this exact structure:

```markdown
## Feature: <Feature Name>

**Goal:** <one sentence>
**Out of scope:** <what we're not doing>
**Done when:** <measurable success criteria>

---

### Task 1: <Verb + Noun>
**Layer:** DB / API / Hook / UI / Test
**Depends on:** Task N (or "none")
**Complexity:** S / M / L
**Acceptance criteria:**
- [ ] <specific, testable criterion>
- [ ] <specific, testable criterion>
- [ ] <specific, testable criterion>

### Task 2: <Verb + Noun>
...
```

### Phase 4 — Create tasks (if approved)

After user reviews and approves the breakdown:
1. Use `TaskCreate` for each task in dependency order
2. Set first unblocked tasks to `in_progress` if user wants to start immediately
3. Note the critical path (longest dependency chain)

## Rules

- **Acceptance criteria must be testable** — "works correctly" is not a criterion. "Returns 200 with correct JSON shape when called with valid auth token" is.
- **No goldplating** — decompose what was asked, not what could hypothetically be added. YAGNI.
- **Layer order matters** — always DB → API → hooks → UI → tests. Never skip layers.
- **S/M/L complexity**:
  - S = single function, clear spec, no ambiguity (< 1 hour)
  - M = multi-file change, some unknowns (1-3 hours)
  - L = cross-cutting concern, requires investigation first (3+ hours, consider further decomposition)
- **L tasks get broken down further** — if a task is L complexity, split it before accepting it

## LIFE project specifics

When breaking down LIFE features, always check these invariants are covered in acceptance criteria:

- [ ] RLS policy on any new table
- [ ] Zod schema on any new API boundary
- [ ] Optimistic mutation with rollback for any write operation
- [ ] Realtime handler (surgical cache patch, not full refetch) if data can change externally
- [ ] `dark:` variants on any new UI component
- [ ] Audit trail entry for any INSERT/UPDATE/DELETE

## Example output (abbreviated)

```markdown
## Feature: Calendar Event Creation

**Goal:** User can create events directly from the day view
**Out of scope:** Recurring events, attendees, calendar source sync
**Done when:** Event appears in DayView immediately after creation, persisted to DB, survives page refresh

---

### Task 1: Add event insert RLS policy
**Layer:** DB
**Depends on:** none
**Complexity:** S
**Acceptance criteria:**
- [ ] Policy allows authenticated users to insert rows where user_id = auth.uid()
- [ ] Policy blocks insert where user_id != auth.uid()
- [ ] Migration runs cleanly on local Supabase

### Task 2: Build createEvent API function
**Layer:** API
**Depends on:** Task 1
**Complexity:** M
**Acceptance criteria:**
- [ ] Accepts CreateEventInput validated by Zod schema
- [ ] Returns created event with all fields
- [ ] Returns 400 with validation error on bad input
- [ ] Logged in audit_trail table
```
