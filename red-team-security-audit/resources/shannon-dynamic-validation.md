# Phase 5 — Dynamic Validation Runbook

Detailed mechanics for the optional live-exploitation arm of `red-team-security-audit`. The SKILL.md
Phase 5 section is the contract; this file is the operator's manual. **Live execution only after the
Phase 5 precondition gate passes** (opt-in + branch guard + authorization + non-production target).

---

## 0. When this runs

Static Phases 1–4 already produced the report. Phase 5 converts *potential* findings into *proven* ones
by exercising a running instance. It is opt-in. If the gate fails or no safe harness exists, you stop and
the static report stands — that is a valid, complete outcome, not a failure.

---

## 1. Archetype routing (Step 5.0)

Profile from code, dependencies, and entrypoints — **not** from the folder name or assumptions.

| Archetype | Detection signals | Validator |
|---|---|---|
| **Web app / HTTP API** | `next`/`express`/`fastify`/`nest`/`koa`/`vite preview`/`django`/`flask`/`rails`; route dirs (`app/api`, `routes/`, `pages/api`); a `dev`/`start` script that binds a port | **Shannon** (§3–4) |
| **AI / LLM pipeline** | `@anthropic-ai/sdk`, `openai`, `langchain`, prompt-template files, tool/function-calling, RAG/vector store (`pgvector`, `pinecone`, `chroma`) | **LLM probes** (§5) |
| **CLI / library / SDK** | `bin` field in package.json, `argparse`/`commander`/`yargs`/`click`, pure `exports`, no listener | **Targeted PoC + sandbox** (§6) |
| **Infra / IaC / scripts** | `.tf`, `Dockerfile`, `docker-compose`, `*.ps1`/`*.sh`, k8s manifests, cron/systemd units | **Config + dry-run** (§7) |
| **Desktop / Electron / mobile** | Tauri `src-tauri`, Electron `main`, React-Native/native | Probe local IPC/HTTP if present; else static-only |
| **None safe** | none of the above, or no runnable surface | **Declare "dynamic N/A — static-only"** with reason |

Multiple surfaces → run each applicable validator and merge. Record the chosen route + reason in report
section 5.

---

## 2. Precondition gate (hard rules)

Run in order; first failure aborts Phase 5.

