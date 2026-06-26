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
  • "tear apart / stress test / find what's wrong / break this" → Codex adversarial
  • Claude fails same op 2× in a row OR user says "I'm stuck / try GPT" → Codex rescue
  • Any request touching or targeting: src/auth/**, src/billing/**, **/migrations/**, **/deploy/**, **/.env*, **/secrets/**, **/policy/**, infra/**, **/Stripe*, **/Plaid*, **/jwt*, **/oauth* → forced Codex adversarial BEFORE "done" (verb irrelevant — edit/refactor/plan/explain/design all fire)
  • Video/audio/PDF artifact or YouTube URL in message (any size) → Gemini multimodal
  • "scan whole repo / find every place X / map architecture" → Gemini 1M-context
  • "ask all three / cross-architecture consensus" → parallel consensus mode
  • Ambiguous review verb targeting Claude's own output → FIRE (bias toward firing)

  ━━━ STAY ASLEEP ━━━
  • Explain/write/build/edit/plan on non-risky paths → Claude direct
  • "Review my draft / my notes" (user's own content, not Claude's output) → Claude
  • Casual chat, status, git/bash/grep, Q&A → Claude direct

  ━━━ VERB ≠ SAFE ON RISKY PATHS ━━━
  Refactor/plan/explain/design targeting auth/billing/migrations/deploy/.env/secrets/policy/infra/Stripe/Plaid/jwt/oauth → FIRE anyway.
---

# Three-Brain Auto-Router

- **Claude** = builder, driver
- **Codex (GPT-5.5)** = reviewer, rescue
- **Gemini 2.5 Pro** = multimodal, long-context

## Startup check (once per session)

```bash
codex --version 2>&1 | head -1   # expect 0.125+
gemini --version 2>&1 | head -1  # expect 0.39+
```

Missing → announce once, skip those routes, don't retry each turn. If Codex missing and a MUST-FIRE triggers, tell the user the mandatory route is unavailable — do not self-review.

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
gemini -p "Timestamped findings [MM:SS]: graphics, text, actions. 800 words max." @/tmp/three-brain/clip.mp4
```

**Audio:**
```bash
ffmpeg -i <input> -vn -ac 1 -ar 16000 /tmp/three-brain/audio.wav -y
gemini -p "Timestamped transcript and findings [MM:SS]. 800 words max." @/tmp/three-brain/audio.wav
```

**PDF** (any size fires; preprocess to cap Gemini input):
```bash
qpdf --pages input.pdf 1-100 -- /tmp/three-brain/doc.pdf 2>/dev/null || cp input.pdf /tmp/three-brain/doc.pdf
gemini -p "Key claims, tables, charts with page numbers. 1000 words max." @/tmp/three-brain/doc.pdf
```

**Whole-codebase:**
```bash
/cc-gemini-plugin:gemini --dirs <paths> "Find every X. Return file:line list."
```

Always demand timestamps/page numbers/file:line citations — no flat summaries.

## Calling pattern

```bash
# Review
git diff | codex exec --skip-git-repo-check "Review this diff. Flag bugs, risks, missing tests. Be specific."

# Adversarial
git diff | codex exec --skip-git-repo-check "Adversarial review. Challenge the design. Find what's wrong. Prove it's broken."

# Rescue
cat <bundle> | codex exec --skip-git-repo-check "Rescue mode. Claude tried 2x and failed. Full context attached. Solve from scratch."

# Gemini file
gemini -p "<ask with output format>" @./file

# Gemini codebase
/cc-gemini-plugin:gemini --dirs <paths> "<question>"
```

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
