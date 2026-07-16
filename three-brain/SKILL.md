---
name: three-brain
description: |
  Auto-routes work to GPT-5.5 (Codex) or Gemini 2.5 Pro. Claude drives; others are called tools.

  ━━━ NO-SELF-REVIEW LAW ━━━
  User asks to "check/review/look-over/proof/verify/audit/sanity-check" ANY work Claude just produced → MUST route to Codex. No self-review. No inline check. Route:
    git diff | codex exec --skip-git-repo-check "Review this diff. Flag bugs, risks, missing tests. Be specific."
  After: integrate findings. Append "(Routed via three-brain → Codex review.)"
  If Codex unavailable: say so explicitly. Do NOT self-review as fallback.
  Mixed artifacts (user wrote prompt, Claude wrote code): if Claude-generated content is in scope, FIRE.

  ━━━ FIRE WHEN ━━━
  • User asks to review/check/verify Claude's own output → Codex review (MUST-FIRE)
  • "tear apart / stress test / find what's wrong / break this" → DUAL adversarial (Codex + Gemini in parallel when Gemini auth alive; Codex-only otherwise)
  • Claude fails same op 2× in a row OR user says "I'm stuck / try GPT" → Codex rescue
  • Any request touching or targeting: src/auth/**, src/billing/**, **/migrations/**, **/deploy/**, **/.env*, **/secrets/**, **/policy/**, infra/**, **/Stripe*, **/Plaid*, **/jwt*, **/oauth* → forced DUAL adversarial BEFORE "done" (verb irrelevant — edit/refactor/plan/explain/design all fire)
  • "harden / stress-test a PLAN before building" → route to /grill-me-codex (no plan yet) or /codex-review (plan exists) — their loop, not this skill's
  • Video/audio/PDF artifact or YouTube URL in message (any size) → Gemini multimodal
  • "scan whole repo / find every place X / map architecture" → Gemini 1M-context
  • "ask all three / cross-architecture consensus" → parallel consensus mode
  • Ambiguous review verb targeting Claude's own output → FIRE (bias toward firing)

  ━━━ STAY ASLEEP ━━━
  • Explain/write/build/edit/plan on non-risky paths → Claude direct
  • "Review my draft / my notes" (user's own content, not Claude's output) → Claude
  • Casual chat, status, git/bash/grep, Q&A → Claude direct
  • Explicit /grill-me-codex, /grill-with-docs-codex, /codex-review, /codex-build invocations → they run their own Codex loop; three-brain must not double-fire

  ━━━ VERB ≠ SAFE ON RISKY PATHS ━━━
  Refactor/plan/explain/design targeting auth/billing/migrations/deploy/.env/secrets/policy/infra/Stripe/Plaid/jwt/oauth → FIRE anyway.
---

# Three-Brain Auto-Router

- **Claude** = builder, driver
- **Codex (GPT-5.5)** = reviewer, rescue
- **Gemini 2.5 Pro** = multimodal, long-context

## Startup check (once per session)

```bash
codex --version 2>&1 | head -1                                # expect 0.130+
gemini -m gemini-2.5-pro -p "ping" --skip-trust 2>&1 | tail -3 # AUTH check, not just version — IneligibleTierError = Gemini dead
```

Missing/failed → announce once, skip those routes, don't retry each turn. If Codex missing and a MUST-FIRE triggers, tell the user the mandatory route is unavailable — do not self-review.

**CLIProxyAPI resilience path (optional, if running locally):** `curl -sf http://localhost:8317/v1/models` confirms it's up. It holds an independent Codex OAuth credential (usable via `codex exec --profile cliproxy`, see `~/.codex/cliproxy.config.toml`) and an Antigravity-backed Gemini-family account exposed as OpenAI-compatible `/v1/chat/completions` — a second, separately-authenticated path for both legs below. Only invoked as a fallback when the primary path errors; never changes default routing.

- **Codex leg fallback:** any `codex exec` call below (review, rescue, adversarial leg, multi-round resume) that fails on auth/rate-limit → retry the same call once with `--profile cliproxy` appended before reporting Codex unavailable.
- **Gemini leg fallback (text/diff/file prompts only — not video/audio):** if the startup ping (line below) fails, retry the same prompt against `http://localhost:8317/v1/chat/completions` with a `gemini-3.x` model id (e.g. `gemini-3.1-pro-low`) instead of giving up on the Gemini leg. Video/audio prompts still need Gemini's native multimodal ingestion (the proxy doesn't replicate that) — those keep using the whisper/frame-extraction fallback further down, unchanged.

Gemini auth: fixed 2026-07-15 — free-tier OAuth ("Code Assist for individuals") was discontinued and threw `IneligibleTierError`. Switched `~/.gemini/settings.json` `security.auth.selectedType` to `gemini-api-key`, and `GEMINI_API_KEY` is set as a persistent user env var (AI Studio key). Always pass `-m gemini-2.5-pro` — without an explicit model, the CLI's internal router classifier calls a deprecated `gemini-2.5-flash-lite` model and throws noisy (but non-fatal) errors before falling back. Always pass `--skip-trust` in headless/non-interactive calls or it refuses to run outside a trusted folder.

If `gemini -p "ping"` ever regresses to `IneligibleTierError` again, the fix is: set `security.auth.selectedType` to `gemini-api-key` in `~/.gemini/settings.json` and ensure `GEMINI_API_KEY` env var holds a valid AI Studio key (aistudio.google.com/apikey) — the old `oauth-personal` type is permanently dead for individual accounts.

## Forced-route announcement

```
[three-brain] routing to Codex (adversarial-review) — risk path: src/auth/
[three-brain] handing off to Codex rescue — Claude failed 2× same test
```

User-requested routes: no announcement needed.

