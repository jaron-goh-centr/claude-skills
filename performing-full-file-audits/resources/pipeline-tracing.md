# Pipeline Integrity Tracing

Companion to Phase 2.5 of the audit skill. The single highest-frequency root cause of subtle bugs across LIFE, CENTR, and similar Next.js + Supabase projects is a field silently changing or vanishing as it travels through the request/response pipeline.

This document gives the procedure plus retros of real bug patterns the audit should catch.

---

## The 9 Layers of a Field

For any field `f` (e.g. `tier`, `user_id`, `amount_cents`, `status`):

1. **UI form** — input control bound to `f` via `react-hook-form` or controlled state.
2. **Mutation hook** — `useMutation` / `useApi` builds the request body. Watch for omitted fields when re-using an `editForm` for a `create` flow.
3. **API request** — `fetch('/api/...', { body: JSON.stringify(body) })`. Network DevTools shows what was sent.
4. **Zod schema** — server route's `z.object({...})`. Fields not in schema get stripped silently if `.strip()` (default).
5. **params interface / DTO** — TypeScript interface used inside the route. If field is not on this interface, IntelliSense lets you write code that ignores it.
6. **Service layer** — `await service.update(id, updateData)`. If `updateData` is built field-by-field, any new field requires hand-editing this object.
7. **DB write** — Supabase `.update({...})` or `.insert({...})`. Field must exist as column.
8. **DB read / response** — `.select('field1, field2, ...')`. Specific column lists silently drop fields you didn't request.
9. **UI cache + render** — `queryClient.setQueryData` / re-render. If response shape ≠ optimistic shape, flicker.

A field has to survive ALL nine layers. Drop at any one = bug.

---

## Tracing Procedure

For each anchor field in scope:

```
# Layer 1-3: client side
rg "name=['\"]<field>['\"]"           # form input
rg "<field>:" src/components/ src/hooks/ # mutation builder

# Layer 4: schema
rg "<field>:\s*z\." src/app/api/ src/lib/validators/

# Layer 5-6: service
rg "<field>" src/lib/services/

# Layer 7-8: DB
rg "<field>" supabase/migrations/

# Layer 9: cache
rg "<field>" src/hooks/ src/components/  # render usage
```

If counts are uneven (e.g. field appears in 8 layers but not the service), that's the bug.

---

## Bug Retrospectives

### Retro 1: Subscriptions create bug — missing `user_id` in optimistic update

**Symptom:** Creating a new subscription rolled back immediately with toast error, even though the row was created in DB.

**Trace:**
- Form bound `name`, `amount_cents`, `currency`, `category` (NO user_id).
- Mutation hook called `useOptimisticMutation` with optimistic value omitting `user_id`.
- API route Zod schema correctly required `user_id`.
- Service inserted with auth context's `user.id` — DB row was correct.
- Response returned the full row including `user_id`.
- Optimistic patch's shape ≠ response shape → TanStack Query re-fetched, mismatched, rolled back.

**Audit fix:** Phase 2.5 "Optimistic mutation completeness" — flag any `useOptimisticMutation` call where the optimistic payload is missing fields the response will return.

### Retro 2: Itinerary stale cache shape

**Symptom:** Travel itinerary page returned empty even though DB had rows.

**Trace:**
- API route returned new shape `{ days: [...], summary: {...} }`.
- DB-backed cache layer still held old shape `{ items: [...] }`.
- Client read cache, found `items` undefined, rendered empty.
- No shape check between cache read and render.

**Audit fix:** Phase 2.5 "Cache-shape validation" — every cache read site must Zod-parse or assertion-check the loaded shape, treat parse failure as cache miss.

### Retro 3: Admin tier read/write asymmetry

**Symptom:** Admin sets user tier to `super_admin`, page refreshes, tier shows `free`.

**Trace:**
- PATCH route accepted `tier`, wrote to `profiles.tier`.
- GET detail route read `profiles.role` instead of `profiles.tier` (legacy field).
- Two different fields. Set worked. Read showed legacy value.

**Audit fix:** Phase 2.5 "GET/PATCH symmetry" — for every PATCH-able field, find the corresponding GET handler, confirm it reads the same column.

### Retro 4: Field added to DB but not Zod schema → silent drop on PATCH

**Symptom:** New `notes` column added via migration. UI form sends `notes`. PATCH succeeds. DB row has empty `notes`.

**Trace:**
- Migration added column.
- Service `update(id, updateData)` did `.update(updateData)` — passed through whatever it got.
- Route Zod schema didn't include `notes` → `.parse()` stripped it before reaching service.
- No error because `.strip()` is the default.

**Audit fix:** Phase 2.5 — every DB column should appear in the Zod schema for routes that mutate the table. Use `z.object({...}).strict()` or audit-time grep:

```
# Diff DB columns against Zod schema fields
psql -c "\\d table_name" | awk '/^ /{print $1}'
rg "z\.object\(\{" -A 50 src/app/api/<route>/ | grep ":" | awk '{print $1}'
```

### Retro 5: Realtime patch drift

**Symptom:** Two devices editing the same trip. Device A optimistically updated. Device B got realtime event but its UI didn't reflect Device A's change correctly.

**Trace:**
- Mutation produced shape `{ id, title, start_at, end_at, attendees }`.
- Realtime subscription received the row payload from Postgres CDC.
- Surgical `setQueryData` patch only updated `title`, missed `attendees` (subscriber forgot to map full row).

**Audit fix:** Phase 2.5 "Realtime cache patches mirror writes" — subscription handlers must populate the same shape the mutation produces.

---

## What "Done" Looks Like

For each anchor field traced, the audit should report:

```
field: tier
✓ form (UserEditForm.tsx:42)
✓ mutation hook (useUpdateUser.ts:18)
✓ Zod schema (/api/users/[id]/route.ts:11)
✓ service (lib/services/users.ts:67)
✓ DB column (migrations/0019_add_tier.sql:4)
✓ select clause (lib/services/users.ts:23)
✓ response shape matches optimistic (useUpdateUser.ts:25)
✓ render (TierBadge.tsx:8)
```

A missing checkmark = a bug or near-bug. Report.

---

## Anti-pattern: Spreading Whole Body Through Pipeline

```ts
// route.ts
const body = await req.json();
return service.update(id, body);  // no Zod, no field whitelist
```

This passes static checks (no field is "missing") but enables mass-assignment and silently propagates renames. Always:
1. Zod parse with `.strict()` or explicit field list.
2. Build `updateData` field-by-field in service.
3. Select specific columns on response.

The minor verbosity is the price of pipeline integrity.
