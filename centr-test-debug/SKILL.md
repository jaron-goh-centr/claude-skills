---
name: centr-test-debug
description: "Defines the canonical test sequence and debugging methodology for CENTR's AI-enabled applications (Next.js 16 + Supabase + Claude API + RLS). Activates when the user mentions 'test', 'testing', 'debug', 'debugging', 'bug', 'fix bug', 'write tests', 'test strategy', 'QA', 'regression', 'flaky test', 'e2e test', 'integration test', 'unit test', 'RLS test', 'AI output test', 'contract test', 'drift test', 'test harness', 'test pyramid', 'CI pipeline tests', 'full debug sequence', or wants to add, fix, or improve tests. Also triggers when diagnosing production bugs, investigating unexpected AI behaviour, verifying RLS policies, testing Edge Functions, validating AI output contracts, or performing systematic debugging."
---

# CENTR Test & Debug Strategy

## When to use this skill
- User asks to run a "full debug sequence" or "debug sequence"
- Diagnosing any bug, test failure, or unexpected behaviour
- Adding, fixing, or improving tests for any part of the stack
- Setting up CI test pipelines
- Verifying RLS policies or testing Edge Functions
- Validating AI output contracts or investigating AI drift
- Any mention of: test, debug, QA, regression, flaky, e2e, integration, unit, RLS test, contract test, drift test

## Stack Assumptions

| Layer | Technology |
|---|---|
| Frontend | Next.js 16 + React 19 + TypeScript + Tailwind CSS + shadcn/ui |
| Backend/DB | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| AI | Claude API (Anthropic) + Google Gemini + heuristic fallbacks |
| Security | RLS, Zod validation, AES-256-GCM, CSP headers |
| Auth | Supabase Auth + Google Workspace SSO (SAML) |
| Test runner | Vitest (unit + integration + contract), Playwright (e2e), pgTAP (RLS) |

## The Diamond Model

The standard test pyramid (unit > integration > e2e) was designed for deterministic CRUD apps. CENTR's stack requires a **diamond shape**: thin at static/unit level, fat in the middle (integration + contract), thin-but-critical at e2e, with an AI-specific layer on top.

## Workflow: The Meta-Sequence

Execute layers in this exact order — cheapest/fastest to most expensive/slowest:

- [ ] **Layer 1: Static Analysis** (~5s) — Types, Zod schemas, ESLint. Pre-commit.
- [ ] **Layer 2: RLS Policy Tests** (~30s) — pgTAP tests for row-level access. Pre-PR.
- [ ] **Layer 3: Integration Tests** (~2-3min) — Vitest + real local Supabase. PR pipeline.
- [ ] **Layer 4: AI Output Contract Tests** (~1-2min) — Schema compliance, PII guard, human-in-the-loop enforcement. PR pipeline.
- [ ] **Layer 5: Component Tests** (~30s) — React Testing Library for complex UI state only. PR pipeline.
- [ ] **Layer 6: E2E Tests** (~5-8min) — Playwright for 5-10 critical user journeys. Merge to main.
- [ ] **Layer 7: AI Regression & Drift Tests** (weekly) — Structural contract comparison against baseline. Weekly cron + model upgrades.

[See LAYERS.md for detailed specifications, code patterns, and examples for each layer.](LAYERS.md)

## Debugging Decision Tree

When a bug is reported, follow this tree to find the correct starting layer:

```
Bug reported
|
+-- "User sees data they shouldn't" / "User can't see their data"
|   -> Layer 2 (RLS). Do NOT touch application code first.
|
+-- "API returns wrong data" / "Feature works for me but not client"
|   -> Layer 3 (Integration). Write test reproducing the scenario.
|
+-- "AI returned something weird" / "AI feature crashed"
|   +-- Check: Is Zod boundary in place? If no, that IS the bug.
|   +-- Check: Did model version change? Run Layer 7 regression.
|   +-- Otherwise -> Layer 4 (AI Contract). Tighten the contract.
|
+-- "Button doesn't work" / "UI shows wrong state"
|   +-- Reproduce in Layer 5 (Component test).
|   +-- If passes -> Bug is in data layer, go to Layer 3.
|
+-- "Whole flow is broken" / "Client can't complete [journey]"
|   -> Layer 6 (E2E). Write Playwright test for the exact journey.
|
+-- "AI used to work, now it doesn't" / "AI answers changed"
|   -> Layer 7 (Drift). Check model version, run regression.
|
+-- "Type error" / "undefined is not a function" / "wrong shape"
    -> Layer 1 (Static). Add missing Zod boundary.
```

## Quick Reference: When to Run What

| Trigger | Layers to Run | Time Budget |
|---|---|---|
| Every commit (pre-commit) | Layer 1 | ~5 seconds |
| Every PR | Layers 2-5 | ~3-4 minutes |
| Merge to main | Layers 1-6 | ~8-10 minutes |
| Weekly (Monday cron) | Layer 7 | ~5 minutes |
| Model version upgrade | Layers 4 + 7 | ~10 minutes |
| New table with RLS | Layer 2 for that table (mandatory before merge) | ~30 seconds |
| New AI feature | Layer 4 contract tests (mandatory before merge) | ~1-2 minutes |
| Production bug reported | Follow Debugging Decision Tree above | Varies |

## Anti-Patterns to Avoid

1. **Testing AI for exact output** — Claude is non-deterministic. Never `expect(response).toBe("exact string")`. Assert structure and constraints only.
2. **Skipping RLS tests** — RLS is last line of defence. The app can have bugs; RLS must not.
3. **E2E testing everything** — Cover 5-10 critical paths only. If flaky, fix or delete.
4. **Mocking Supabase in integration tests** — Use `supabase start` for real local instance. Mock only external APIs you don't control.
5. **No fallback tests for AI** — Always test Claude 500, timeout, and malformed JSON paths.
6. **Ignoring human-in-the-loop contract** — AI writing directly to production tables without draft/review is a bug regardless of output quality.
7. **Running AI contract tests with expensive models** — Use Haiku for test runs. Contracts should be model-agnostic.

## CORTEX-Specific Testing (When Applicable)

For CORTEX orchestrator deployments, add:

**Governance Policy Tests:**
- Intern-level agents CANNOT execute without human review
- Trust level promotion requires all threshold conditions
- Demotion triggers immediately on threshold violation
- Kill switches take effect on the next request cycle

**Learning Pipeline Tests:**
- Rules below confidence threshold auto-downgrade
- Provisional rules require 5+ occurrences before activation
- Human overrides recorded and fed into learning pipeline
- No learned rule can modify its own agent's trust level or permissions

## CI Pipeline

[See LAYERS.md for complete CI workflow configuration.](LAYERS.md)
