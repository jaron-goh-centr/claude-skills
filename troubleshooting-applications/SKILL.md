---
name: troubleshooting-applications
description: Troubleshoots applications to resolve errors and implement robust error handling patterns. Use when the user asks to debug an issue, improve application reliability, or implement retry and circuit breaker patterns.
---

# Troubleshooting Applications & Error Handling

## When to use this skill
- Implementing error handling in new features
- Designing error-resilient APIs
- Debugging production issues
- Improving application reliability
- Creating better error messages for users and developers
- Implementing retry and circuit breaker patterns
- Handling async/concurrent errors
- Building fault-tolerant distributed systems

## Workflow
1.  **Analyze Error Context**: Determine if the error is recoverable (e.g., network timeout, invalid input) or unrecoverable (e.g., OOM, programming bug).
2.  **Select Error Handling Philosophy**:
    - *Exceptions*: For unexpected errors and exceptional conditions (disrupts control flow).
    - *Result Types*: For expected errors and validation failures (explicit success/failure).
    - *Panics/Crashes*: For unrecoverable errors.
3.  **Apply Relevant Pattern**: Implement Circuit Breaker, Error Aggregation, or Graceful Degradation based on the architecture scale.
4.  **Validate Error Handling**: Ensure fast failure, meaningful message generation, and appropriate logging levels without swallowing errors.
5.  **Clean up Resources**: Ensure `finally` blocks, defer, or context managers handle state teardowns properly.

## Instructions

### Python Error Handling
- **Custom Exception Hierarchy**: Create an `ApplicationError` base class with `ValidationError`, `NotFoundError`, etc., inheriting from it. Include `message`, `code`, and `details`.
- **Context Managers for Cleanup**: Use `@contextmanager` to construct `try...except...finally` blocks to safely commit, rollback, and close database sessions or file handles.
- **Retry with Exponential Backoff**: Use Python decorators to retry transient exceptions (like `NetworkError`) with exponential backoffs manually.

### TypeScript / JavaScript Error Handling
- **Custom Error Classes**: Create classes extending `Error` to append additional context (e.g. `code`, `statusCode`, `details`). Call `Error.captureStackTrace` in the constructor.
- **Result Type Pattern**: For explicit error handling, structure functions to return `Result<T, E> = { ok: true; value: T } | { ok: false; error: E }`.

### Rust & Go Error Handling
- **Rust**: Heavily rely on `Result<T, E>` and `Option<T>` for error propagation with the `?` operator. Create custom Enums representing Application errors and implement `From` for standard library conversions.
- **Go**: Use explicit `(*Type, error)` multiple return values. Declare Sentinel errors (e.g., `var ErrNotFound = errors.New(...)`) or struct-based Error implementations.

### Universal Patterns
- **Circuit Breaker**: Wrap functions calling external systems. Track a `CircuitState` (CLOSED, OPEN, HALF_OPEN) and trip to OPEN if a threshold of failures occurs in a specific time window.
- **Error Aggregation**: Collect multiple errors (e.g. when doing complex form validation) into an `ErrorCollector` class, eventually throwing an `AggregateError` instead of failing on the very first exception.
- **Graceful Degradation**: Supply `with_fallback(primary, fallback)` wrappers that try invoking a function, catching errors to seamlessly invoke a cached or default return value.

## Best Practices
- **Fail Fast:** Validate input early, fail quickly.
- **Preserve Context:** Include stack traces, metadata, timestamps.
- **Meaningful Messages:** Explain what happened and how to fix it.
- **Log Appropriately:** Error = log, expected failure = don't spam logs.
- **Handle at Right Level:** Catch where you can meaningfully handle.
- **Clean Up Resources:** Use try-finally, context managers, defer.
- **Don't Swallow Errors:** Log or re-throw, don't silently ignore.
- **Type-Safe Errors:** Use typed errors when possible.

## Resources
- `references/exception-hierarchy-design.md`: Designing error class hierarchies
- `references/error-recovery-strategies.md`: Recovery patterns for different scenarios
- `references/async-error-handling.md`: Handling errors in concurrent code
- `assets/error-handling-checklist.md`: Review checklist for error handling
- `assets/error-message-guide.md`: Writing helpful error messages
- `scripts/error-analyzer.py`: Analyze error patterns in logs
