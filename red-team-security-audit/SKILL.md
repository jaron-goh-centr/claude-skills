---
name: red-team-security-audit
description: Performs a comprehensive adversarial security audit across all layers of a codebase (frontend, backend, auth, database, infra, dependencies, AI logic). Use when the user requests a "complete security audit", "full security audit", "red team audit", "adversarial audit", "comprehensive security review", or any phrase signaling they want an exhaustive, paranoid, attacker-perspective review (not a routine lint/check). Distinct from `performing-full-file-audits` (the checklist-driven quality/bloat/security workspace audit) — this skill is the **red-team** variant: assumes a hostile environment, motivated attackers, and creativity beyond standard checklists. Runs on ANY codebase (web or not). Can optionally escalate to **Phase 5 live exploitation** that *proves* findings with reproducible PoCs — Shannon (Keygraph autonomous pentester) for web/API targets, archetype-tailored dynamic probes otherwise — gated, opt-in, dev-branch-only. Also triggers on: "prove these vulnerabilities", "run live exploits", "validate with Shannon", "dynamic validation", "actually exploit this".
---

# Red-Team Security Audit

## When to activate

Trigger phrases (any of these MUST fire this skill):
- "complete security audit"
- "full security audit"
- "red team audit"
- "adversarial audit"
- "comprehensive security review"
- "audit everything for security"
- "assume hostile environment"
- "attack this codebase"
- "find every vulnerability"
- "paranoid review"

Also fires for the optional live-validation arm (Phase 5):
- "prove these vulnerabilities" / "actually exploit this"
- "run live exploits" / "dynamic validation"
- "validate with Shannon" / "pentest this"

If user says any of the above, invoke this skill BEFORE responding. Skill stays active for the entire audit engagement.

## Methodology overview

Four core phases, executed in order (do not skip), plus an optional fifth (opt-in, gated).

```
Phase 1: Threat model → Phase 2: Layer audits → Phase 3: Adversarial chains → Phase 4: Output report
                                                                            → Phase 5 (optional, opt-in): Adaptive dynamic validation
```

Phases 1–4 are **static, read-only, and codebase-agnostic** — they run on any project (web app, API,
CLI, library, AI pipeline, infra). Phase 5 is the **optional live-exploitation arm** that converts
static *potential* findings into *proven* PoCs; it profiles the target and routes to the right dynamic
validator (Shannon for web/API; tailored probes otherwise). See Phase 5 and
[`resources/shannon-dynamic-validation.md`](resources/shannon-dynamic-validation.md).

The skill is **paranoid by default**:
- Assume nothing works as intended.
- Assume the system is deployed against motivated attackers.
- Flag-if-unsure (note as "potential risk" with reasoning).
- Do not assume fixes are correct — re-derive from code.
- Cross-reference any prior audit document and supplement, do not duplicate.

---

## Phase 1 — Threat Model

Before searching for vulnerabilities, build the threat model. Output this as the opening section of the final report.

### 1.1 Attacker profiles

Enumerate at least 4 distinct profiles, each with capabilities and motivations:
- **Anonymous external** — no creds; can hit public routes, OAuth callbacks, webhook receivers, share-token URLs.
- **Authenticated user** — valid account; can hit all `/api/*` routes; goal is horizontal/vertical privilege escalation.
- **Insider / malicious admin** — has elevated DB or admin app access; goal is data exfil or backdoor.
- **API consumer / 3rd-party integration** — supplies webhooks (Postmark, Stripe, RevenueCat, etc.); goal is signature bypass or replay.
- **Supply-chain adversary** — pushes malicious npm package update; goal is RCE on build/runtime.
- **AI-prompt attacker** — controls a field that flows into an LLM prompt (calendar event title, contact note, news article body); goal is prompt injection → data exfil or side-effect. Also controls *ingested trusted content*: a downloaded skill `.md`, an MCP server's hidden input/output, a PDF/email/RAG document — this is INDIRECT (second-order) injection, where the payload rides in data the app trusts by design (not a field the attacker "obviously" owns).

