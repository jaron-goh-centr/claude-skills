# CENTR Test Layers — Detailed Specifications

## Layer 1: Static Analysis (Pre-Commit, ~5 seconds)

**Catches:** Type mismatches, schema drift, malformed data shapes — roughly 30-40% of all bugs before a single test runs.

**Setup:**
1. Enforce `strict: true` in `tsconfig.json` with `noUncheckedIndexedAccess: true`
2. Place Zod schemas on every Supabase Edge Function input AND output boundary
3. Run ESLint with `@typescript-eslint/strict` ruleset
4. Wire all three into pre-commit hook (husky + lint-staged)

**Zod boundary pattern:**

```typescript
import { z } from "zod";

const InputSchema = z.object({
  leadId: z.string().uuid(),
  action: z.enum(["enrich", "qualify", "archive"]),
});

const OutputSchema = z.object({
  success: z.boolean(),
  data: z.record(z.unknown()).optional(),
  error: z.string().optional(),
});

// Validate input at entry
const parsed = InputSchema.safeParse(requestBody);
if (!parsed.success) {
  return new Response(JSON.stringify({ success: false, error: parsed.error.message }), { status: 400 });
}

// Validate output before returning
const response = OutputSchema.parse(result);
return new Response(JSON.stringify(response));
```

**Key rule:** If data crosses a boundary (client <-> server, server <-> Supabase, server <-> Claude API), it must pass through a Zod schema. No exceptions.

**Debug hint:** If a bug involves "wrong data shape" or "undefined is not an object" — the fix is almost always a missing Zod boundary, not a logic error. Add the schema first, then fix whatever it catches.

---

## Layer 2: RLS Policy Tests (Pre-PR, ~30 seconds)

**Catches:** Access control bugs — the most dangerous class in multi-tenant Supabase apps.

Test against four personas minimum:
1. **Unauthenticated** — should see nothing
2. **Wrong-tenant user** — authenticated but different workspace — should see nothing
3. **Correct-tenant user** — should see only their workspace rows
4. **Admin** — should see their workspace rows plus admin-only fields/actions

**Test pattern:**

```sql
-- Test: user from workspace_a cannot see workspace_b leads
SET request.jwt.claims = '{"sub": "user-a-id", "workspace_id": "workspace-a"}';

SELECT count(*) FROM leads WHERE workspace_id = 'workspace-b';
-- ASSERT: count = 0

-- Test: user from workspace_a CAN see their own leads
SELECT count(*) FROM leads WHERE workspace_id = 'workspace-a';
-- ASSERT: count > 0

-- Test: unauthenticated user sees nothing
RESET role;
SET role TO 'anon';
SELECT count(*) FROM leads;
-- ASSERT: count = 0
```

**Run against:** Local Supabase instance (`supabase start`) with seeded test data covering at least two workspaces.

**Key rule:** Every new table with RLS gets a policy test before the PR merges. Non-negotiable for multi-tenant deployments.

**Debug hint:** If a bug involves "user can see data they shouldn't" or "user can't see data they should" — go directly to RLS policy tests. Do not debug application code first.

---

## Layer 3: Integration Tests (PR Pipeline, ~2-3 minutes)

**Catches:** The majority of real bugs — "does this API route correctly query Supabase, apply RLS, transform the data, and return the right shape?"

Use Vitest with actual Supabase client calls against a local Supabase instance. For each Edge Function or API route:
1. Seed test data into the local database
2. Authenticate as different users
3. Call the function
4. Assert happy path (correct data, correct shape)
5. Assert permission-denied path (wrong user gets 403, not wrong data)
6. Assert edge cases (empty inputs, missing optional fields, concurrent requests)

**Test pattern:**

```typescript
import { describe, it, expect, beforeAll } from "vitest";
import { createClient } from "@supabase/supabase-js";

describe("Lead Enrichment Edge Function", () => {
  let clientA: SupabaseClient; // workspace A user
  let clientB: SupabaseClient; // workspace B user

  beforeAll(async () => {
    clientA = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${tokenA}` } },
    });
    clientB = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${tokenB}` } },
    });
    await seedLeads(clientA, "workspace-a", 5);
    await seedLeads(clientB, "workspace-b", 3);
  });

  it("returns enriched lead for correct workspace user", async () => {
    const { data, error } = await clientA.functions.invoke("enrich-lead", {
      body: { leadId: "lead-a-1" },
    });
    expect(error).toBeNull();
    expect(data.success).toBe(true);
    expect(data.data).toHaveProperty("enrichedAt");
  });

  it("rejects request from wrong workspace user", async () => {
    const { data, error } = await clientB.functions.invoke("enrich-lead", {
      body: { leadId: "lead-a-1" },
    });
    expect(error).not.toBeNull();
    expect(data?.data).toBeUndefined();
  });

  it("handles missing lead gracefully", async () => {
    const { data } = await clientA.functions.invoke("enrich-lead", {
      body: { leadId: "nonexistent-uuid" },
    });
    expect(data.success).toBe(false);
    expect(data.error).toContain("not found");
  });
});
```

