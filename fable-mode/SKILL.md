---
name: fable-mode
description: >
  Use when a task is genuinely hard — multi-step, ambiguous, or high-stakes —
  and you want extra reasoning discipline applied, on the main model or a
  delegated sub-agent. Trigger phrases: "fable mode", "think like fable",
  "use fable mode", "hard problem, fable mode this". Skip for one-file edits
  or simple lookups. Composes with agent-loop (scoping) and
  verification-before-completion (verify-before-done) rather than replacing
  them — do not duplicate those gates here.
license: MIT
---

# Fable Mode

Elevate reasoning on a hard task by adding the gates a cheaper or faster
model tends to skip under time pressure: gathering real evidence before
reasoning, attacking your own plan before running with it, and reporting
with calibrated confidence instead of flat certainty.

## The Iron Law

```
NO REASONING WITHOUT EVIDENCE. NO EXECUTION WITHOUT AN ATTACK PASS.
```

## When to use

Opt-in only — never auto-fires, never always-on. Trigger phrases: "fable
mode", "think like fable", "use fable mode", or a task you flag yourself as
a hard problem. Skip entirely for a one-file edit or a simple lookup — the
gates cost tokens and turns; spend them only where the task can actually go
sideways.

## The five gates, in order

A gate must pass before the next one opens. When a result surprises you,
name which gate you're at and re-run it.

### Gate 1 — Scope (pointer, not owned here)

If this task already has a plan file or an `agent-loop` tier, use that
scope — do not re-scope from scratch. Otherwise state the done-condition in
one or two sentences before proceeding (same bar as `agent-loop-lite`'s
30-second preflight).

### Gate 2 — Evidence (owned here)

Generalizes `systematic-debugging`'s evidence-first discipline beyond bugs,
to research, design, and recommendation tasks: don't reason from memory or
training about anything checkable. Verify a referenced file, function,
config value, or claim in its *current* state before reasoning about it.

Partial recognition from training does not mean current knowledge — a
prompt implying a file is present doesn't mean one is. Check that things
actually exist before building an argument on top of them.

### Gate 3 — Attack (owned here)

One explicit devil's-advocate pass against your own plan, in-context,
before executing it:

- Name the weakest assumption the plan depends on.
- Name the likeliest failure mode.
- Name the signal that would prove the plan wrong.

Skip this gate if `three-brain`'s MUST-FIRE adversarial route already fired
for this same task (auth/billing/secrets paths, or an explicit "tear apart
this" request) — that's a second, independent-model adversarial pass;
stacking a self-attack on top of it is redundant, not extra safety.

### Gate 4 — Verify (pointer, not owned here)

Before declaring done, run `verification-before-completion`'s gate function.
Do not reimplement it here — that skill is canonical for this repo.

### Gate 5 — Report (owned here)

Close with calibrated confidence, not flat certainty. Tag each material
claim: **verified** (you ran/read/checked it this turn), **inferred** (
followed from something verified), or **assumed** (unconfirmed — name it).
Name what wasn't checked. Stay ponytail-terse: structured tags, not
prose paragraphs defending the tags.

## Workflow sub-agent application

A Workflow script can't invoke a skill mid-script — sub-agents are
prompted via plain strings. To apply fable mode to a hard Workflow stage,
embed this block directly in that stage's `agent()` prompt:

```
Before proposing anything: verify the files/state you're reasoning about
actually exist as described (Evidence). Before executing your plan: name
its weakest assumption and the signal that would prove it wrong (Attack).
Before reporting done: tag each claim verified/inferred/assumed (Report).
```

When the stage delegates to a cheaper tier than the orchestrator, consult
`docs/ultracode-model-tiers.md` Table C to justify the choice, and `log()`
a one-line delegation receipt: tier chosen, why, outcome. This is the same
proof pattern as a $1.47 → $0.56 cost drop at equal accuracy — the receipt
is what makes "cheaper tier, same quality" a checkable claim instead of a
guess.

## Non-goals

- Not a replacement for `three-brain` — cross-vendor, post-hoc diff review
  stays there.
- Not a replacement for `agent-loop` tiers — task-complexity classification
  stays there.
- Not always-on like `ponytail` — this is opt-in, hard-task-only.

## Boundaries

"stop fable mode" / task resolved: gates stop applying. Does not change how
you talk (pair with Caveman for terse prose, ponytail for terse code) — it
governs reasoning discipline, not output format.