## Failure counter (HARD)

Deterministic counter. 2× same test fail / shell error / stalled edit on same path → MUST invoke Codex rescue. Announce. Send full context bundle: failing output, what was tried, relevant file content.

```bash
cat <bundle> | codex exec --skip-git-repo-check "Rescue mode. Claude tried 2x and failed. Full context attached. Solve from scratch."
```

Reset on: pass, goal change, or "keep trying."

## Gemini preprocessing

**Video:**
```bash
yt-dlp -f "best[ext=mp4][height<=720]" "<url>" -o /tmp/three-brain/in.mp4
ffmpeg -t 120 -i /tmp/three-brain/in.mp4 /tmp/three-brain/clip.mp4 -y
gemini -m gemini-2.5-pro --skip-trust -p "Timestamped findings [MM:SS]: graphics, text, actions. 800 words max." @/tmp/three-brain/clip.mp4
```

**Audio:**
```bash
ffmpeg -i <input> -vn -ac 1 -ar 16000 /tmp/three-brain/audio.wav -y
gemini -m gemini-2.5-pro --skip-trust -p "Timestamped transcript and findings [MM:SS]. 800 words max." @/tmp/three-brain/audio.wav
```

**PDF** (any size fires; preprocess to cap Gemini input):
```bash
qpdf --pages input.pdf 1-100 -- /tmp/three-brain/doc.pdf 2>/dev/null || cp input.pdf /tmp/three-brain/doc.pdf
gemini -m gemini-2.5-pro --skip-trust -p "Key claims, tables, charts with page numbers. 1000 words max." @/tmp/three-brain/doc.pdf
```

**Whole-codebase:**
```bash
/cc-gemini-plugin:gemini --dirs <paths> "Find every X. Return file:line list."
```

Always demand timestamps/page numbers/file:line citations — no flat summaries.

**Gemini-dead fallback (video/audio)** — proven pipeline, use only if the startup ping fails again:
```bash
yt-dlp -f "best[ext=mp4][height<=720]" "<url>" -o /tmp/three-brain/in.mp4
ffmpeg -t 120 -i /tmp/three-brain/in.mp4 -vn -ac 1 -ar 16000 /tmp/three-brain/audio.wav -y
whisper /tmp/three-brain/audio.wav --model small --output_dir /tmp/three-brain   # verbatim transcript
ffmpeg -i /tmp/three-brain/in.mp4 -vf fps=1/3 /tmp/three-brain/frame_%03d.jpg -y # 1 frame/3s, Claude reads directly
```
PDF fallback: Claude Read tool handles PDFs natively (paged) — no Gemini needed.

## Calling pattern

Codex hardening (all `codex exec` calls): pipe input via stdin OR append `< /dev/null` — `codex exec` reads stdin in addition to the prompt arg and hangs silently under non-TTY drivers without EOF. Run via Bash tool with `timeout: 600000` (default 2-min tool timeout kills real reviews).

```bash
# Review
git diff | codex exec --skip-git-repo-check "Review this diff. Flag bugs, risks, missing tests. Be specific."

# Adversarial (Codex leg)
git diff | codex exec --skip-git-repo-check "Adversarial review. Challenge the design. Find what's wrong. Prove it's broken."

# Adversarial (Gemini leg — fire in parallel with Codex leg when Gemini auth alive)
mkdir -p /tmp/three-brain && git diff > /tmp/three-brain/diff.txt
gemini -m gemini-2.5-pro --skip-trust -p "Adversarial review of this diff. Challenge the design, find bugs, race conditions, security holes. file:line citations. Independent pass — do not hedge." @/tmp/three-brain/diff.txt

# Rescue
cat <bundle> | codex exec --skip-git-repo-check "Rescue mode. Claude tried 2x and failed. Full context attached. Solve from scratch."

# Gemini file
gemini -m gemini-2.5-pro --skip-trust -p "<ask with output format>" @./file

# Gemini codebase
/cc-gemini-plugin:gemini --dirs <paths> "<question>"
```

### Dual adversarial merge

Run both legs in parallel (one message, two Bash calls). Claude merges by evidence: findings both models agree on = high-confidence, lead with those; unique findings kept and attributed (`[codex]` / `[gemini]`). Codex is the mandatory leg — Gemini is additive; its absence never blocks and never downgrades the NO-SELF-REVIEW LAW. Plain (non-adversarial) review stays Codex-only fast path.

### Multi-round Codex (session resume)

When a review needs iteration (revise → re-review), don't fire stateless one-shots — resume the same session so Codex remembers prior findings:

```bash
# Round 1 — capture thread_id
codex exec -s read-only --json -o /tmp/three-brain/verdict.txt "<review prompt>" < /dev/null 2>/dev/null | grep '"type":"thread.started"'

# Rounds 2+ — resume REJECTS -s; force read-only via -c or it inherits config.toml sandbox (write risk)
codex exec resume "$THREAD_ID" -c sandbox_mode="read-only" --json -o /tmp/three-brain/verdict.txt "Re-review. Check prior findings addressed, flag anything new." < /dev/null 2>/dev/null >/dev/null
```

For full plan-hardening loops (VERDICT protocol, MAX_ROUNDS, review log) hand off to /codex-review or /grill-me-codex instead of reimplementing here.

## Parallel consensus (explicit invoke only)

Each model returns:

```
Recommendation: <one line>
Blocking risks: <bullets>
Assumptions: <bullets>
Confidence: low/medium/high
Tests to verify: <bullets>
```

Claude diffs by evidence, not average.

## Output filing

`./three-brain-out/<YYYY-MM-DD>-<slug>/` — input.txt, gemini-analysis.md, claude-build.*, codex-review.md, log.md

Append to `./three-brain-out/log.md`: `[date] route=X target=Y`
