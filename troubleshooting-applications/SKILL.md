---
name: troubleshooting-applications
description: Designs resilient error-handling ARCHITECTURE — exception hierarchies, Result types, retry/backoff, circuit breakers, error aggregation, graceful degradation. Use when implementing error handling in new code, hardening an API or integration against failure, or when the user asks for retry logic, circuit breakers, fallbacks, or fault tolerance. NOT for diagnosing a live bug or failing test — use superpowers:systematic-debugging (root-cause diagnosis) or reflect (auto-retry on error output) for those.
---

# Error-Handling Architecture

## Scope boundary (read first)
This skill DESIGNS error handling. It does not diagnose failures.
- Live bug, failing test, stack trace in hand → `superpowers:systematic-debugging`
- Fix attempt failed, need error-feedback retry loop → `reflect`
- CENTR-stack (Next.js + Supabase + Claude API) test/debug sequence → `centr-test-debug`

**Conflict rule:** if the codebase already has an established error-handling convention (error classes, a Result lib, an existing retry util), conform to it and surface the mismatch — do not impose these patterns over it.

## When to use
- Implementing error handling in new features or API boundaries
- Wrapping external calls (HTTP, DB, LLM APIs) for fault tolerance
- Adding retry, circuit breaker, fallback, or aggregation logic
- Improving error messages and logging discipline

## Workflow
1. **Classify the failure mode**: recoverable (network timeout, invalid input, rate limit) vs unrecoverable (OOM, programming bug, corrupted invariant).
2. **Pick the mechanism — decision rule:**
   - Expected failure the caller can act on (validation, not-found, rate limit) → **Result type**
   - Programmer invariant violated (impossible state, contract breach) → **throw/panic**
   - Unrecoverable resource exhaustion → **crash + supervisor/platform restart** — never catch-and-limp
3. **Apply the matching resilience pattern** (defaults below — override only with a stated reason).
4. **Validate**: fast failure, meaningful messages, correct log levels, nothing swallowed.
5. **Clean up**: `finally` / `defer` / context managers for teardown on every path.

## Concrete defaults (use these numbers unless the project specifies otherwise)
- **Retry**: 3 attempts, base 200ms, exponential backoff with full jitter, cap 5s. Retry ONLY idempotent operations and transient errors (timeout, 429, 502/503/504). Never retry 4xx validation errors.
- **Circuit breaker**: OPEN after 5 consecutive failures within a 60s window; HALF_OPEN probe after 30s; CLOSE after 2 consecutive successes. While OPEN, fail fast or serve fallback — do not queue.
- **Timeouts**: every external call gets an explicit timeout. No unbounded awaits.

## Worked example (TypeScript — primary stack)
Result boundary + fallback + circuit breaker around an external call:

```typescript
type Result<T, E = AppError> = { ok: true; value: T } | { ok: false; error: E }

class AppError extends Error {
  constructor(message: string, public code: string, public details?: unknown) {
    super(message)
    Error.captureStackTrace?.(this, AppError)
  }
}

class CircuitBreaker {
  private failures = 0
  private state: 'CLOSED' | 'OPEN' | 'HALF_OPEN' = 'CLOSED'
  private openedAt = 0

  constructor(private threshold = 5, private resetMs = 30_000) {}

  async exec<T>(fn: () => Promise<T>): Promise<Result<T>> {
    if (this.state === 'OPEN') {
      if (Date.now() - this.openedAt < this.resetMs)
        return { ok: false, error: new AppError('circuit open', 'CIRCUIT_OPEN') }
      this.state = 'HALF_OPEN'
    }
    try {
      const value = await fn()
      this.failures = 0
      this.state = 'CLOSED'
      return { ok: true, value }
    } catch (e) {
      if (++this.failures >= this.threshold || this.state === 'HALF_OPEN') {
        this.state = 'OPEN'
        this.openedAt = Date.now()
      }
      return { ok: false, error: new AppError(String(e), 'UPSTREAM_FAILURE', e) }
    }
  }
}

// Usage: breaker + fallback at the call site
const breaker = new CircuitBreaker()
async function getRates(): Promise<Rates> {
  const res = await breaker.exec(() => fetchRatesFromApi({ timeoutMs: 3000 }))
  if (res.ok) return res.value
  const cached = await readCachedRates()
  if (cached) return cached            // graceful degradation
  throw res.error                       // no fallback available — surface it
}
```

## Other languages (deltas from the example)
- **Python**: `ApplicationError` base class with `message`/`code`/`details`; `@contextmanager` for commit/rollback/close; retry decorator with the defaults above.
- **Rust**: `Result<T, E>` + `?`; custom error enum with `From` impls for stdlib conversions. Panics only for invariant violations.
- **Go**: `(T, error)` returns; sentinel errors (`var ErrNotFound = errors.New(...)`) for expected cases, wrapped errors (`fmt.Errorf("...: %w", err)`) to preserve context.

## Universal patterns
- **Error aggregation**: collect all validation errors into one `AggregateError` instead of failing on the first — applies to form validation, batch jobs, multi-field parsing.
- **Graceful degradation**: `withFallback(primary, fallback)` — fallback must be cheaper and safe (cache, default, reduced feature); never a second full-cost call to the same failing system.

## Best practices
- Fail fast: validate input at the boundary.
- Preserve context: cause chain, metadata, timestamps — never `catch (e) {}`.
- Expected failures don't spam error logs; unexpected ones always do.
- Catch only where you can act; otherwise let it propagate.
- Typed errors over string matching.

## Edge cases
- **Async fan-out**: use `Promise.allSettled` (not `Promise.all`) when partial success is acceptable; aggregate the rejects.
- **Retry + circuit breaker together**: retries live INSIDE the breaker's `exec` call, so repeated retries count as one breaker attempt — otherwise retries triple the failure count and trip the breaker early.
- **Idempotency**: if the operation isn't provably idempotent (payments, sends, inserts without unique keys), do not retry — return the Result and let the caller decide.
- **Trust boundaries**: never simplify or remove validation/RLS/audit error paths (project invariant — these are exempt from ponytail simplification).
