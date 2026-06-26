# Security Check Patterns & Examples

Detailed grep patterns, correct/incorrect code examples, and references for Phase 5 of the audit.

## Frontend XSS Patterns

### dangerouslySetInnerHTML / innerHTML
```
Grep: dangerouslySetInnerHTML|\.innerHTML\s*[+=]
```
**Incorrect:** `<div dangerouslySetInnerHTML={{ __html: userComment }} />`
**Correct:** `<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userComment) }} />`

### href/src injection
```
Grep: href=\{[^}]*(?:user|param|query|input|search|data)|src=\{[^}]*(?:user|param|query|input)
```
Verify values don't come from unsanitized user input. Block `javascript:` protocol:
```ts
const safeHref = href.startsWith('http://') || href.startsWith('https://') || href.startsWith('/') ? href : '#';
```
> **Note:** Static asset paths and Next.js `<Link>` with hardcoded routes are safe. Manually review any dynamic values derived from URL params, database fields, or user input.

### DOM injection via URL params
Check `useSearchParams()`, `useParams()`, `location.search`, `location.hash` — values rendered without sanitization are XSS vectors.

## Sensitive Data Patterns

### Client bundle leakage
```
Grep: process\.env\.(?!NEXT_PUBLIC_)
```
In `'use client'` files, only `NEXT_PUBLIC_*` vars are safe. Also check for API keys in client-side fetch calls, tokens in React state, secrets in `console.log()`.

> **Note:** False positives in `next.config.ts`, `middleware.ts`, and server-only files are expected and safe. Only flag occurrences in files with `'use client'` directive.

### Storage misuse
```
Grep: localStorage\.(setItem|getItem).*(key|token|secret|password|credential)
```
Tokens/keys should use `sessionStorage` (cleared on tab close) or HTTP-only cookies, never `localStorage`.

## Backend Injection Patterns

