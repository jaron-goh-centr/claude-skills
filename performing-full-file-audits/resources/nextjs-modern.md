# Next.js Modern Patterns (14 / 15 / 16)

Detailed checks for async request APIs, Server Actions, React Server Components, React 19, edge runtime, and Turbopack.

## Async Request APIs (Next.js 15+)

In Next.js 15, several request-time APIs became async and must be `await`ed.

### What changed
| API | Before (Next.js 14) | After (Next.js 15+) |
|-----|---------------------|---------------------|
| `cookies()` | Synchronous | `await cookies()` |
| `headers()` | Synchronous | `await headers()` |
| `params` | Sync prop | `await params` |
| `searchParams` | Sync prop | `await searchParams` |

### Grep patterns
```
Grep: const.*=\s*cookies\(\)|const.*=\s*headers\(\)
```
Verify each match uses `await`. Missing `await` causes runtime errors or returns a Promise object instead of the value.

```
Grep: \bparams\b.*\.(slug|id|workspaceId)|searchParams\.(get|has|toString)
```
In Next.js 15+ page/layout components, `params` and `searchParams` are Promises:

**Incorrect (Next.js 15+):**
```ts
export default function Page({ params }: { params: { id: string } }) {
  const id = params.id; // params is a Promise, not an object
}
```

**Correct:**
```ts
export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
}
```

### `connection()` API
Next.js 15 introduced `connection()` from `next/server` to explicitly opt into dynamic rendering:
```ts
import { connection } from 'next/server';
export default async function Page() {
  await connection(); // Opts into dynamic rendering
  // ...
}
```
Use when a Server Component needs to be dynamic but doesn't call `cookies()` or `headers()`.

## Server Actions (`'use server'`)

### What they are
Every function marked with `'use server'` (at file top or inline) is automatically exposed as an HTTP POST endpoint. They bypass route middleware entirely.

### Security checklist
- [ ] **Auth check required:** Every server action must validate the user session independently — middleware does NOT protect server actions.
```ts
// INCORRECT — no auth check
'use server'
export async function deleteAccount(id: string) {
  await db.from('accounts').delete().eq('id', id);
}

// CORRECT — explicit auth
'use server'
export async function deleteAccount(id: string) {
  const { user } = await getAuthContext();
  if (!user) throw new Error('Unauthorized');
  await db.from('accounts').delete().eq('id', id).eq('workspace_id', user.workspaceId);
}
```

- [ ] **Input validation:** Server actions receive `FormData` without type safety. Always validate with Zod or equivalent.
```ts
'use server'
const schema = z.object({ name: z.string().min(1), email: z.string().email() });
export async function createContact(formData: FormData) {
  const parsed = schema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) throw new Error('Invalid input');
  // ...
}
```

- [ ] **Return value safety:** Server actions return values to the client. Never return sensitive data (internal IDs, tokens, full error stacks).

- [ ] **Rate limiting:** Server actions are HTTP endpoints — they need rate limiting just like API routes.

### Grep patterns
```
Grep: 'use server'|"use server"
```
For each match, verify auth + validation + safe return values.

## React 19 Patterns

### `use()` hook
Replaces `useContext()` and can unwrap Promises in client components:
```ts
import { use } from 'react';

// Unwrap context (replaces useContext)
const theme = use(ThemeContext);

// Unwrap promises (new in React 19)
const data = use(fetchPromise); // Must be used with Suspense boundary
```

### `useActionState()` (replaces `useFormState`)
```
Grep: useFormState
```
Flag as deprecated in React 19. Replace with `useActionState`:

**Deprecated:**
```ts
import { useFormState } from 'react-dom';
const [state, formAction] = useFormState(serverAction, initialState);
```

**Current:**
```ts
import { useActionState } from 'react';
const [state, formAction, isPending] = useActionState(serverAction, initialState);
```
Note: `useActionState` also returns `isPending` — no need for separate `useFormStatus()` in many cases.

### `useOptimistic()`
Pattern for optimistic UI updates with server actions:
```ts
import { useOptimistic } from 'react';
const [optimisticItems, addOptimistic] = useOptimistic(items, (state, newItem) => [...state, newItem]);
```

### Native form actions
React 19 supports `action` prop directly on `<form>`:
```tsx
<form action={serverAction}>
  <input name="email" />
  <button type="submit">Submit</button>
</form>
```
This replaces manual `onSubmit` + `preventDefault()` patterns for server action forms.

### React Compiler
Check if the React Compiler is enabled:
```
Grep: reactCompiler|babel-plugin-react-compiler|experimental.*reactCompiler
```
In `next.config.ts`:
```ts
experimental: { reactCompiler: true }
```
When enabled:
- `useMemo`, `useCallback`, `React.memo` are unnecessary — the compiler auto-memoizes
- Flag files still using manual memoization as cleanup candidates (not bugs)
- Verify the codebase doesn't use patterns the compiler can't optimize (mutating objects in render, reading `ref.current` during render)