**Key rule:** Every Edge Function gets at least three integration tests: happy path, wrong-user path, and malformed-input path.

**Debug hint:** If a bug involves "API returns wrong data" or "feature works for me but not for the client" — write an integration test that reproduces the exact scenario first, then fix it.

---

## Layer 4: AI Output Contract Tests (PR Pipeline, ~1-2 minutes)

**Catches:** Malformed AI responses, hallucinated fields, PII leakage, missing confidence indicators, outputs that bypass human-in-the-loop.

**Contracts to test for every AI feature:**

| Contract | What to Assert |
|---|---|
| Schema compliance | Response parses against the Zod schema for that feature |
| No PII leakage | Response doesn't contain PII from the prompt (emails, phone, NRIC) |
| Confidence indicator | Response includes required confidence/grounding field |
| Token budget | Response is under defined max token limit |
| Human-in-the-loop | AI output stored as draft, NOT written to production table |
| Fallback behaviour | Malformed JSON caught by Zod boundary, returns safe error |
| Model degradation | API 500/timeout degrades gracefully (error shown, not crash) |

**Test pattern:**

```typescript
import { describe, it, expect } from "vitest";
import Anthropic from "@anthropic-ai/sdk";
import { LeadEnrichmentOutputSchema } from "@/schemas/ai";

const client = new Anthropic();

describe("AI Lead Enrichment Contract", () => {
  it("output matches schema", async () => {
    const response = await client.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1000,
      messages: [{ role: "user", content: TEST_ENRICHMENT_PROMPT }],
    });
    const text = response.content[0].type === "text" ? response.content[0].text : "";
    const parsed = LeadEnrichmentOutputSchema.safeParse(JSON.parse(text));
    expect(parsed.success).toBe(true);
  });

  it("does not leak PII from prompt", async () => {
    const promptWithPII = `Enrich this lead: John Doe, john@test.com, +65 9123 4567, NRIC S1234567A`;
    const response = await client.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1000,
      system: SYSTEM_PROMPT_WITH_PII_GUARD,
      messages: [{ role: "user", content: promptWithPII }],
    });
    const text = response.content[0].type === "text" ? response.content[0].text : "";
    expect(text).not.toContain("S1234567A");
  });

  it("stores output as draft, not production record", async () => {
    const result = await triggerEnrichment(clientA, "lead-a-1");
    const { data: draft } = await clientA
      .from("ai_drafts")
      .select()
      .eq("source_id", "lead-a-1")
      .single();
    expect(draft).not.toBeNull();
    expect(draft.status).toBe("pending_review");
    const { data: lead } = await clientA
      .from("leads")
      .select("updated_at")
      .eq("id", "lead-a-1")
      .single();
    expect(lead.updated_at).toBe(ORIGINAL_UPDATED_AT);
  });
});
```

**Key rule:** Every AI feature needs a contract test proving the Zod boundary catches bad output AND human-in-the-loop is enforced.

**Debug hint:** If "AI returned something weird" or "AI feature crashed" — check Zod boundary first. Missing or too-loose schema is usually the bug.

---

## Layer 5: Component Tests (PR Pipeline, ~30 seconds)

**Catches:** Complex UI state bugs — multi-step forms, approval workflows, pipeline transitions, AI chat interfaces.

Do NOT unit-test every React component. Test only the 10-15 with the most complex interaction logic.

**Components that always need tests:**
- Pipeline/kanban stage transition components
- Multi-step approval workflows (AI draft -> review -> approve -> save)
- AI chat/copilot interfaces (message submission, streaming, error states)
- Form components with conditional logic or dependent fields
- Permission-gated UI elements (buttons disabled based on role)

**Test pattern:**

```typescript
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { ApprovalWorkflow } from "@/components/ApprovalWorkflow";

describe("ApprovalWorkflow", () => {
  it("transitions from draft to approved on approve click", async () => {
    render(<ApprovalWorkflow draft={mockDraft} />);
    expect(screen.getByText("Pending Review")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: /approve/i }));
    await waitFor(() => {
      expect(screen.getByText("Approved")).toBeInTheDocument();
    });
  });

  it("shows rejection reason field on reject", async () => {
    render(<ApprovalWorkflow draft={mockDraft} />);
    fireEvent.click(screen.getByRole("button", { name: /reject/i }));
    await waitFor(() => {
      expect(screen.getByPlaceholderText(/reason/i)).toBeInTheDocument();
    });
  });
});
```