### SQL injection
```
Grep: f"SELECT.*\{|"SELECT"\s*\+|`SELECT.*\$\{
```
All queries must use parameterized queries or ORM/SDK. Watch for raw SQL in `.rpc()` calls.

### Command injection
```
Grep: os\.system\(|subprocess\.call.*shell=True|eval\(|exec\(|child_process\.exec\(
```
These must never include user input.

### Missing auth on API routes
```
Grep: export async function (POST|PATCH|PUT|DELETE)
```
Verify each match has an auth check (`getAuthContext()` or equivalent) in the same file. Flag unprotected mutation routes.

## Rate Limiting

### Detection — missing rate limiting
```bash
# Find all route handlers
grep -rn "export async function GET\|export async function POST\|export async function PUT\|export async function DELETE\|export async function PATCH" app/api/ --include="*.ts"

# Check if any rate limiting is applied
grep -rn "rateLimit\|rateLimiter\|rate-limit\|throttle\|upstash" --include="*.ts" --include="*.js"
```
**Red flag:** First search returns results; second returns nothing → rate limiting is missing entirely.

### Next.js App Router implementation
```ts
// lib/rate-limit.ts
import { NextRequest, NextResponse } from 'next/server';

const rateLimitMap = new Map<string, { count: number; resetTime: number }>();

export function rateLimit(config: { windowMs: number; maxRequests: number }) {
  return function checkRateLimit(req: NextRequest): NextResponse | null {
    const ip = req.headers.get('x-forwarded-for') ?? req.ip ?? 'unknown';
    const now = Date.now();
    const record = rateLimitMap.get(ip);
    if (!record || now > record.resetTime) {
      rateLimitMap.set(ip, { count: 1, resetTime: now + config.windowMs });
      return null;
    }
    if (record.count >= config.maxRequests) {
      return NextResponse.json(
        { error: 'Too many requests. Please try again later.' },
        { status: 429 }
      );
    }
    record.count++;
    return null;
  };
}
```

Usage in a route handler:
```ts
const limiter = rateLimit({ windowMs: 60_000, maxRequests: 30 });
const authLimiter = rateLimit({ windowMs: 15 * 60_000, maxRequests: 5 }); // stricter for auth

export async function POST(req: NextRequest) {
  const limited = limiter(req);
  if (limited) return limited;
  // ... handler logic
}
```

> **Production note:** In-memory `Map` doesn't share state across serverless instances. Replace with [Upstash Redis rate limiting](https://upstash.com/docs/redis/sdks/ratelimit-ts/overview) for multi-instance deployments.

## IDOR — Insecure Direct Object References

Any route that accepts an ID param and queries by it without scoping to the requesting user allows any authenticated user to access any other user's data.

### Detection
```bash
# Dynamic route segments in Next.js
grep -rn "params\.\(id\|userId\|[a-zA-Z]*Id\)" app/api/ --include="*.ts"

# Direct ID queries — scan for missing ownership scope
grep -rn '\.eq("id"' app/api/ --include="*.ts"
```

**Vulnerable pattern:**
```ts
// Anyone authenticated can read any invoice by guessing/incrementing the ID
export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  const { data } = await supabase.from('invoices').select('*').eq('id', params.id).single();
  return NextResponse.json(data);
}
```

### Fix — Option A: Ownership check in query
```ts
const { data: { user } } = await supabase.auth.getUser();
if (!user) return NextResponse.json({ error: 'Unauthorised' }, { status: 401 });

const { data } = await supabase
  .from('invoices')
  .select('*')
  .eq('id', params.id)
  .eq('user_id', user.id)   // Scope to requesting user
  .single();

// Return 404 — not 403 — to avoid confirming the resource exists
if (!data) return NextResponse.json({ error: 'Not found' }, { status: 404 });
```

### Fix — Option B: RLS (preferred for Supabase)
With correct RLS policies the Supabase client auto-scopes queries to the authenticated user. Defence in depth: even if app code misses an ownership check, RLS returns `null` data. Always use the anon-key client (not admin client) in route handlers.

### Fix — Option C: UUID PKs (prevent enumeration)
```sql
CREATE TABLE public.invoices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  -- ...
);
```
UUIDs prevent sequential enumeration but do **not** replace ownership checks — use alongside Option A or B.

## SSRF & Path Traversal

### Server-Side Request Forgery (SSRF)
Any endpoint that fetches a user-provided URL is an SSRF vector.

```
Grep: fetch\(.*(?:url|href|link|endpoint|uri)|axios\.(get|post)\(.*(?:url|href|link)|got\(.*(?:url|href)
```

**Incorrect:**
```ts
// User can request internal metadata endpoints, cloud provider secrets, etc.
const response = await fetch(req.body.url);
```

**Correct:**
```ts
import { URL } from 'url';
const parsed = new URL(req.body.url);
const blockedHosts = ['127.0.0.1', 'localhost', '169.254.169.254', '0.0.0.0'];
const blockedRanges = ['10.', '172.16.', '192.168.'];
if (blockedHosts.includes(parsed.hostname) || blockedRanges.some(r => parsed.hostname.startsWith(r))) {
  return res.status(400).json({ error: 'Invalid URL' });
}
if (!['http:', 'https:'].includes(parsed.protocol)) {
  return res.status(400).json({ error: 'Invalid protocol' });
}
```

### Path Traversal
Any endpoint that reads/writes files using user-provided paths.

```
Grep: readFile.*(?:path|file|name)|writeFile.*(?:path|file|name)|path\.join\(.*(?:req\.|params\.|query\.)
```

**Incorrect:**
```ts
const filePath = path.join('/uploads', req.query.filename);
const data = fs.readFileSync(filePath); // ../../../etc/passwd
```

**Correct:**
```ts
const resolved = path.resolve('/uploads', req.query.filename);
if (!resolved.startsWith('/uploads/')) {
  return res.status(400).json({ error: 'Invalid path' });
}
```

## CSRF Protection

### API route CSRF
Mutation routes (POST/PUT/PATCH/DELETE) should be protected against CSRF:
- **SameSite cookies:** `SameSite=Strict` or `SameSite=Lax` prevents cross-origin cookie sending.
- **CSRF tokens:** Custom header (e.g., `X-CSRF-Token`) validated server-side.
- **Origin check:** Validate `Origin` or `Referer` header matches allowed origins.

```
Grep: csrf|csrfToken|_csrf|x-csrf|SameSite
```
Absence of CSRF protection on mutation routes = finding.

### Server Actions
Next.js Server Actions have built-in CSRF protection via origin header checking. Verify it's not bypassed:
```
Grep: skipCSRFCheck|csrf.*false|csrf.*disable
```
Any match is CRITICAL.

## WebSocket & Realtime Security

### Supabase Realtime channels
```
Grep: supabase\.channel\(|\.on\(['"]postgres_changes|realtime.*subscribe|\.subscribe\(
```

**Checks:**
- [ ] Channel subscriptions happen after auth is validated (not before login completes)
- [ ] Channel names are not user-controlled (prevents subscribing to other workspaces' channels)
- [ ] RLS is enabled on all tables with Realtime subscriptions — RLS applies to Realtime
- [ ] Unsubscribe on component unmount to prevent stale connections

**Incorrect:**
```ts
// User can subscribe to any workspace's changes
const channel = supabase.channel(`workspace-${userInput}`);
```

**Correct:**
```ts
// Channel name derived from authenticated user's workspace
const { data: { user } } = await supabase.auth.getUser();
const channel = supabase.channel(`workspace-${user.workspace_id}`);
```

## File Upload Security

### Detection
```
Grep: upload|multer|formidable|busboy|supabase.*storage.*upload|\.from\(.*\)\.upload|createObjectURL|FileReader
```

### Checks
- [ ] **Server-side size limits:** Don't rely on client-side `maxSize` alone. Enforce in API route or middleware.
- [ ] **MIME type validation:** Check magic bytes (file signature), not just `Content-Type` header or file extension.
  ```ts
  // File extensions can be spoofed. Check magic bytes:
  // JPEG: FF D8 FF, PNG: 89 50 4E 47, PDF: 25 50 44 46
  const buffer = Buffer.from(await file.arrayBuffer());
  const signature = buffer.slice(0, 4).toString('hex');
  ```
- [ ] **Filename sanitization:** Strip `../`, path separators, null bytes, and special characters.
  ```ts
  const safeName = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
  ```
- [ ] **Storage bucket policies:** Supabase storage buckets have RLS policies. Public buckets should only contain truly public assets.
- [ ] **Executable content:** Block `.html`, `.svg` (XSS vectors via inline scripts), `.exe`, `.sh` unless explicitly needed.
- [ ] **Antivirus/scanning:** For user-uploaded content served to others, consider malware scanning.

## Hardcoded Secrets Patterns
```
Grep: sk-ant-api|sk-[a-zA-Z0-9]{32,}|Bearer [a-zA-Z0-9]{20,}
Grep: xoxb-|ghp_|eyJhbG|supabase.*service_role|SUPABASE_SERVICE_ROLE_KEY
Grep: password\s*=\s*["'][^"']{8,}|secret\s*=\s*["'][^"']{8,}
```

### Secrets in git history
```bash
git log --all --diff-filter=A -- "*.env" "*.key" "*.pem" "*credentials*"
git log -p --all -S "sk-ant-" -S "sk-" -- "*.ts" "*.tsx" "*.js"
```

## Security Headers Checklist

### Content Security Policy (CSP)
Check `next.config.ts` or `middleware.ts` for CSP header. Key directives:
- `default-src 'self'` — baseline restriction
- `script-src` — must NOT include `'unsafe-eval'` in production
- `connect-src` — allowlist actual external services, no wildcards
- `frame-ancestors 'none'` — prevents clickjacking (replaces X-Frame-Options)

### Required headers
| Header | Value | Purpose |
|--------|-------|---------|
| `X-Content-Type-Options` | `nosniff` | Prevents MIME sniffing |
| `X-Frame-Options` | `DENY` | Prevents clickjacking |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | Enforces HTTPS |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limits referrer leakage |
| `Permissions-Policy` | `camera=(), microphone=()` | Restricts browser APIs |

## Supply Chain Security

### Dependency audit
```bash
npm audit --audit-level=high    # or pnpm audit
```

### Lockfile verification
- Verify `package-lock.json` or `pnpm-lock.yaml` exists and is committed
- Missing lockfile = phantom dependency attacks possible

### Postinstall scripts
```bash
# Check for potentially dangerous postinstall scripts in dependencies
npm ls --json | node -e "..." # or manually review package.json scripts of deps
```

### Abandoned dependencies
Flag any dependency with >1 year since last npm publish. Check via:
```bash
npm view <package> time --json | tail -1
```

## Database Security (Supabase/Postgres)

### RLS verification
Every `CREATE TABLE` in migrations must have:
```sql
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;
CREATE POLICY "..." ON table_name FOR ... USING (...);
```

### RLS detection — live DB queries
Run these against the Supabase SQL editor to catch gaps:

```sql
-- Tables with RLS disabled
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND rowsecurity = false;

-- Tables with RLS enabled but zero policies (equally dangerous)
SELECT t.tablename
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
WHERE t.schemaname = 'public'
  AND t.rowsecurity = true
GROUP BY t.tablename
HAVING COUNT(p.policyname) = 0;
```

Both queries should return zero rows. Any result is a CRITICAL finding.

### RLS policy patterns

**Org/workspace-scoped access (typical for CENTR builds):**
```sql
CREATE POLICY "Org members can view org data"
  ON public.deals FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.org_members WHERE user_id = auth.uid()
    )
  );
```

**Role-based access (admin vs member):**
```sql
CREATE POLICY "Admins can manage all org data"
  ON public.deals FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.org_members
      WHERE user_id = auth.uid()
        AND org_id = deals.org_id
        AND role = 'admin'
    )
  );
```

### RLS policy correctness
Policies must scope through workspace_id via the authenticated user's workspace lookup — not just `auth.uid()`. A missing workspace join = cross-workspace data access.

### Admin client usage
```
Grep: createAdminClient\(\)|service_role
```
Must only appear in server-side code (`lib/services/`, `app/api/`), never in client components.

## Authentication Patterns

### Supabase Auth v2 / PKCE
- Verify `auth.exchangeCodeForSession()` in callback route (not deprecated `auth.verifyOtp()`)
- Verify `createBrowserClient` and `createServerClient` from `@supabase/ssr` (not deprecated `createClientComponentClient`)
- Verify middleware refreshes session on each request

### OAuth state validation
```
Grep: state.*param|oauth.*state|csrf.*token
```
OAuth callbacks must validate the `state` parameter to prevent CSRF.

## References
- [OWASP Secure Coding Practices](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)
- [OWASP Top 10 2021](https://owasp.org/www-project-top-10/)
- [Next.js Security Headers](https://nextjs.org/docs/app/api-reference/config/next-config-js/headers)
- [Supabase RLS Guide](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [npm audit docs](https://docs.npmjs.com/cli/audit)