## React Server Components (RSC) Boundaries

### The `'use client'` boundary
When a component has `'use client'`, everything it imports also becomes client code. This creates security and performance implications.

### Checks
- [ ] **No server-only imports in client components:**
```
Grep in 'use client' files: next/headers|cookies\(\)|createServerClient|createAdminClient|server-only
```
These will either error at build time or leak server code to the client bundle.

- [ ] **No client hooks in Server Components:**
```
Grep in non-'use client' files: useState|useEffect|useRef|useCallback|useMemo|useReducer|useContext
```
Files without `'use client'` are Server Components by default. Using hooks in them causes runtime errors.

- [ ] **Unnecessary `'use client'`:** Components that only render JSX with props (no hooks, no event handlers, no browser APIs) should be Server Components. Flag `'use client'` files that don't use any client-only APIs.

- [ ] **`cookies()` and `headers()` context:** These can only be called in:
  - Server Components (during render)
  - Route Handlers (`route.ts`)
  - Server Actions (`'use server'`)
  - Middleware
  They CANNOT be called in `generateMetadata`, `generateStaticParams`, or cached functions without `noStore()`. In Next.js 15+, they must be `await`ed.

### Server-only protection
Projects should use the `server-only` package to prevent accidental client imports:
```ts
import 'server-only'; // Throws build error if imported from client
```
Check if sensitive modules (DB clients, admin Supabase client, secret utilities) include this import.

## Edge Runtime

### What runs on edge
- `middleware.ts` always runs on edge runtime
- Route handlers with `export const runtime = 'edge'`
- Pages with `export const runtime = 'edge'`

### Limitations to check
- [ ] **No Node.js APIs:** Edge runtime doesn't support `fs`, `path`, `crypto` (Node version), `Buffer` (from `node:buffer`), `child_process`, `net`, `tls`, or any Node.js built-in.
- [ ] **Limited npm packages:** Many packages use Node.js APIs internally. If middleware imports a heavy library, it may fail silently or at deploy time.
- [ ] **No native modules:** `bcrypt`, `sharp`, `canvas` etc. won't work. Use `bcryptjs` or similar pure-JS alternatives.
- [ ] **Request size limits:** Edge functions typically have 1MB request/response limits (varies by platform).

### Grep pattern for edge runtime files
```
Grep: runtime.*=.*['"]edge['"]|middleware\.(ts|js)
```
Then verify no Node.js imports in those files:
```
Grep in edge files: require\(['"]fs['"]|require\(['"]path['"]|require\(['"]crypto['"]|from ['"]node:
```

### Middleware matcher coverage
```ts
// Check that the matcher covers all protected routes
export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|auth|api/webhooks).*)',
  ],
};
```
Verify the matcher doesn't accidentally exclude API routes or dashboard pages that need auth.

## Turbopack vs Webpack

### Detection
```bash
# Check package.json scripts
grep -E "turbo|--turbo|--webpack" package.json
```
Next.js 15+ uses Turbopack by default for `next dev`. Production `next build` still uses webpack (as of Next.js 16).

### What to check
- [ ] **Webpack config compatibility:** If `next.config.ts` has a `webpack:` function, it's ignored under Turbopack. Verify any custom webpack plugins have Turbopack equivalents.
- [ ] **Dev/prod parity:** If dev uses Turbopack but build uses webpack, behavior can differ. Test both.
- [ ] **Module resolution differences:** Turbopack may resolve imports differently than webpack. Watch for `Module not found` errors that only appear in one bundler.
- [ ] **CSS handling:** Turbopack handles CSS differently. Custom PostCSS plugins or CSS modules with edge-case syntax may behave differently.

## Performance Patterns

### Dynamic imports for heavy libraries
```ts
// INCORRECT — loads recharts on page load
import { BarChart } from 'recharts';

// CORRECT — loads recharts on demand
const BarChart = dynamic(() => import('recharts').then(m => m.BarChart), { ssr: false });
```

Libraries to check: `recharts`, `chart.js`, `pdf-lib`, `jspdf`, `xlsx`, `monaco-editor`, `highlight.js`, `three`, `mapbox-gl`.

### Image optimization
```
Grep: <img\s|<img>
```
Replace raw `<img>` with `<Image>` from `next/image`. Verify `width`, `height`, and `sizes` props are set.

### Suspense boundaries
Every page with async data should have either:
- A `loading.tsx` file in its directory
- Explicit `<Suspense fallback={...}>` wrapping async components

Without these, the entire page blocks until all data loads.
