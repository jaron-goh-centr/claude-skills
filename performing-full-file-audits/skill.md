---
name: performing-full-file-audits
description: Performs a comprehensive project workspace review including functional auditing, bloat removal, file consolidation, performance profiling, and security scanning. Covers Next.js/React/TypeScript/Supabase/Tailwind stacks with deep LLM integration auditing. Use when auditing code for quality, performance, cost, or security vulnerabilities — including "polish this project", "production-readiness check", "verify security", "full audit", "code audit", "clean up the workspace". Absorbs the retired auditing-optimizing-securing skill. Includes a mandatory Codex self-review gate (Phase 0.5) when Claude-authored code is in scope. For an adversarial attacker-perspective audit use red-team-security-audit; for over-engineering-only hunts use ponytail-audit.
---

# Full File Audit, Bloat Removal, Consolidation and Security Review

## When to use this skill
- When requested to perform a "full file audit", "comprehensive review", or "code audit".
- When identifying and removing redundant code or unused assets (bloat removal).
- When consolidating fragmented files, deduplicating logic, or restructuring directories.
- When conducting security audits, especially for AI-integrated applications.
- When ensuring a workspace is clean, functional, and secure after a series of major changes.
- When preparing a project for production deployment or handoff.
- When investigating performance issues or unexplained costs.

## Workflow