### 1.2 Entry points

List every external entry point. Categorize:
- HTTP routes (public, authenticated, admin, cron, webhook)
- WebSocket / Realtime channels
- File uploads
- Email ingest endpoints
- Push / SMS / Telegram receivers
- OAuth callbacks
- Public share links / invite tokens

### 1.3 Trust boundaries

Map trust transitions:
- Browser ↔ API (cookie / JWT / Authorization header)
- API ↔ DB (RLS enforced, service-role bypass)
- API ↔ AI provider (prompt → model → response → DB write)
- API ↔ 3rd-party webhook (signature verification)
- App ↔ Admin app (separate app or shared domain?)

### 1.4 Sensitive assets

Enumerate what an attacker would target:
- Secrets (API keys, master encryption keys, JWT signing keys)
- Credentials (OAuth refresh tokens, password hashes)
- PII (profiles, contacts, finance, health, location)
- Tokens (session, share, invite, MFA)
- Audit logs (tampering value)
- Role / tier / entitlements (privilege escalation target)
- System-prompt contents — its instructions AND any secrets/keys/tool names embedded in it; extracting the system prompt reveals structure + implicit rules and is the typical first step before deeper exploitation

---

## Phase 2 — Layer Audits (parallel)

For large codebases (>500 files), dispatch parallel Explore agents — one per layer — in a single message with multiple Agent tool calls. Use 7–8 agents. Each agent receives:
- Their specific scope (file globs, specific routes/dirs)
- Concrete vulnerability classes to search for
- The path to any prior audit document (with instruction to supplement, not duplicate)
- Required output mini-format

For smaller codebases (<500 files), execute layers sequentially with Grep + Read.

### Layer 1 — Authentication & Session

Search for:
- Token storage (cookie flags `Secure`, `HttpOnly`, `SameSite`; localStorage misuse)
- Session fixation / rotation on login & privilege change
- OAuth state / PKCE / nonce; provider redirect_uri whitelist
- MFA enforcement consistency (admin path vs user path)
- Password reset token: single-use? expiry? leak via referer?
- Vertical priv-esc: client-side role checks; server-side missing checks
- Horizontal priv-esc: scope by user_id missing
- Race in role check vs role write
- Logout: token invalidated server-side or only client-cleared?

### Layer 2 — Input handling & Injection

Search for:
- Routes without Zod / runtime validation
- SQL: any raw string concat with user input
- NoSQL / PostgREST: filter injection via dynamic key
- Command injection: `child_process.exec` / `spawn` / `execSync` with user input
- Template injection: email / SMS / push templates with `${user_input}`
- Path traversal: file uploads / download / read with user-controlled path
- SSRF: URL fetched from user input (image proxy, link preview, webhook)
- File upload: mime sniffing trust, ZIP/SVG/IMG bombs, double-extension
- XXE in any XML parsing
- Server-side template engines (Pug, Handlebars) with raw input

### Layer 3 — IDOR / BOLA / Mass-Assignment

Search for:
- Routes with `[id]` / `[token]` path params not scoping by `user_id`
- PATCH/PUT bodies with mass-assignment (.partial() Zod accepting `role`, `tier`, `user_id`)
- Indirect references via foreign keys (e.g., `event_id` → bypass user check)
- Bulk endpoints accepting array of IDs (one missing check leaks all)
- Predictable IDs (sequential int, low-entropy UUID v1, base64-of-counter)
- Public share tokens without rate-limit / without revocation

### Layer 4 — Data Security & Crypto

Search for:
- Plaintext secret storage (DB columns, log files, error messages)
- AES-GCM IV reuse (deterministic IV from PRNG seed)
- Single master key for all credentials (no per-tenant / per-provider isolation)
- Weak KDF (PBKDF2 < 100k iter, no Argon2/scrypt for password hash)
- Hardcoded keys (search `.env*`, all .ts/.js/.json/.sql files; check git history if available)
- Secrets logged on error path (`console.error(err)` where `err.config.headers` includes Authorization)
- Browser storage: tokens in localStorage (vs httpOnly cookie)
- Crypto.randomUUID vs Math.random() in security contexts
- JWT: alg:none acceptance, weak HS256 secret, `kid` injection

