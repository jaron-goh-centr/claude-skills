---
name: auditing-optimizing-securing
description: Performs a comprehensive code audit, removes redundant code, and conducts a deep security sweep (BE, FE, and AI logic). Use when the user wants to polish a project, ensure production-readiness, or verify security.
---

# Auditing, Optimizing, and Securing Codebases

## When to use this skill
- Before a production release or major merge
- When code feels "bloated" or performance is degrading
- To identify security vulnerabilities in Backend, Frontend, or AI Agent logic
- To ensure all functional requirements are actually met by the implementation

## Workflow
You must follow this pipeline in order. Do not skip a phase unless specifically instructed by the user.

1.  **Phase 1: Functional Logic Audit**
    - [ ] **Trace Entry Points:** Identify all public APIs, entry files, and user-facing inputs.
    - [ ] **Data Flow Analysis:** Follow data from input through processing to storage/output.
    - [ ] **Feature Gap Check:** Cross-reference current code against the project specifications.
    - [ ] **Error Edge Cases:** Verify every async call or external I/O has a dedicated error handler.
2.  **Phase 2: Bloat & Redundancy Removal**
    - [ ] **Dead Code Elimination:** Identify and remove unused imports, functions, and variables.
    - [ ] **Dependency Audit:** Check for heavy packages used for trivial tasks.
    - [ ] **Logic Consolidation:** Refactor duplicate logic or utility functions into single shared sources.
    - [ ] **YAGNI Review:** Remove features or code paths that aren't currently required.
3.  **Phase 3: Security & AI Resilience Sweep**
    - [ ] **Backend (OWASP Top 10):** Check for SQL injection, insecure auth, broken access control, and data exposure.
    - [ ] **Rate limiting:** Every public/auth API route must have rate limiting. Auth/payment endpoints need stricter limits (5 req/15 min). Detection: grep for all route exports, then grep for `rateLimit|rateLimiter|upstash` — if second returns nothing, it's missing entirely.
    - [ ] **IDOR (Insecure Direct Object Reference):** Route handlers with ID path params must scope DB queries to the requesting user (`.eq("user_id", user.id)`) or rely on RLS. Return 404 — not 403 — when access is denied.
    - [ ] **RLS (Supabase):** Run live-DB detection queries — tables with `rowsecurity = false`, and tables with RLS enabled but zero policies. Both must return zero rows.
    - [ ] **Frontend Safety:** Verify input sanitization (XSS) and secure handling of sensitive tokens.
    - [ ] **AI-Specific Security:** 
        - [ ] Check for prompt injection vulnerabilities in dynamic prompts.
        - [ ] Verify handling of "Hallucinations" in critical logic paths.
        - [ ] Ensure AI output is sanitized before being rendered or executed.

## Instructions

### Logic Audit Methodology
- Assume nothing works as intended. Verify every branch of every `if` statement.
- Use `grep-search` to find all instances of `@todo` or `FIXME`.

### Security Methodology
- **Backend:** Check environment variables for secrets that should be in a vault. Check SQL queries for lack of parametrization.
- **AI Agent Security:** Look for patterns where user input is concatenated directly into system instructions. Recommend using "XML-tag delimiters" or "bracketed templates" to prevent injection.

## Output Template: Audit Report
When this skill is completed, provide the user with a summary in this format:

### Audit Summary
- **Logic Issues Found:** [X]
- **Lines of Code Removed:** [X]
- **Security Vulnerabilities Identified:** [X]

### Severity Rubric (aligned with `performing-full-file-audits` and `red-team-security-audit`)
- **P0** — block deploy; exploit possible by remote unauth attacker, secret leak, RLS gap on user data, RCE, broken core feature.
- **P1** — high; auth-required exploit (IDOR, stored XSS, prompt injection), regression of approved behavior.
- **P2** — medium; defense-in-depth gap, missing headers, weak rate-limit, schema drift.
- **P3** — low / informational; hardening, deprecated dep without CVE, doc gaps.

### Detailed Findings
- **P0 / P1 (priority):** [List]
- **Improvements Made:** [List]
- **Action Items for User:** [List]
