# File Consolidation & Structural Health

Detailed heuristics and examples for Phase 3 of the audit.

## Merge Heuristics — Fragmented Files

### When to merge
- **Same-domain cluster:** 3+ files in the same directory with related names (e.g., `format-date.ts`, `format-currency.ts`, `format-number.ts`) → merge into `formatters.ts`
- **Tiny files:** Files under 30 LOC with a single exported function, especially if they share imports
- **Shared consumers:** Multiple small files all imported by the same parent module
- **One-liner re-exports:** Files that only re-export from another file with no added logic

### When NOT to merge
- Files with different test coverage strategies (unit vs integration)
- Files that change at very different frequencies (stable utils vs actively-developed features)
- Files used by different build targets (server-only vs client-only)
- Files with different dependency trees (merging would pull heavy deps into lightweight modules)

### Grep patterns for detection
```
# Find directories with many small files
# Count exports per file — single-export files are merge candidates
Grep: ^export (function|const|class|type|interface|enum)
```
Then cross-reference file sizes. Directories with 5+ files averaging <30 LOC each are strong candidates.

## Duplicate Logic Detection

### Finding near-identical functions
1. **Name-based:** Grep for function names with common prefixes/suffixes across files:
   ```
   Grep: export (async )?function (get|fetch|create|update|delete|format|parse|validate)
   ```
   Group matches by verb — multiple `getUser`-like functions across files often contain duplicate logic.

2. **Signature-based:** Functions with identical parameter lists and return types in different files:
   ```
   Grep: \(workspace_id: string|workspaceId: string
   ```
   Repeated parameter patterns suggest shared data-fetching logic that should be centralized.

3. **Body-based:** Look for repeated patterns:
   - Identical Supabase query chains (`.from('table').select('*').eq(...)`)
   - Identical error handling blocks (try/catch with same shape)
   - Identical auth-check preambles (`const { user } = await getAuthContext()`)

### Consolidation targets
| Pattern | Consolidate into |
|---------|-----------------|
| Repeated Supabase queries for same table | `lib/services/{entity}.ts` |
| Repeated auth checks | Middleware or shared `withAuth()` wrapper |
| Repeated Zod schemas for same shape | `lib/schemas/{entity}.ts` |
| Repeated formatting functions | `lib/utils/formatters.ts` |
| Repeated error response builders | `lib/utils/api-response.ts` |

## Directory Structure Patterns

### Feature-based (recommended for app code)
```
app/
  contacts/
    page.tsx
    ContactList.tsx
    ContactForm.tsx
    useContacts.ts
    contacts.schema.ts
  deals/
    page.tsx
    DealPipeline.tsx
    useDeal.ts
```
Components, hooks, and schemas co-located with the feature they serve.

### Type-based (acceptable for shared libraries)
```
lib/
  hooks/
    useContacts.ts
    useDeals.ts
  schemas/
    contacts.schema.ts
    deals.schema.ts
  services/
    contacts.service.ts
    deals.service.ts
```

### What to flag
- **Mixed strategies:** Feature-based in `app/` but hooks scattered in `lib/hooks/` instead of co-located. Choose one pattern and be consistent.
- **Orphaned directories:** Directories with a single file that could live one level up.
- **Deep nesting:** More than 4 directory levels for non-route files suggests over-organization.
- **Unclear naming:** Directories like `helpers/`, `misc/`, `common/`, `shared/` with unrelated contents — split by domain.

## Barrel File Decision Tree

```
Is it an index.ts that re-exports?
├─ Re-exports a SINGLE file → REMOVE (import directly)
├─ Re-exports from sub-barrels (barrel-of-barrels) → REMOVE (causes bundling issues, circular deps)
├─ Re-exports everything with `export *` from 5+ files → REVIEW
│   ├─ Used by external consumers (public API) → KEEP but audit for unused exports
│   └─ Only used internally → SIMPLIFY to named exports only
├─ Selectively re-exports (curated public API) → KEEP
└─ Adds logic beyond re-exporting → Not a barrel, leave it alone
```

### Barrel anti-patterns
- `export * from './a'; export * from './b';` — name collision risk, tree-shaking issues
- Barrel files that import and re-export heavy dependencies — forces the dep to load even when only lightweight exports are needed
- Circular barrel chains: `a/index.ts` → `b/index.ts` → `a/index.ts`

### Grep pattern
```
Grep: ^export \* from|^export \{.*\} from
```
In `index.ts` files. Count re-exports vs direct exports to classify.

## Circular Dependency Detection

### Symptoms
- `ReferenceError: Cannot access 'X' before initialization` at runtime
- TypeScript `any` inference where a concrete type is expected
- Webpack/Turbopack warnings about circular dependencies

### Detection approach
1. Use bundler output — both webpack and Turbopack warn about circular imports
2. Manual trace: for suspicious modules, follow the import chain:
   ```
   A imports B → B imports C → C imports A  (cycle!)
   ```

### Resolution patterns
| Cycle type | Fix |
|-----------|-----|
| Shared types | Extract types into a leaf `types.ts` file that both modules import |
| Shared constants | Extract into `constants.ts` |
| Mutual function calls | Introduce a third module or use dependency inversion (pass function as parameter) |
| Component circular import | Restructure with composition — parent passes child via props/children |

## Monorepo Considerations

When `turbo.json`, `pnpm-workspace.yaml`, or `package.json#workspaces` exists:

- [ ] **Cross-package duplication:** Same utility functions defined in multiple packages. Consolidate into a shared `packages/shared/` or `packages/utils/` package.
- [ ] **Version drift:** Different packages pinning different versions of the same dependency. Align versions.
- [ ] **Shared package extraction:** If 3+ packages import the same set of utilities, those utilities should be a shared package.
- [ ] **Internal package boundaries:** Shared packages should have a clean public API (barrel file with curated exports), not `export *` of everything.

## Safety Checklist — After Consolidation

After any file moves, merges, or restructuring:

- [ ] **Update all imports:** Grep for the old file path and update every import statement.
- [ ] **Check dynamic imports:** `React.lazy(() => import('./old-path'))` and `next/dynamic` calls use string paths that static analysis may miss.
- [ ] **Update barrel files:** If moved files were re-exported through an `index.ts`, update or remove the barrel.
- [ ] **Run TypeScript check:** `npx tsc --noEmit` to catch broken imports.
- [ ] **Run build:** `npx next build` to catch SSR/bundling issues.
- [ ] **Run tests:** Verify no test imports broke.
- [ ] **Check path aliases:** `tsconfig.json` path aliases (`@/components/*`) may need updating if directory structure changed.
- [ ] **Verify git diff:** Review the diff to ensure no logic was accidentally changed during the move — consolidation should be behavior-preserving.