1. **Opt-in** — user explicitly asked to exploit/prove/validate live.
2. **Branch guard** (applies to every archetype's live path):
   ```bash
   git -C "<repo>" rev-parse --abbrev-ref HEAD
   ```
   Protected (ABORT): `main`, `master`, `production`, `prod`, detached `HEAD`, `release/*`.
   Abort message: *"Live validation blocked: protected branch '<branch>'. Switch to a dev/feature branch."*
   Rationale: protected branches are what production deploys from; live exploits are mutative. Dev/feature
   branches isolate any side-effects from the shipping line.
3. **Authorization + non-production** — confirm ownership / written authz and that the target is
   local/staging/sandbox. Never a production URL.
4. **Validator prereqs** — for Shannon: Docker daemon up + credential set (§3).

---

## 3. Shannon — one-time engine setup (web/API path)

Prereqs: Node 18+ (have v24), Git, Docker Desktop. Credential below.

**a. Start Docker daemon** (Windows):
```powershell
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
# poll until ready:
do { Start-Sleep 5; docker info --format '{{.ServerVersion}}' 2>$null } until ($LASTEXITCODE -eq 0)
```

**b. Credential — reuse the Claude subscription (preferred, no extra billing):**
```powershell
claude setup-token              # generates a token; run interactively yourself
setx CLAUDE_CODE_OAUTH_TOKEN "<token>"   # persist for future shells
$env:CLAUDE_CODE_OAUTH_TOKEN = "<token>" # current shell
```
Alternative: `setx ANTHROPIC_API_KEY "sk-ant-..."` (paid, pay-per-token). Shannon also accepts AWS Bedrock
(`CLAUDE_CODE_USE_BEDROCK=1`) / Google Vertex (`CLAUDE_CODE_USE_VERTEX=1`). Never print the secret back;
verify only with `if ($env:CLAUDE_CODE_OAUTH_TOKEN) {"set"} else {"missing"}`.
Recommended for large runs: `setx CLAUDE_CODE_MAX_OUTPUT_TOKENS 64000`.

**c. Initialize the engine** (configures credentials + prepares the worker; state lives in `~/.shannon/`):
```powershell
npx @keygraph/shannon setup
```
`setup` is the interactive credential-config step. If you've already exported `CLAUDE_CODE_OAUTH_TOKEN`
(or `ANTHROPIC_API_KEY`), the engine picks it up and `setup` mainly confirms/stores config. Run it
yourself if it prompts. Other engine subcommands: `status`, `logs <workspace>`, `workspaces`,
`stop [--clean]`, `uninstall`.

---

## 4. Shannon — run (web/API path)

```powershell
# target app MUST be running and reachable first (start its dev server)
npx @keygraph/shannon start -u http://localhost:<port> -r "<repo path>" -w <workspace> -o ".\shannon-out"
# fast, low-token dry run (smoke test):
npx @keygraph/shannon start -u http://localhost:<port> -r "<repo path>" --pipeline-testing
```

Real `start` flags (from `npx @keygraph/shannon help`): `-u/--url` (required), `-r/--repo` (required),
`-c/--config <yaml>`, `-o/--output <dir>` (copy deliverables out), `-w/--workspace <name>` (auto-resumes if
exists), `--pipeline-testing` (minimal prompts, fast), `--debug` (keep worker container for log inspection).
**There is no `--scope` flag.**

- **Scope / focus** — control via a config YAML passed with `-c`: include/exclude paths, login flow, scope
  rules. Steer it at the P0/P1 areas the static pass flagged. Omit `-c` for a full sweep.
- **Localhost** — Docker Desktop auto-translates `http://localhost:{PORT}` → `http://host.docker.internal:{PORT}`
  inside the worker (Windows/macOS). On Linux, pass `host.docker.internal` explicitly or use host networking.
- **Workspace / resume** — `-w <name>` names a session and auto-resumes if it already exists.
- **Auth'd targets** — if the app needs login or has scope rules, create a `target-config.yaml`
  (login flow, creds, include/exclude paths) and pass it with `-c`.
- **Confirm before launch** — display the full command; wait for the user's go. Monitor via
  `npx @keygraph/shannon logs <workspace>`, `npx @keygraph/shannon status`, or the workflow UI at
  `http://localhost:8233`, across Pre-Recon → Recon → Vuln Analysis → Exploitation → Reporting (≈ 1–1.5 hr;
  far faster with `--pipeline-testing`).
- **Read results** — deliverables copy to your `-o` dir; full state lives under `~/.shannon/`. Parse by
  severity; each proven finding carries a reproducible PoC. LLM output may contain inaccuracies —
  human-review every finding.

---

## 5. AI / LLM-pipeline validator (non-web live path)

When the target is (or also is) an LLM pipeline, validate Layer-8 static findings at runtime instead of /
in addition to Shannon:

- **Identify the real sinks** — where user-controlled text enters a prompt (system/user/tool args), and where
  model output causes side-effects (DB write, email/calendar mutation, tool calls).
- **Inject** crafted payloads into those exact fields against a running dev instance: instruction-override,
  delimiter-escape, tool-coercion, data-exfil, persona-switch, **structured-output coercion, combination
  (role-play + JSON), multi-turn reassembly, payload splitting, fake-delimiter**, and **indirect (2nd-order)
  injection** via a planted skill `.md` / mock MCP response / seeded RAG doc.
- **Observe** whether the injection changes control flow, triggers a side-effect without a HITL gate, or
  crosses tenant boundaries (response for another `user_id`).
- **Repeat each probe N times** — LLMs are non-deterministic; "held once" ≠ safe. A run that never succeeds
  across N attempts is `UNCONFIRMED`, not `SAFE`.
- **Prove or refute** each Layer-8 finding; mark `PROVEN`/`UNCONFIRMED`. Same branch-guard + authorization gate
  applies (it executes against a live agent with side-effects). Keep payloads non-destructive; never target a
  shared/prod model deployment.
- **Full payload battery + indirect-injection harness + anti-patterns → [`ai-prompt-injection.md`](ai-prompt-injection.md).**

---

## 6. CLI / library / SDK validator (targeted PoC)

No network surface → Shannon does not apply. Instead, write a **minimal, sandboxed PoC** for each P0/P1
static finding:

- **Arg / path injection** — invoke the binary with adversarial args / crafted paths that the static pass
  flagged (e.g. `../../` traversal, `$(...)`/backtick command injection, glob abuse) and confirm the unsafe
  effect.
- **Sandboxed exec** — run inside a throwaway dir / container; never against real user data. Capture the
  observable proof (file written outside intended root, command executed, etc.).
- **No safe harness** (e.g. the finding needs destructive input to prove) → mark `DYNAMIC N/A` and keep the
  static finding with its reasoning. Don't fabricate a PoC.

---

## 7. Infra / IaC / scripts validator

- **Static-config + exec review** of the actual manifests/scripts; no live mutation of real infrastructure.
- **Sandboxed dry-run** only — `terraform plan` (never `apply`), container build in a scratch context,
  script run with `--dry-run`/`-WhatIf` (PowerShell) against disposable resources.
- Anything that would touch live infra → `DYNAMIC N/A`, report the static finding + the manual repro steps.

---

## 8. Static ↔ dynamic merge format (report section 5)

Per finding from Phase 4 section 2:

```
<ID> | <validator> | PROVEN | repro: <1-liner or PoC path> | raw: <-o output dir or ~/.shannon/ workspace>
<ID> | <validator> | UNCONFIRMED | reason: <why live run didn't reproduce>
<ID> | —           | DYNAMIC N/A | reason: <no safe harness / archetype>
```

Then append **validator-only findings** (full Phase-4 finding format, new IDs) for anything the live run
surfaced that static missed. State up front: which validator ran, the archetype that routed it, the branch
it executed on, and the scope used.

---

## 9. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `failed to connect to the docker API … dockerDesktopLinuxEngine` | Daemon not up. Start Docker Desktop, wait for `docker info` to return a `ServerVersion`. |
| Shannon: missing credential | No `CLAUDE_CODE_OAUTH_TOKEN`/`ANTHROPIC_API_KEY` in the shell. Set + re-open shell (`setx` persists for *new* shells only). |
| Worker can't reach the app | App not running, wrong port, or Linux host. Confirm the dev server is up; use `host.docker.internal` / `--network host` on Linux. |
| Scan "finds nothing" on a real web app | Auth-gated routes. Provide `target-config.yaml` with the login flow. |
| Branch guard fired but user insists | Non-negotiable. Have them `git switch -c <dev-branch>`; never override on `main`/`prod`. |
| Run too slow / token-heavy | Narrow scope via a `-c config.yaml` (include/exclude paths) and/or use `--pipeline-testing`; set `CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000`. |

---

## 10. Safety invariants

- Live exploitation is **opt-in**, **dev-branch-only**, **non-production**, **authorized**.
- Source is never modified — analyze + exploit a running instance in an isolated sandbox.
- Every proven finding still requires human review (LLM output can be wrong).
- Updating this skill from upstream must preserve the branch guard in §2 and the Rule #7 carve-out in SKILL.md.