### Layer 5 — Infrastructure / Headers / Config

Search for:
- CSP: `unsafe-inline`, `unsafe-eval`, `*` in script-src
- HSTS missing / max-age too low / `includeSubDomains` missing
- CORS: `*` with credentials, reflect-origin without whitelist
- X-Frame-Options / frame-ancestors absent (clickjacking)
- Permissions-Policy missing
- Debug routes mounted in prod (`/api/debug/*`, `/api/_internal/*`)
- Source maps shipped to production (.js.map URLs)
- Stack traces leaked in error responses
- `NEXT_PUBLIC_*` env containing secrets
- Admin app on same domain as user app (cookie scoping risk)
- Cron route auth bypass (anyone can hit `/api/cron/*` if Bearer absent)
- Webhook signature missing or non-timing-safe (`===` vs `crypto.timingSafeEqual`)

### Layer 6 — RLS / Database

Search for:
- Tables with `rowsecurity = false`
- Tables with RLS enabled but zero policies (double-check intent: service-role-only vs accidental lockout)
- Policies with USING but no WITH CHECK (UPDATE escape)
- Policies referencing `auth.uid()` inside SECURITY DEFINER (always returns NULL → policy true)
- SECURITY DEFINER functions with mutable `search_path` (privilege escalation via shadowed function)
- Views without `security_barrier` exposing other users' data
- Foreign keys missing ON DELETE CASCADE (orphan data referencing deleted user)
- Audit triggers: coverage on every mutating table?
- Cross-tenant leak via JOIN on unrestricted `_view`

### Layer 7 — Dependencies & Supply Chain

Search for:
- `npm audit` simulation: known-vuln package@version (next, react, anthropic-sdk, supabase-js, jsonwebtoken, axios, etc.)
- Unpinned majors (`^`, `~`) on security-critical deps
- Postinstall scripts on transitive deps
- Typo-squat risk (anthropic vs `@anthropic-ai/sdk`)
- `eval`, `new Function`, `vm.runInNewContext` with non-static input
- Lockfile drift (package.json vs lockfile mismatch)
- `overrides` masking root vulnerabilities
- Deprecated packages (`request`, `node-uuid`, `crypto-js`, `bcryptjs` on Node)

