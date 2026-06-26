# Architectural Invariant Audit Patterns

This file expands Phase 3.5 of the audit skill. Each project's CLAUDE.md / constitution defines non-negotiable invariants. This resource translates the most common ones into detection patterns.

## Workflow

1. Read CLAUDE.md, AGENTS.md, project constitution, and `~/.claude/projects/<slug>/memory/MEMORY.md` plus any `feedback_*.md`.
2. For each `must`, `must not`, `non-negotiable`, `banned`, `always`, `never` directive, write a grep query.
3. Run all queries in a batch.
4. Report violations with citation back to the source rule (file path + line number from the constitution).

---

## Pattern Catalog

### Provider Adapter Pattern

> Rule: External services accessed via `lib/adapters/`. UI never knows the provider.

**Detection:**
```
# UI components importing concrete SDK
rg -l "'use client'" app/ src/ | xargs rg -l "from ['\"]@(anthropic-ai|openai|stripe|postmark)"
```
Any match = violation.

### RLS on All Tables

> Rule: Every `CREATE TABLE` paired with `ENABLE ROW LEVEL SECURITY` and at least one policy.

**Detection (static):**
```
# tables in migrations
rg "create table\s+(?!if not exists\s+)?(\w+)" -or '$1' supabase/migrations/

# RLS-enabled tables
rg "alter table\s+(\w+)\s+enable row level security" -or '$1' supabase/migrations/
```
Diff first list against second. Tables in first not in second = violation.

**Detection (live DB):**
```sql
select schemaname, tablename
from pg_tables
where schemaname = 'public'
  and tablename not in (select tablename from pg_tables where rowsecurity = true);

-- RLS-enabled but no policies
select c.relname
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relrowsecurity = true
  and n.nspname = 'public'
  and not exists (
    select 1 from pg_policies p
    where p.tablename = c.relname
  );
```

### Optimistic Mutations Always

> Rule: Every user-initiated write updates UI in <16ms. No spinners on user-initiated changes.

**Detection:**
```
# useMutation calls without onMutate (TanStack Query optimistic pattern)
rg "useMutation\(\{" -A 20 | rg -B 0 -A 15 "useMutation\(\{" | grep -L "onMutate"
```
Manual verification: each `useMutation` in user-write flows should have `onMutate` + `onError` rollback.

### Workspace / User Scoping on Queries

> Rule: All queries scoped to `workspace_id` (or `user_id`). RLS is the safety net, not the primary check.

**Detection:**
```
# Supabase queries that don't .eq() workspace_id or user_id
rg "from\(['\"](\w+)['\"]\)" -A 5 src/ apps/ | rg -B 5 "\.select\(" | grep -v "\.eq\("
```
False positives: list endpoints that intentionally return public data. Cross-ref with project's "public tables" list.

### No Inline Side Effects

> Rule: Domain mutations dispatch events to a queue/bus. No inline emails, push notifications, third-party API calls.

**Detection:**
```
# Mutation handlers with inline side-effect calls
rg -l "from ['\"]@(postmark|twilio|sendgrid|webpush)" src/lib/services/

# Or AI calls inside mutation handlers (should be queued)
rg -B 5 -A 30 "messages\.create\(" src/lib/services/ | grep -E "(insert|update|delete)\("
```

### No Conditional Gates on Universal Operations (LIFE global)

> Rule: Verification / ID resolution / connection validation runs unconditionally. NEVER gated behind `isRemote`, `isSelf`, `isSameUrl`, role checks.

**Detection:**
```
rg -B 2 -A 5 "if\s*\(.*(isRemote|isSelf|isSameUrl|isProduction).*\)\s*\{" src/
```
Manual review: confirm what's inside the gate. If it's a verification call, that's a violation.

### Audit Log Coverage

> Rule: Every CUD + AI call writes to `audit_logs`.

**Detection:**
```
# Service files with INSERT/UPDATE/DELETE
rg -l "\.(insert|update|delete)\(" src/lib/services/

# Of those, check for auditLog import
rg -L "auditLog|audit_logs" $(rg -l "\.(insert|update|delete)\(" src/lib/services/)
```
Diff = uncovered services.

### Provider Tier Resolution

> Rule: Model IDs resolve from tier (`fast` / `smart` / `reasoning`). Hardcoded model IDs bypass tier policy.

**Detection:**
```
# Hardcoded Anthropic / OpenAI model strings in route handlers
rg "['\"]claude-(opus|sonnet|haiku)-[0-9]+(-[0-9]+)*['\"]" src/app/ src/lib/
rg "['\"]gpt-(4o?|3\.5)['\"]" src/app/ src/lib/
```
Allowed: `lib/ai/models.ts` (the resolution map itself).

### No Banned Patterns (LIFE example)

```
rg "font-family.*Inter|: any\b|h-screen|window\.addEventListener\(['\"]scroll|ease-in-out|ease-linear" src/ apps/
```

### Optimistic Mutation Completeness

> Rule: Optimistic update payload must match server response shape.

**Detection (manual):** For each `onMutate`, compare returned object to the mutation's response type. Mismatched fields cause flicker.

### Three-Layer Data Stack (LIFE)

> Rule: Client cache (TanStack Query) → Realtime (WebSocket surgical patches) → Persistence (Supabase + RLS).

**Detection:**
```
# Realtime subscriptions doing full refetch instead of surgical patch
rg "supabase\.channel" -A 30 src/ | grep "queryClient.invalidateQueries"
```
Should use `queryClient.setQueryData` for surgical patches.

### Field-Level Provenance

> Rule: Enriched fields stored as `{ value, source, confidence, fetched_at }`.

**Detection:** TypeScript types for enriched entities should reference `Provenance<T>` or equivalent. Bare primitive types on enriched fields = violation.

---

## Surgical-Change Rule

For audits scoped to recent commits:

```
# What did the commit say it changed?
git log -1 --format=%B HEAD

# What actually changed?
git diff HEAD~1 --stat
```

Diff the two. Files modified beyond the commit message scope = unrequested edits → flag as violations of the "surgical changes" rule.

---

## Regression Preservation

For each function modified in audit scope:

1. Get the prior version: `git show HEAD~1:path/to/file.ts`
2. Extract the function's contract: signature, return shape, side effects, error paths.
3. Diff the new version. Any branch silently dropped = regression.
4. If unsure whether a branch was intentionally removed, route to Codex.

This is partly mechanical (signature changes) and partly semantic (was that early-return there for a reason?). Lean on Codex for the semantic side.