**Key rule:** Test user-visible behaviour, not implementation details. Skip pure presentational components.

**Debug hint:** If component test passes but bug exists in production, the bug is in the data layer — go to Layer 3.

---

## Layer 6: E2E Tests (Merge to Main, ~5-8 minutes)

**Catches:** Full user journey breakages.

Playwright for 5-10 most critical journeys only. Do not try to cover everything.

**Critical paths for a typical CENTR build:**
1. Authentication flow — login -> redirect -> correct workspace loaded
2. Primary CRUD cycle — create lead -> view -> edit -> delete
3. AI-assisted workflow — trigger AI enrichment -> review draft -> approve -> record saved
4. Pipeline progression — move deal through stages -> verify stage-specific rules
5. Invoice/payment flow (if applicable) — generate invoice -> mark paid -> reconcile

**Test pattern:**

```typescript
import { test, expect } from "@playwright/test";

test("AI enrichment -> review -> approve flow", async ({ page }) => {
  await page.goto("/login");
  await page.fill('[name="email"]', "test@workspace-a.com");
  await page.fill('[name="password"]', "test-password");
  await page.click('button[type="submit"]');
  await page.waitForURL("/dashboard");

  await page.click('text=Leads');
  await page.click('text=Acme Corp');

  await page.click('button:has-text("Enrich with AI")');
  await page.waitForSelector('[data-testid="ai-draft-panel"]');

  expect(await page.textContent('[data-testid="draft-status"]')).toBe("Pending Review");

  await page.click('button:has-text("Approve")');
  await page.waitForSelector('text=Enrichment applied');

  expect(await page.textContent('[data-testid="enriched-badge"]')).toBe("Enriched");
});
```

**Key rule:** If an e2e test is flaky, fix it or delete it. Flaky e2e tests are worse than no tests.

**Debug hint:** If a production bug can't be reproduced in integration tests — it's usually timing, race condition, or browser-specific. Write a Playwright test. If Playwright can't reproduce it either, check deployment config, CDN caching, SSR hydration.

---

## Layer 7: AI Regression & Drift Tests (Weekly + Model Upgrades)

**Catches:** Behavioural drift when Claude or Gemini models are updated.

**Harness structure:**

```
tests/ai-regression/
  enrichment/
    inputs.json          # 20-30 representative lead inputs
    contracts.ts         # Zod schemas + assertion functions
    baseline-results.json # Last known-good outputs (structure only)
  copilot/
    inputs.json
    contracts.ts
    baseline-results.json
  run-regression.ts      # Runner that hits the AI, asserts contracts
```

**What to assert (structural, not exact):**
- Output still parses against Zod schema
- Required fields still present
- Confidence scores within expected range
- Response length within +/-50% of baseline
- No new PII leakage patterns
- Tone/format hasn't shifted dramatically (section count, bullet count)

**What to flag for manual review (not auto-fail):**
- Significant structure changes even if schema-valid
- New patterns in reasoning or recommendations
- Changes in how model handles ambiguous inputs

**Key rule:** Assert contracts, not content. Model can change phrasing — it cannot change structure, violate safety constraints, or break the schema.

---

## CI Pipeline Configuration

```yaml
# .github/workflows/test.yml
name: Test Pipeline

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

jobs:
  static:
    name: Static Analysis
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npx tsc --noEmit
      - run: npx eslint . --max-warnings 0
      - run: npx vitest run tests/schemas

  rls:
    name: RLS Policy Tests
    runs-on: ubuntu-latest
    needs: static
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
      - run: supabase start
      - run: supabase db test

  integration:
    name: Integration + Contract Tests
    runs-on: ubuntu-latest
    needs: rls
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
      - run: supabase start
      - run: npm ci
      - run: npx vitest run tests/integration
      - run: npx vitest run tests/ai-contracts
    env:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY_TEST }}

  components:
    name: Component Tests
    runs-on: ubuntu-latest
    needs: static
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npx vitest run tests/components

  e2e:
    name: E2E Critical Paths
    runs-on: ubuntu-latest
    needs: [integration, components]
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
      - run: supabase start
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npx playwright test
```

**Weekly cron (AI regression):**

```yaml
  ai-regression:
    name: AI Drift Detection
    runs-on: ubuntu-latest
    schedule:
      - cron: '0 6 * * 1'  # Every Monday 6 AM UTC
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npx vitest run tests/ai-regression
      - run: node tests/ai-regression/compare-baseline.js
    env:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY_TEST }}
```