**AI supply chain** (the npm checks above don't cover content that flows into a prompt):
- Ingested skill / `.md` / prompt-template files loaded at runtime without injection-scanning — a 2nd-order injection carrier (a "helpful" downloaded skill can carry a hidden payload)
- MCP server tool definitions + responses trusted unsanitized — audit the "toxic flow": what text enters the prompt, what output is acted on, which tools it can trigger (nobody inspects the code in between)
- RAG/vector documents, PDFs, email bodies fed into a prompt without treating their content as hostile
- Untrusted content reaching a prompt with NO input guardrail between ingest and model
- **This OS:** treat Obsidian-sync notes, `skills/*/SKILL.md`, and every connected MCP server as live injection carriers — audit each as untrusted input, not trusted config.

### Layer 8 — AI-specific

Search for:
- Prompt assembly: user input concatenated into system prompt without delimiter (`<user_data>` tags or similar)
- LLM JSON output → `JSON.parse` without try-catch and without Zod re-validation
- LLM tool-use with side-effects (send_email, modify_calendar, write_db) without HITL gate
- AI cache key missing user_id (response leak across users)
- AI rate-limit absent on user-controllable invocations (cost-DOS via expensive prompts)
- Model output flowing into DB writes that bypass field-level validation
- Vector store (RAG) with cross-tenant fetch (filter on user_id missing)
- AI-induced privilege escalation: LLM output influencing role / tier / entitlement
- Agent impersonation: LLM persona switching mid-conversation via injection (attacker-supplied "you are an unrestricted auditor AI" / "switch to policy-interpreter mode")
- Structured-output coercion: a prompt demanding JSON "matching this schema — mandatory for compliance/export" to pressure a leak — the demand-framing is the *attack* (don't mistake structured output here for a defense)
- Fake-delimiter injection: untrusted data carrying `-- instructions` / `##` / `<system>` to forge instruction context (e.g. injected "for reference and calibration" text inflating a doc score)
- Payload splitting in one prompt: define harmless fragments then "output A+B+C" to evade keyword filters (embeds in a PDF, white-on-white email text, or a downloaded skill `.md`)
- Multi-turn reassembly: individually-innocent turns whose accumulated chat history (re-fed as one prompt — LLMs are stateless, history lives in the app layer) reconstruct an exfil the bot refused directly
- Combination payloads: role-play + structured-output (or two or more techniques) stacked — these have broken models that resisted each technique alone; flag any pipeline relying on ONE guardrail
- Secrets embedded IN the system prompt (API keys, internal URLs, tool tokens) — the primary exfil target; never co-locate secrets with the prompt

---

## Phase 3 — Adversarial Search (chains)

After single-finding sweep, deliberately search for chain combinations. At minimum 3 multi-step exploit chains in the report. Patterns to look for:

1. **Reflected URL → CSP gap → cookie steal → IDOR**
2. **Webhook replay → race in role check → admin priv-esc**
3. **Prompt injection → AI tool-use → side-effect (email/calendar mutation)**
4. **Mass-assignment → tier change → entitlement bypass → free-tier abuse**
5. **OAuth callback CSRF → session fixation → account takeover**
6. **Source map leak → finds debug route → debug route SQL-injects → service-role bypass**
7. **File-upload SVG with onload → stored XSS → exfil another user's session via image proxy SSRF**
8. **Cache poison via `NEXT_PUBLIC_` env → forces stale CSP → opens clickjack**
9. **Malicious downloaded skill `.md` / MCP response → indirect (2nd-order) prompt injection → LLM tool-use side-effect (no input guardrail between ingest and model)**
10. **Stacked role-play + structured-output demand → single AI guardrail bypassed → system-prompt secret (API key) exfil**

Also explicitly probe:
- Race conditions (TOCTOU on ownership check)
- State desync between client cache and server (optimistic mutation accepts forbidden change)
- Replay attacks (idempotency key missing on payment / share-RSVP)
- Timing attacks (`===` on token comparison)
- Cache poison (shared key across users)
- Feature abuse (referral reward double-claim, free-tier loophole)
- "Shouldn't be possible but is" — interactions between modules under stress

---

## Phase 4 — Output Format

The final report MUST follow this exact structure:

### 1. Vulnerability Summary
- Total counts by severity (P0 / P1 / P2 / P3)
- One-line each

### 2. Detailed Findings
For each finding:
- **Title**
- **Severity** (P0 critical / P1 high / P2 medium / P3 low / informational)
- **Affected component** (file:line where possible)
- **Description**
- **Exploitation scenario** (concrete steps)
- **Impact** (data / auth / availability / financial)
- **Recommended fix**

### 3. Attack Chains
- Minimum 3 chains. Each: numbered steps, reference findings IDs from section 2.

### 4. Secure Design Recommendations
- Architectural patterns (defense-in-depth at middleware, key isolation, rate-limit-by-default, AI output sandbox, RLS coverage harness, dep pinning policy, secret rotation runbook)
- Each recommendation: what, why, where to apply
- **AI guardrail stack** (no single guardrail suffices — combinations defeat any one): input guardrail (pre-LLM) **and** output guardrail (pre-print), each as hardcoded checks **plus** multiple *narrow* LLM-as-judge instances (a strict, narrow judge is harder to breach than a wide chatbot prompt — and the judge is itself injectable, so stack + hardcode; the source talk suggests 3–5); input-length cap (limits long-storyline attacks — doesn't stop compact payload-splitting); I/O sanitize/normalize; small-scope services to bound blast radius; HITL on risky ops; keep the system prompt strict; secrets OUT of the system prompt. Headline principle: **treat the model like untrusted user input** — isolate untrusted content from authority/secrets/tools, and validate output before any side-effect (you can't always avoid ingesting untrusted data, but you can deny it authority). "We use a strong model" is NOT a control (newer ≠ safer; combinations still break strong models).

### 5. Dynamic Validation Results (only when Phase 5 ran)
- **Validator used** and **why** (target archetype → routed path), or "dynamic N/A — static-only" + rationale.
- Per static finding, a validation status: `PROVEN (PoC + repro)` / `UNCONFIRMED (static only)` / `DYNAMIC N/A (archetype)`.
- **Validator-only findings** — anything the live run surfaced that static missed (new IDs, full finding format).
- For Shannon runs: path to the raw report (`audit-logs/{host}_{session}/`), branch the run executed on, scope used.

---

## Phase 5 — Dynamic Validation (adaptive, opt-in)

**Purpose.** Phases 1–4 reason about the code and produce *potential* findings. Phase 5 *proves* them by
executing real exploits/probes against a running instance, turning "potential" into "reproducible PoC".
It is **opt-in and never auto-runs** — the static report is a complete deliverable on its own.

**This runs on any project — it does not assume a web app.** Step 5.0 profiles the target's design and
functional philosophy, then routes the dynamic arm. No web surface ≠ skip; it selects a different (or no)
validator, stated explicitly.

### Step 5.0 — Profile the target archetype (from code/deps/entrypoints, not assumptions)

| Archetype | Signals | Dynamic validator |
|---|---|---|
| **Web app / HTTP API** | `next`/`express`/`fastify`/`vite`/`nest` server, route files, a dev URL/port | **Shannon** — `npx @keygraph/shannon` (full OWASP exploitation) |
| **AI / LLM pipeline** | prompt assembly, `@anthropic-ai/sdk`/`openai`, tool-use, agent loop, RAG/vector store | **Live prompt-injection / tool-abuse probes** (runtime form of Layer 8 — inject into the real prompt sinks, observe side-effects) |
| **CLI / library / SDK** | `bin` entry, no network listener, exports only | **Targeted PoC** — arg/path-injection + sandboxed exec of the flagged code paths; if no safe harness, static-only |
| **Infra / IaC / scripts** | shell/PowerShell, Terraform, Dockerfiles, cron/systemd | **Config + exec review with sandboxed dry-run** — never mutate live infra |
| **Desktop / Electron / mobile** | Tauri/Electron main, RN/native | Probe the local IPC/HTTP surface if one exists; else static-only |
| **No safe dynamic harness** | — | **Declare "dynamic validation N/A — static-only"** with rationale; deliver the static report |

If the project exposes **multiple** surfaces (e.g. a Next.js app that is also an LLM agent), run the
applicable validators and merge all results.

### Precondition gate — required before ANY live execution (every archetype, not just web)

Run these in order; if any fails, **abort Phase 5** and deliver the static report.

1. **Explicit user opt-in** for live execution.
2. **Branch guard (hard rule, non-negotiable, overrides user insistence).** Resolve the target repo branch:
   `git -C <repo> rev-parse --abbrev-ref HEAD`. If it is `main`, `master`, `production`, `prod`, a detached
   `HEAD`, or matches `release/*` → **ABORT**, print:
   *"Live validation blocked: protected branch '<branch>'. Switch to a dev/feature branch to run dynamic validation."*
   Do NOT proceed. (Protected-branch list is the single source of truth; extend here if needed.)
3. **Authorization + non-production confirm.** "Do you own this / have written authorization?" and the target
   is local / staging / sandbox — **never** a production deployment. Stop if no or uncertain.
4. **Validator prereqs.** Shannon path: Docker daemon running + a credential present
   (`CLAUDE_CODE_OAUTH_TOKEN` preferred — reuses the Claude subscription — or `ANTHROPIC_API_KEY`).

### Execute + focus

- **Focus from static results** — steer each validator to prove the highest-value P0/P1 candidates first.
  - Shannon: there is **no `--scope` flag** — narrow via a config YAML (`-c target-config.yaml`: include/exclude
    paths, login flow, scope rules) and prioritise the highest-risk areas the static pass flagged.
  - LLM probes: target exactly the prompt sinks / tool-use paths flagged in Layer 8.
- **Web path command** — `npx @keygraph/shannon start -u <url> -r <repo> [-c config.yaml] [-w <name>] [-o <out>]`.
  Localhost auto-maps to `host.docker.internal` on Docker Desktop. Display the full command and wait for
  confirmation before launch. Full run ≈ 1–1.5 hr (Pre-Recon → Recon → Vuln Analysis → Exploitation →
  Reporting); monitor via `npx @keygraph/shannon logs <name>` / `status` / the workflow UI at
  `http://localhost:8233`. Add `--pipeline-testing` for a fast, low-token dry run (use for the Phase 5 smoke test).
- **Merge** — fold results into report section 5 (above), annotating each static finding's validation status
  and appending validator-only findings.

Full runbook (engine setup, Docker health-check, flags, localhost handling, the non-web validator recipes,
report parsing, troubleshooting): [`resources/shannon-dynamic-validation.md`](resources/shannon-dynamic-validation.md).

---

## Severity rubric

- **P0** — block deploy. Active exploit possible by remote unauthenticated attacker, or any data leak / privilege escalation / RCE.
- **P1** — high. Exploitable with auth or modest pre-conditions. Auth bypass, IDOR, stored XSS, secret leak.
- **P2** — medium. Defense-in-depth gap, missing header, weak rate-limit, info disclosure on errors.
- **P3** — low / informational. Best-practice deviation, hardening opportunity, deprecated dep without known CVE.

---

## Rules

1. **Paranoid mode** — if unsure whether something is exploitable, flag with rationale. Don't trust comments / docs / variable names — re-derive from code.
2. **No silent assumptions** — if you can't see the surrounding context (e.g., RLS policy file missing), call it out as an open question.
3. **Cross-reference prior audits** — if `docs/security/AUDIT_FINDINGS_*.md` or similar exist, cite findings by ID and mark "PRE-EXISTING" when not new. Do not re-list known fixes; do supplement with newly found gaps.
4. **No remediation code by default** — this skill outputs an audit report. Implementation is a separate engagement unless the user explicitly asks.
5. **Save report to disk** — write to `docs/security/RED_TEAM_AUDIT_<YYYY-MM-DD>.md` and surface inline summary.
6. **Layer agents return uniform mini-format** so merge is mechanical:
   ```
   ID | severity | layer | file:line | title | exploit-1liner | fix-1liner
   ```
7. **Read-only by default** — Phases 1–4 are pure static review: no file deletion, no migration runs, no live
   API probing. **Live exploitation occurs ONLY in opt-in Phase 5**, and only after its precondition gate
   passes (explicit opt-in + branch guard refusing `main`/`master`/`prod`/`release/*` + authorization +
   non-production target). Phase 5 never modifies the target's source — it analyzes and exploits a running
   instance in an isolated sandbox. If any gate condition is unmet, stay read-only and deliver the static report.

## Cross-references

- Field-vanishing / pipeline-drift bugs: see [`performing-full-file-audits/resources/pipeline-tracing.md`](../performing-full-file-audits/resources/pipeline-tracing.md). Many privilege-escalation chains start with a field silently dropped or shape-mismatched between layers.
- Architectural-invariant violations as attack surface: [`performing-full-file-audits/resources/invariant-audit.md`](../performing-full-file-audits/resources/invariant-audit.md).
- **Phase 5 dynamic validation runbook** (archetype routing, Shannon engine setup, branch guard, non-web validators, report merge, troubleshooting): [`resources/shannon-dynamic-validation.md`](resources/shannon-dynamic-validation.md).
- **Prompt-injection probe playbook** (technique battery + payload templates, indirect/2nd-order injection harness, canary-only rule, non-determinism retry rule, anti-patterns): [`resources/ai-prompt-injection.md`](resources/ai-prompt-injection.md).