### Phase 0 — Scope Negotiation
Before starting, determine the audit scope with the user:
- [ ] **Select audit tier:**
  - `quick` — Phases 1-4 only (prep, dead code, consolidation, build verification)
  - `security` — Phases 1, 5, 9 (prep, full security audit, reporting)
  - `performance` — Phases 1, 6, 9 (prep, performance profiling, reporting)
  - `consolidation` — Phases 1-4, 7, 9 (prep, dead code, consolidation, build, file sync, reporting)
  - `full` — All phases (default if user says "full audit" or doesn't specify)
- [ ] **Estimate duration:** Count source files and LOC. `<5K LOC ≈ 15min`, `5-20K ≈ 45min`, `20K+ ≈ 90min + subagents`.
- [ ] **Phase exclusions:** Ask if any phases should be skipped (e.g., "I tested manually, skip functional verification").
- [ ] **Incremental option:** If user wants "audit recent changes", use `git diff --name-only HEAD~N` to scope to changed files + their direct importers.
  - **Always re-audit regardless of diff:** Files matching `auth|middleware|payment|billing|webhook|encryption|admin` in their path — these are high-risk and warrant every-audit coverage.
  - **Risk-based expansion:** If a changed file is imported by an auth/payment module, include that module in scope.

### Phase 0.5 — Self-Review Gate (HARD GATE)
> **Why:** Three-Brain global rule says Claude must NOT review Claude's own output. Same architecture = same blind spots. Self-audit fails to catch what the original author missed.

- [ ] **Detect own-work scope:** Run `git log --author="$(git config user.name)" -10` and check overlap with audit scope. Cross-ref `git diff --name-only HEAD~5` against scope.
- [ ] **If audit scope contains code Claude (you) authored in last 24h:** STOP. Route review to Codex. Example:
  ```
  git diff HEAD~5 | codex exec --skip-git-repo-check "Audit this. Find bugs, security gaps, regressions. Be paranoid."
  ```
  For un-tracked files, pipe content directly: `cat path/to/file | codex exec --skip-git-repo-check "Audit this for ..."`
- [ ] **Integrate Codex findings** as Phase 1 input. Do not start a fresh self-review on top of Codex output.
- [ ] **Skip gate ONLY if user explicitly says** "audit yourself", "skip codex", "run despite same-author" — note the override in the final report.

### Phase 1 — Preparation & Scoping
- [ ] Check `git status` for unexpected uncommitted changes or untracked files.
- [ ] Review recent commits (`git log --oneline -20`) to understand what changed recently.
- [ ] Identify the tech stack (Python/JS/TS, frameworks, DB) to choose the right audit checks.
- [ ] Check for mirrored/duplicated file sets that must stay in sync.
- [ ] **Count total files and LOC** to decide whether to use parallel subagents (threshold: 20+ source files).
- [ ] **Read CLAUDE.md / project docs** if they exist — understand architectural invariants before flagging "violations" that are actually intentional patterns.
- [ ] **Read project memory** at `~/.claude/projects/<slugified-cwd>/memory/MEMORY.md` and any `feedback_*.md` files. Memory may explicitly mark CLAUDE.md rules as stale or overridden (e.g., LIFE's `feedback_keep_dark_mode.md` overrides the "light v1 only" rule). Do NOT re-flag rules that memory says are intentionally violated.
- [ ] **Identify entrypoints:** List all entry files (pages, API routes, middleware, workers, scripts, test runners) so dead code detection doesn't false-positive on them.
- [ ] **Monorepo detection:** Check for `turbo.json`, `pnpm-workspace.yaml`, or `workspaces` in root `package.json`. If monorepo: identify which packages are in scope, map cross-package dependencies, and note shared packages that multiple apps depend on.

### Phase 2 — Import Graph & Dead Code Analysis
This phase catches entire dead files and unused functions — the highest-value cleanup.

> **Caution:** Static grep misses dynamic dispatch (`window[funcName]()`, `React.lazy(() => import(...))`), re-exports via barrel files, and factory/event handler patterns (`subscribe()`, `addEventListener()`). Verify "unused" findings before deleting. Do not flag test helpers/fixtures — test runners import them outside normal import paths.

- [ ] **Dead module detection:** For every file, grep the codebase for its imports. If a module is never imported and is not an entrypoint, flag it for deletion.
  - **Next.js App Router auto-entrypoints:** `page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, `not-found.tsx`, `route.ts`, `middleware.ts`, `global-error.tsx`, `template.tsx` — never flag these.
  - **Config entrypoints:** `tailwind.config.*`, `next.config.*`, `vitest.config.*`, `postcss.config.*`, `components.json`.
- [ ] **Dead function detection:** For each exported function, grep for call sites. Zero callers outside the defining file = flag it.
- [ ] **Dead type/interface detection:** Exported TypeScript types never referenced outside their defining file.
- [ ] **Duplicate definitions:** Functions, constants, or config values defined more than once.
- [ ] **Unused dependencies:** Cross-reference `package.json` against actual imports. Watch for transitive usage (`tailwindcss` in config, `@types/*` used by compiler, `postcss` used by build).
- [ ] **Unused shadcn/ui components:** Components in `components/ui/` never imported by `app/` or other components.
- [ ] **Dead CSS / Tailwind classes:** Custom `@layer` definitions in `globals.css` never referenced in components. (Note: dynamic class construction like `bg-${color}-500` gets purged at build time — flag these too.)
- [ ] **Dead environment variables:** `.env.example` keys vs `process.env.*` usage. Flag vars defined but never read.
- [ ] **TODO/FIXME sweep:** Grep for `@todo`, `TODO`, `FIXME`, `HACK`, `ponytail:` markers — surface as a deferred-work ledger in the report; stale ones (>90 days by git blame) flag for resolution or deletion.

### Phase 2.5 — Pipeline Integrity Tracing
> **Why:** Highest-frequency root cause of subtle bugs is a field silently vanishing across request → Zod → service → DB → response → cache → UI layers. Static checks miss this; only end-to-end tracing catches it.
> Detailed worked examples: [pipeline-tracing.md](resources/pipeline-tracing.md)

For each module touched in scope, trace at least one critical field end-to-end:

- [ ] **Pick anchor fields:** primary key, `workspace_id` / `user_id`, status enum, money fields, AI-generated fields, role/tier.
- [ ] **Trace request path:** UI form → mutation hook → API request body → Zod schema → params interface → service `updateData` / DB INSERT → DB column → SELECT → response shape → UI cache → re-render.
- [ ] **Flag any layer where the field name, type, or nullability silently changes** without explicit transform. Particularly: PATCH route Zod accepts field but service `updateData` object omits it (silent drop).
- [ ] **GET/PATCH symmetry:** GET handler reads same fields PATCH handler writes. Asymmetry produces "set works, refresh wipes" bugs (admin-tier role-read pattern).
- [ ] **Cache-shape validation:** Any layer reading cached data (TanStack Query, Redis, in-memory LRU, server-side memoization) must shape-check on read with Zod or assertion — not assume v1 cache schema is still valid after a deploy.
- [ ] **Optimistic mutation completeness:** Optimistic update payload must include EVERY field server response will return. Missing fields cause rollback flicker even when the write succeeded.
- [ ] **Realtime cache patches mirror writes:** When a realtime event fires, the surgical `setQueryData` patch must populate the same shape the original mutation produced. Drift here = stale UI on multi-device edits.

### Phase 3 — File Consolidation & Structural Health
> Detailed heuristics and examples: [file-consolidation.md](resources/file-consolidation.md)

- [ ] **Fragmented utility files:** Identify clusters of small files (<30 LOC) in the same directory with related exports. Propose merging into cohesive modules.
- [ ] **Duplicate logic:** Grep for near-identical function bodies across files (repeated Supabase query chains, auth preambles, error handlers, Zod schemas). Consolidate into shared utilities in `lib/utils/` or `lib/services/`.
- [ ] **Directory structure audit:** Verify organization follows a consistent pattern (feature-based or type-based). Flag mixed strategies, orphaned directories, and unclear naming (`helpers/`, `misc/`, `common/` with unrelated contents).
- [ ] **Barrel file cleanup:** Audit `index.ts` re-export files. Remove barrels that re-export a single file or that re-export everything from a directory (barrel-of-barrels). Keep barrels that provide a genuine public API surface.
- [ ] **Component co-location:** Components used by a single feature should live in that feature's directory, not in a shared `components/` folder.
- [ ] **Circular dependency detection:** Trace import chains for cycles. Refactor shared types/constants into a leaf module. Check bundler output for circular import warnings.

### Phase 3.5 — Architectural Invariant Audit
> **Why:** Each project's CLAUDE.md / constitution lists non-negotiable invariants (RLS scoping, provider adapter pattern, optimistic mutations, no inline side effects). Generic "good practice" greps don't catch project-specific rule violations.
> Detection patterns: [invariant-audit.md](resources/invariant-audit.md)

- [ ] **Read CLAUDE.md / AGENTS.md / project constitution.** Extract the explicit "must do" / "must not" / "non-negotiable" / "banned patterns" lists.
- [ ] **Generate audit checks from invariants** — turn each rule into a grep query. Examples:
  - "All tables have RLS" → `grep "create table"` cross-ref `enable row level security` + matching policies.
  - "Optimistic mutations always" → `useMutation` calls in user-write paths without `onMutate`.
  - "No inline side effects" → mutation handlers dispatching emails/notifications without going through event bus / queue.
  - "Provider adapter pattern" → UI components importing concrete provider SDK (`from "@anthropic-ai/sdk"` in a `'use client'` file).
  - "No conditional gates on universal ops" → `if (isRemote|isSelf|isSameUrl|isProduction)` wrapping verification calls.
- [ ] **Banned-pattern grep batch:** Compile project's banned-patterns into one grep run. Common LIFE bans: `Inter` font, `: any`, `h-screen`, `window.addEventListener('scroll'`, `ease-in-out`, `ease-linear`, default shadcn `className=""`.
- [ ] **Surgical-change verification:** If audit follows a recent commit, diff vs commit message — flag changes outside the stated scope (rename creep, formatting drift, unrequested refactors).
- [ ] **Regression preservation:** For every modified function in scope, list its prior known behaviors (return shape, side effects, edge-case branches) and verify each still holds. If unsure, route to Codex.

### Phase 4 — Syntax & Build Verification
- [ ] **TypeScript strict mode:** Verify `"strict": true` in `tsconfig.json`. Count `@ts-ignore`, `@ts-expect-error`, `as any` — flag files with excessive use (>3 per file).
- [ ] **TypeScript:** `npx tsc --noEmit` — catch all type errors.
- [ ] **Next.js build:** `npx next build` if feasible — catches SSR errors, missing exports, metadata issues.
- [ ] **Bundler awareness:** Check if dev uses Turbopack vs build uses webpack. If `next.config.ts` has `webpack:` config, verify it's not ignored under Turbopack.
- [ ] **Verify entrypoints:** Confirm main entrypoints still load after any deletions or consolidation moves.
- [ ] **Run test suite** if one exists (`vitest`, `pytest`, `npm test`). Fix regressions immediately.
- [ ] **Lint check:** `npx eslint .` — catch unused vars, missing hook deps, etc.

### Phase 5 — Security Audit
> Detailed grep patterns and code examples: [security-checks.md](resources/security-checks.md)

#### 5a. Frontend Security (React/Next.js)
- [ ] **XSS:** `dangerouslySetInnerHTML`, `.innerHTML`, dynamic `href={}`/`src={}`, DOM injection via URL params.
- [ ] **Sensitive data in client bundles:** `process.env.` without `NEXT_PUBLIC_` in `'use client'` files. API keys in fetch calls, tokens in state, secrets in `console.log()`.
- [ ] **Storage misuse:** Tokens/keys in `localStorage` (should use `sessionStorage` or HTTP-only cookies).
- [ ] **CORS:** `Access-Control-Allow-Origin: *` in production.
- [ ] **Open redirects:** `redirect()`, `router.push()` with user-controlled destination.
- [ ] **Client-side auth bypass:** Auth checks must happen server-side, not just in client components.
- [ ] **Security headers (CSP):** Verify `Content-Security-Policy` exists. No `'unsafe-eval'` in production. Check `X-Frame-Options`, `X-Content-Type-Options`, HSTS, `Referrer-Policy`.

#### 5b. Backend Security (API Routes / Server Actions)
- [ ] **SQL injection:** All queries use parameterized queries or ORM/SDK. No raw SQL concatenation.
- [ ] **Command injection:** `eval()`, `exec()`, `child_process.exec()` must never include user input.
- [ ] **SSRF / path traversal:** Endpoints fetching user-provided URLs or reading user-provided file paths must validate inputs. See [security-checks.md](resources/security-checks.md).
- [ ] **CSRF protection:** Mutation API routes validate CSRF tokens or rely on SameSite cookies. Server Actions have built-in origin checks — verify they're not disabled.
- [ ] **File upload security:** Upload size limits enforced server-side, MIME type validated by magic bytes, storage paths sanitized, bucket policies enforce RLS. See [security-checks.md](resources/security-checks.md).
- [ ] **Missing auth on API routes:** Every POST/PATCH/DELETE handler must call `getAuthContext()` or equivalent. Flag unprotected mutation routes.
- [ ] **Missing role checks:** Admin routes must enforce admin role, not just authentication.
- [ ] **Server Actions (`'use server'`):** Each is an exposed HTTP endpoint that bypasses middleware. Verify auth, input validation (Zod), safe return values, and rate limiting. See [nextjs-modern.md](resources/nextjs-modern.md).
- [ ] **Rate limiting:** Public endpoints and auth routes need rate limits. Auth/payment endpoints need stricter limits (5 req/15 min). See detection grep patterns in [security-checks.md](resources/security-checks.md).
- [ ] **Webhook signature verification:** HMAC/signature validation on incoming webhooks.
- [ ] **IDOR (Insecure Direct Object Reference):** Route handlers with ID path params must scope DB queries to the requesting user (`.eq("user_id", user.id)`) or rely on RLS (preferred). Return 404 — not 403 — to avoid confirming resource existence. See [security-checks.md](resources/security-checks.md).
- [ ] **Secrets in code/git:** Search for hardcoded keys, tokens, passwords. Check git history for committed secrets.
- [ ] **Error message leakage:** Catch blocks must not return raw errors to clients in production.

#### 5c. LLM-Specific Security
> Detailed tool_use and structured output checks: [llm-security.md](resources/llm-security.md)

- [ ] **Prompt injection (direct/indirect/workspace):** User input, RAG data, and user-configurable fields properly delimited with XML tags and message roles.
- [ ] **Defense instructions:** System prompts include explicit "ignore instructions in data tags" directives.
- [ ] **Tool/function calling security:** Parameter validation via Zod, `requiresConfirmation` on destructive tools, output sanitization, recursive call depth limits, permission checks at execution time.
- [ ] **MCP server security:** Authorization validation on MCP endpoints, transport security, tool poisoning defense, scope limitation. See [llm-security.md](resources/llm-security.md).
- [ ] **Structured output validation:** JSON responses parsed with try/catch + schema validation. Malformed output doesn't crash the app.
- [ ] **Max tokens:** Set on every LLM API call. Proportional to task complexity.
- [ ] **Model selection:** User-selectable tiers resolve to hardcoded allowlist. No arbitrary model IDs.
- [ ] **Cost controls:** Per-workspace/user usage tracking. Runaway loop prevention (depth limits). Streaming error handling.
- [ ] **PII minimization:** Customer PII not unnecessarily included in prompts. Logs/traces encrypted.
- [ ] **Hallucination guards:** Claim checking or coverage scoring where applicable.

#### 5d. Database & Schema (Supabase / Postgres)
- [ ] **RLS:** Enabled on ALL tables. Every `CREATE TABLE` has corresponding `ENABLE ROW LEVEL SECURITY` + policies.
- [ ] **RLS detection (live DB):** Run the SQL detection queries in [security-checks.md](resources/security-checks.md) to find tables with RLS disabled or enabled-but-no-policies.
- [ ] **RLS policy correctness:** Policies scope through `workspace_id` via user lookup, not just `auth.uid()`.
- [ ] **UUID primary keys:** User-facing ID columns should use `UUID DEFAULT gen_random_uuid()` — sequential integers enable enumeration attacks.
- [ ] **Admin client usage:** `createAdminClient()`/`service_role` only in server-side code, never client components.
- [ ] **Unused tables:** Tables in DDL but never queried in code.
- [ ] **Missing indexes:** Frequently filtered columns (`workspace_id`, `created_at`, `status`, `email`) need indexes.
- [ ] **Migration consistency:** Sequential numbering, column names/types match code expectations.
- [ ] **Cascade deletes:** Verify ON DELETE behavior is intentional. Wrong cascades can wipe data.
- [ ] **Realtime security:** Channel subscriptions validate auth. Channel names scoped to workspace. RLS covers Realtime-enabled tables.
- [ ] **Cross-tenant probe (live DB):** For each user-scoped table, run a SELECT as `auth.uid() = user_a` then as `user_b` — assert disjoint result sets. Optional helper: store seed fixtures in `__tests__/fixtures/rls-probe.sql` for repeatable checks.
- [ ] **WITH CHECK coverage:** UPDATE policies with `USING` but no `WITH CHECK` allow update-escape (user overwrites a row they own to belong to another user). Detection: `select * from pg_policies where cmd = 'UPDATE' and qual is not null and with_check is null`.
- [ ] **SECURITY DEFINER + auth.uid() trap:** Functions marked SECURITY DEFINER calling `auth.uid()` always return NULL (executor context lost) → policy condition becomes vacuously true. Detection: `select proname from pg_proc where prosecdef = true and prosrc ilike '%auth.uid()%'`.
- [ ] **Mutable search_path on SECURITY DEFINER:** Functions without `SET search_path = pg_catalog, public` are vulnerable to function-shadowing privilege escalation. Detection: `pg_proc.proconfig is null` for `prosecdef = true`.
- [ ] **service_role surface area:** Grep `createAdminClient()` / `service_role` call sites — each should have a comment explaining why RLS bypass is needed; flag bare uses in user-facing routes.
- [ ] **View security_barrier:** Views without `WITH (security_barrier = true)` can leak across tenants when join conditions push down through unrestricted base tables.

#### 5e. Authentication & Session Security
- [ ] **Middleware coverage:** `middleware.ts` protects all non-public routes. Check matcher config.
- [ ] **Edge runtime safety:** Middleware must not import Node.js-only APIs (`fs`, `path`, `crypto` node version). See [nextjs-modern.md](resources/nextjs-modern.md).
- [ ] **Session refresh:** Supabase middleware refreshes session on each request.
- [ ] **Auth callback (PKCE):** Uses `exchangeCodeForSession()` (not deprecated `verifyOtp()`). Uses `@supabase/ssr` patterns (not deprecated `createClientComponentClient`).
- [ ] **OAuth state parameter:** Validated to prevent CSRF.
- [ ] **Credential encryption:** Stored provider credentials use AES-256-GCM. Encryption key not hardcoded.

#### 5f. Supply Chain Security
- [ ] **Dependency audit:** `npm audit --audit-level=high` — flag HIGH/CRITICAL vulnerabilities.
- [ ] **Lockfile committed:** `package-lock.json` or `pnpm-lock.yaml` exists in git.
- [ ] **Postinstall scripts:** Check for dangerous `postinstall` scripts in dependencies.
- [ ] **Abandoned deps:** Flag packages with >1 year since last publish.
- [ ] **EOL runtimes:** Check Node.js version in `.nvmrc`/`package.json engines`/`Dockerfile` against Node.js release schedule. Flag EOL versions.
- [ ] **Deprecated APIs:** Grep for known deprecated patterns (`createClientComponentClient`, `useFormState`, `getServerSideProps`, `getStaticProps` in App Router projects).
- [ ] **CVE-affected packages:** Cross-reference critical dependencies against known unfixed CVEs using `npm audit` output.

#### 5g. Container & Deployment Security
- [ ] **Dockerfile best practices:** Multi-stage builds, non-root user (`USER node`), no secrets in build args, `.dockerignore` excludes `.env`/`.git`/`node_modules`.
- [ ] **Exposed ports:** Only necessary ports exposed. No debug ports (9229, 5555) in production.
- [ ] **Health checks:** Container has `HEALTHCHECK` instruction or orchestrator-level health probe.
- [ ] **Base image currency:** Base image is recent and from a trusted registry. Flag `latest` tags (non-reproducible builds).

#### 5h. Cost & Resource Controls
> **Why:** Production drains repeatedly trace to: AI calls without logging, no per-user rate limits, no server cache before LLM, hardcoded model IDs that bypass tier resolution, RevenueCat ↔ Stripe ↔ DB tier desync, unauthenticated cron endpoints firing paid jobs.

- [ ] **AI usage logging coverage:** Every `anthropic.messages.create()` / `openai.chat.completions.create()` call site must write to `ai_usage_logs` (or equivalent). Detection: grep for AI SDK call sites, then grep for the logger import — diff = uncovered routes.
- [ ] **Shared AI wrapper enforcement:** If project has a wrapper utility (e.g., `makeCallAI`, `callClaude`), raw SDK calls outside it = violations. They bypass logging, tier resolution, and cache.
- [ ] **Per-user/workspace AI rate limits:** Global limits don't prevent one tenant from draining the budget. Detection: rate-limit middleware should key by `user_id` or `workspace_id`, not just IP.
- [ ] **Server-side cache before LLM call:** Briefing / digest / summarization endpoints with no cache layer re-bill on every page load. Look for `messages.create` inside route handlers without preceding `cache.get`.
- [ ] **Hardcoded model IDs:** Search for literal model strings (`'claude-sonnet-4-6'`, `'gpt-4o'`) in route handlers — should resolve from tier (`resolveModel(profile.tier)`).
- [ ] **Subscription/entitlement source-of-truth:** RevenueCat ↔ Stripe ↔ DB `profiles.tier` must agree. Detection query: `select id, tier, stripe_customer_id from profiles where tier <> (latest webhook payload tier)`.
- [ ] **Cron auth:** Every `/api/cron/*` route validates `Authorization: Bearer ${CRON_SECRET}`. Missing = anyone can fire your jobs (and bills).
- [ ] **Webhook idempotency:** Stripe / RevenueCat / Postmark webhooks check event_id against a processed-events table; replay = double-charge / double-grant.
- [ ] **Streaming token budget:** SSE/streaming AI endpoints have max-token cap and timeout — runaway streams burn through budget invisibly.
- [ ] **Background job dedup:** Queue worker dedupes by job_id; same job firing 3× = 3× the cost.

### Phase 6 — Performance Audit

#### 6a. Next.js & RSC Performance
- [ ] **Bundle size:** Large imports (`recharts`, `pdf-lib`, `xlsx`, `monaco-editor`) should use `next/dynamic` with `ssr: false`.
- [ ] **Server vs Client components:** `'use client'` only on components using hooks/events/browser APIs. See [nextjs-modern.md](resources/nextjs-modern.md) for RSC boundary checks and React 19 patterns.
- [ ] **Unnecessary `'use client'`:** Components that only render JSX with props should be Server Components.
- [ ] **Client importing server code:** `'use client'` files must not import `next/headers`, `cookies()`, DB clients, or `server-only` modules.
- [ ] **Unnecessary re-renders:** Inline `style={{}}`, `options={[]}` in render. Extract or memoize (unless React Compiler is enabled — check `next.config`).
- [ ] **Image optimization:** `<Image>` from `next/image` instead of `<img>`. Check `width`/`height`/`sizes`.
- [ ] **Missing Suspense boundaries:** Pages with async data need `<Suspense>` or `loading.tsx`.
- [ ] **N+1 queries:** List fetched, then each item triggers individual query. Batch instead.
- [ ] **Async request APIs (Next.js 15+):** `cookies()`, `headers()`, `params`, `searchParams` must be `await`ed. See [nextjs-modern.md](resources/nextjs-modern.md).

#### 6b. API & Data Fetching Performance
- [ ] **Missing staleTime:** `useApi()` / TanStack Query calls without `staleTime` refetch on every mount.
- [ ] **Polling intervals:** `refetchInterval` under 10s on non-critical data wastes bandwidth.
- [ ] **Missing pagination:** Unbounded `SELECT *` on growing tables. Add `?limit=`/`?offset=` or cursor pagination.
- [ ] **Missing caching:** Frequently-read, rarely-written data should have in-memory cache with TTL.
- [ ] **Redundant API calls:** Multiple components independently calling the same endpoint. Share via context or hooks.

#### 6c. Supabase Query Performance
- [ ] **SELECT \*:** Use specific columns, especially on tables with large JSON columns.
- [ ] **Missing `.single()`:** Queries expecting one row should use `.single()`.
- [ ] **Realtime cleanup:** `supabase.channel()` subscriptions cleaned up on unmount.

#### 6d. Accessibility
- [ ] **Missing alt text:** `<img>` and `<Image>` without `alt` attributes.
- [ ] **Semantic HTML:** `<div onClick>` should be `<button>`. Interactive elements need accessible names.
- [ ] **Form labels:** Inputs must have `<label>` or `aria-label`.
- [ ] **Heading hierarchy:** One `<h1>` per page, logical heading order.
- [ ] **Tab order:** No `tabIndex > 0`. Modals must trap focus and support Escape to close.

#### 6e. Design Quality (when UI in scope)
> **Why:** AI-generated UI tells (generic 3-col grids, default shadows, gradient-overuse, Inter fallback) ship without flag. The audit doesn't currently recognize "looks like AI built this" as a defect. Pair this phase with the design triad (`taste-skill`, `soft-skill`, `impeccable`).

- [ ] **Invoke `impeccable` skill** for any pages/components in scope — it produces the deeper audit. This phase only catches the textbook tells.
- [ ] **AI-tell grep:** `grid-cols-3` without responsive variants, `bg-gradient-to-br from-purple-` / `from-pink-` (signature AI gradient), bare `shadow-lg` / `shadow-xl` without custom shadow tokens, default `rounded-md` everywhere, `lucide-react` icons mixed with no system.
- [ ] **Font enforcement:** Project's `font-family` declarations must NOT fall back to `Inter` in projects that ban it (LIFE bans Inter; uses Sora + Satoshi). No `system-ui` as primary on a branded surface.
- [ ] **Token consistency:** Hardcoded hex colors (`#1B4332`) in components instead of CSS variables / Tailwind tokens. Spacing values not on the project's grid (LIFE: 8px). Font sizes not from defined scale.
- [ ] **Touch targets:** Interactive elements rendered <44px (LIFE rule). Detection: `<button class="h-8"` / `h-9` without padding compensation.
- [ ] **Motion:** `transition-all`, `ease-in-out`, `ease-linear` (banned in LIFE — should use spring physics or custom cubic-bezier). Framer Motion `transition={{ type: 'tween' }}` without easing.
- [ ] **Dark mode parity:** Components using light-only Tailwind classes (`bg-white text-black`) without `dark:*` variants. Both themes must ship — flag any component missing dark variants.
- [ ] **Loading state mis-use:** `<Spinner />` / `Skeleton` rendered for data the user just optimistically wrote (LIFE banned pattern — optimistic data must appear instantly).
- [ ] **Asymmetric layout:** Default 3-column grids of equal-width cards = AI tell. Prefer 2/3 + 1/3, zig-zag, or staggered grids per LIFE rules.
- [ ] **Iconography:** Emojis in UI (banned in LIFE — must use Phosphor icons). Mixed icon libraries on the same page.

### Phase 7 — File Sync & Consistency
- [ ] **Mirrored files:** Diff duplicate file sets and fix any drift.
- [ ] **Config consistency:** `.env.example` lists all `process.env.*` keys used in code.
- [ ] **Cross-reference deletions:** After deleting any file, grep for stale imports/references.
- [ ] **Type/schema drift:** TypeScript interfaces in `lib/types/` match Supabase migration columns.
- [ ] **Zod schema completeness:** Zod schemas cover all required fields from corresponding TypeScript types.
- [ ] **Route/page consistency:** Dashboard pages have corresponding API routes. All API routes have frontend callers.
- [ ] **Environment safety:** `.env.*` files not committed to git. Dev-only features gated behind `NODE_ENV`.
- [ ] **Observability:** Error tracking (Sentry/similar) exists. Structured logging (not just `console.log`). Health check endpoint (`/api/health`).
- [ ] **Migration sequential check:** Filenames sorted vs numerical sequence — flag gaps (missing 217 between 216 and 218) or duplicates (two `220_*.sql`). Detection: `ls supabase/migrations | awk -F_ '{print $1}' | sort -n | uniq -d` and adjacent-diff scan for non-1 gaps.
- [ ] **Migration idempotency:** Each migration uses `IF NOT EXISTS` / `IF EXISTS` / `CREATE OR REPLACE` so re-runs don't break. Detection: grep migration files for `create table\b` (without IF NOT EXISTS), `create index\b`, `alter table ... add column\b` (without IF NOT EXISTS where supported).
- [ ] **Schema-vs-code drift:** Run `supabase db diff` against current schema; flag local drift not captured in a migration file.
- [ ] **Superseded-migration audit:** Migrations adding columns/tables later removed but the original migration still runs on fresh DBs (e.g. `223_cleanup_superseded_web_push.sql` shipped because `219` left dead rows). These should be consolidated or marked historical with comment.
- [ ] **Audit trigger coverage:** Every mutating table should have an `AFTER INSERT/UPDATE/DELETE` audit trigger. Cross-ref `information_schema.triggers` to user-table list.
- [ ] **RLS-enabled-but-no-policies trap:** Tables with RLS turned on but zero policies = silent lockout. Detection in [security-checks.md](resources/security-checks.md).
- [ ] **Foreign key cascade audit:** Every FK should have explicit `ON DELETE CASCADE` / `SET NULL` / `RESTRICT`. Default `NO ACTION` causes failed deletes that get swept under the rug.

### Phase 8 — Functional Verification
End-to-end check that every feature works as intended.

> **When the dev server cannot run locally:** If the project requires external services (DB, auth provider, third-party APIs) that aren't available:
> - Run static checks only: type check, lint, build. Skip runtime smoke tests.
> - Use `curl` or API client against a staging URL if one is provided.
> - For Supabase projects: verify connection string is set and `supabase status` returns healthy.
> - Note in report: "Functional verification was static-only. Runtime testing requires [missing service]."

#### 8a. API Route Smoke Test
- [ ] Inventory all API routes: glob `app/api/**/route.ts`, list HTTP methods exported.
- [ ] Test each route with valid input: correct status codes, response shape matches types, structured error JSON.
- [ ] Test with invalid input: malformed JSON, missing fields, wrong types → 400 with useful message.
- [ ] Test without auth: protected routes return 401, not 500 or empty 200.

#### 8b. Page & Navigation Verification
- [ ] Load every page: no blank screens, loading states render, error boundaries work.
- [ ] Navigation flows: Login → Dashboard → each section → Logout. CRUD for each entity. Settings persistence.
- [ ] Protected route enforcement: dashboard URLs redirect to login when logged out.
- [ ] 404 handling: non-existent routes render not-found page.

#### 8c. Feature-Level Verification
- [ ] Auth flow: register → verify → login → session persists → logout clears session.
- [ ] CRUD operations: create → appears in list → detail shows correct data → update persists → delete removes + no orphans.
- [ ] Search/filtering: correct results, handles empty results gracefully.
- [ ] AI features: send message → receive response, streaming works, empty input shows validation, KB context included.
- [ ] Admin features: each tab loads, controls function.

#### 8d. Data Integrity Checks
- [ ] Orphaned records: foreign keys pointing to non-existent parents.
- [ ] Null required fields: non-nullable business fields that are actually null.
- [ ] Enum consistency: `stage`/`status`/`role` values in DB match TypeScript definitions.
- [ ] Audit log coverage: create/update/delete operations logged correctly.

#### 8e. Integration Health
- [ ] Supabase connectivity: simple query succeeds.
- [ ] LLM provider: configured provider responds to minimal request.
- [ ] External services: credentials valid, services reachable. Log healthy vs broken integrations.

### Phase 8.5 — Deployment & Ops
> **Why:** Production fires repeatedly trace to deployment-side bugs that no source-code audit catches: env-var wipeouts from raw `curl PUT`, missing GitHub deploy hooks causing zombie services, broken cross-subdomain auth, CDN caching HTML for a year.

- [ ] **Env-var setter safety:** Project should have a safe-patcher script (e.g., LIFE's `scripts/render-env-set.js`). Raw `curl -X PUT /env-vars` calls in scripts/CI = wipeout risk → flag.
- [ ] **Required env vars on prod:** Cross-ref `.env.example` against what's actually set on Render/Vercel. Use platform API to list, not assume. Missing vars on prod cause silent fallbacks.
- [ ] **Subdomain cookie scoping:** If admin app and user app share root domain (`admin.x.com` + `app.x.com`), check cookie `Domain` attribute — wrong scope = session leak across apps.
- [ ] **Deploy hook coverage:** Every Render service should have GitHub deploy hook wired; manual-deploy services drift. Detection: list Render services and check `autoDeploy = true` per service.
- [ ] **CDN cache headers:** Static assets have `Cache-Control: public, max-age=31536000, immutable`; HTML responses have `Cache-Control: no-store` or short max-age. Wrong headers = stale users for hours after deploy.
- [ ] **Rollback readiness:** Last 3 deploys documented; latest deploy SHA tagged; one-command rollback path exists.
- [ ] **Health check completeness:** `/api/health` checks DB connection, AI provider, Stripe, Postmark — not just "200 OK". A service that returns 200 while its DB is down is worse than no health check.
- [ ] **DNS / domain ownership:** Cloudflare or registrar DNS matches the deployed service's expected hostname. Stale DNS records pointing to dead Workers / deprecated CDNs.
- [ ] **Cross-app auth:** If multiple subdomains share auth (`app.` ↔ `admin.`), session/JWT issuer + audience claims include all valid subdomains; otherwise users get logged out crossing subdomains.
- [ ] **Build-time secret leakage:** `NEXT_PUBLIC_*` env vars only contain truly public values. Detection: grep `.env*` for `NEXT_PUBLIC_.*KEY|SECRET|TOKEN`.

### Phase 9 — Reporting
- [ ] **Categorize findings** by severity (aligned with `red-team-security-audit` for cross-skill merge):
  - **P0 (block deploy):** Active exploit possible by remote unauthenticated attacker; data leak; privilege escalation; RCE; secrets leaked; missing auth on mutating routes; RLS off on user-data tables; broken core feature.
  - **P1 (high):** Exploitable with auth or modest pre-conditions — IDOR, stored XSS, prompt injection, mass-assignment, regression of approved behavior, AI cost-DoS via missing per-user limits.
  - **P2 (medium):** Defense-in-depth gap — missing security headers, weak rate-limit, schema/Zod drift, missing pagination, re-renders, dead code increasing attack surface, file/cache drift, AI usage logs uncovered.
  - **P3 (low / informational):** Best-practice deviation — minor redundancy, hardening opportunity, deprecated dep without known CVE, AI-tell design issues, documentation gaps.
- [ ] **Create fix plan** as checklist with file paths and line numbers.
- [ ] **Estimate impact** per finding: [Security] [Cost] [Performance] [DX] [Reliability]
- [ ] **Machine-readable output** (optional): Produce JSON summary with `{ audit_date, scope, files_audited, findings: [{ severity, category, file, line, description, suggested_fix }], summary: { p0, p1, p2, p3 } }`.
- [ ] **Verify each fix** (type check, grep for remaining references) before moving on.
- [ ] **Commit fixes** with descriptive messages grouping related changes.

## Execution Strategy

### Parallel subagents for large codebases
For projects with 20+ files, spawn parallel Agent subagents:
- **Agent 1:** Backend (API routes, services, server actions) — auth, injection, dead code, error handling
- **Agent 2:** Frontend (pages, components, hooks) — XSS, performance, accessibility, dead code, RSC boundaries
- **Agent 3:** Infrastructure (SQL migrations, configs, env vars, middleware) — RLS, schema drift, supply chain, consistency
- **Agent 4:** AI/LLM (prompt assembly, adapters, tool definitions) — prompt injection, tool_use security, MCP security, cost controls
- **Agent 5:** Functional verification (requires running dev server) — API smoke tests, page loads, CRUD flows
- **Agent 6:** File consolidation (runs after dead code removal) — fragmentation, dedup, structure, barrels, circular deps
- **Agent 7:** Regression preservation — diff working tree against last known-good commit; for each modified function, list prior behaviors (returns, side effects, edge-case branches) and verify each still holds. Flag any silently dropped behavior.
- **Agent 8:** Architectural invariant — reads CLAUDE.md / project memory, generates targeted greps from the must/must-not lists, runs them, reports violations with citation back to the source rule.

#### Subagent merge protocol
- Each agent produces structured findings: `{ file, line, severity, category, description, suggestedFix }`.
- Dedup on `(file, line, category)` — keep higher severity.
- **Conflict priority matrix:**
  - Security fix > Performance fix > Cleanup > Style
  - If two agents propose contradictory changes to the same file+line, security agent wins.
  - If same priority tier, the agent whose change is more conservative (less destructive) wins.
- **Cross-agent dedup:** Before committing, diff all proposed changes. If Agent A deletes a function and Agent B adds a call to it, surface as a conflict for human review.
- Orchestrator validates no agent's deletions conflict with another's references.

### Incremental audit mode
When auditing recent changes only:
- Use `git diff --name-only HEAD~N` to scope to changed files + their direct importers.
- **Always include high-risk files** (auth, payment, billing, webhooks, middleware, encryption) even if unchanged — these are re-audited every time.
- Run full checklist but only on scoped files.
- Note in report: "Scoped audit covering N files changed since commit X. M high-risk files re-audited."

### Priority order for fixes
1. Security vulnerabilities (fix immediately)
2. Broken features / functional failures (fix immediately)
3. Broken references / bugs (fix immediately)
4. Data integrity issues (orphaned records, enum mismatches)
5. Performance issues causing visible degradation
6. Dead file deletions (safe, high-value cleanup)
7. Dead function removal (verify no dynamic/reflection usage first)
8. File consolidation (merges, dedup, restructuring — behavior-preserving only)
9. Consistency fixes (file sync, config alignment, type drift)
10. Optimization (caching, pagination, bundle splitting)

## Common Pitfalls
- **Dynamic dispatch:** `getattr()`, `window[funcName]()`, `React.lazy(() => import(...))`, string-based routing won't show in static grep — verify before deleting "unused" code.
- **Tailwind dynamic classes:** `bg-${color}-500` gets purged at build time. Use complete class names or `safelist`.

## Resources
- [Pipeline integrity tracing — worked examples & bug retros](resources/pipeline-tracing.md)
- [Architectural invariant detection patterns](resources/invariant-audit.md)
- [Security check patterns & examples](resources/security-checks.md)
- [Next.js modern patterns (Server Actions, RSC, Edge, Turbopack, React 19)](resources/nextjs-modern.md)
- [LLM & AI security checks (tool_use, MCP, structured outputs, cost controls)](resources/llm-security.md)
- [File consolidation heuristics & patterns](resources/file-consolidation.md)
- [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [Core Web Vitals Guide](https://web.dev/vitals/)
