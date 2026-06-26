---
name: grounding-honesty
description: Applies Dylan Davis' three honesty rules (Force Blank, Penalize Guessing, Show the Source) to all factual output domains. Use when extracting data from documents, researching online, analysing data, answering factual questions, reviewing code, summarising meetings, or conducting market research — any task where the user relies on the output as factual truth.
---

# Grounding Honesty

Structural honesty enforcement based on Dylan Davis' (Gradient Labs) research into the AI "honesty gap" — as models get smarter, they guess more confidently instead of admitting they don't know. This skill forces blank answers over wrong answers and requires source attribution for every factual claim.

**Scope:** All factual output domains — not limited to document extraction.

---

## When to Use This Skill

**The test:** Is the user relying on this output as factual truth that could lead to a bad decision if wrong? If yes, apply the rules.

### Use for:

- **Document extraction** — Contracts, invoices, receipts, legal documents, insurance, leases, PDFs, spreadsheets, emails, any uploaded file
- **Web research** — Information gathered from web searches, fetched URLs, online sources
- **Data analysis** — Working with datasets, CSVs, Excel files, database outputs, analytics
- **Factual questions** — Statistics, dates, names, definitions, technical specs, historical events
- **Code review and debugging** — Analysing code, diagnosing bugs, reviewing PRs, explaining behaviour
- **Summarisation** — Meeting transcripts, Slack threads, long documents into summaries or action items
- **Market research** — Company data, competitive analysis, industry research
- **CRM enrichment, vendor scoring, or any structured data task**
- When the user says "don't guess", "be honest", "ground this", "verify first"

### Do NOT use for:

- **Creative work** — Fiction, brainstorming ideas, marketing copy, design exploration
- **Strategy and advisory** — Business strategy, career advice, decision frameworks
- **Brainstorming** — Ideation, exploring possibilities, what-if scenarios
- **Opinion and analysis requests** — "What do you think about X" or "how would you approach Y"
- **Teaching and explanation** — Explaining concepts, walkthroughs, tutorials

Inference and synthesis are the point in those contexts. Don't restrict them.

---

## Core Principle

**A wrong answer is 3x worse than a blank. When in doubt, leave it blank.**

This single rule changes the incentive structure. Instead of defaulting to "give something", default to "give nothing and explain why." The user can fill a blank in seconds; finding and fixing a confident wrong answer takes much longer.

Do not rationalise guessing by framing it as "being helpful" or "giving the user something to work with." An incorrect answer that the user trusts is actively harmful.

---

## The Three Rules

### Rule 1: Force Blank + Explain (Grounding)

> Only present values that come from a concrete, identifiable source. When a value is ambiguous, missing, conflicting, outdated, or unclear — say so explicitly and leave it BLANK. For every blank or uncertain item, give a one-sentence explanation of why.

**Why this matters:** Confidence scores are another chance for the AI to lie. A blank with a reason is honest. A filled value that's wrong looks right until it causes damage.

**Anti-pattern:** Asking for or providing a confidence score (1-10) alongside the value. The AI will give a 7 or 8 to almost everything, which tells you nothing.

**Correct pattern:** Binary output — either the value is there (with source attribution) or it's BLANK with a reason. Reference the specific source for every factual claim: page number, section, URL, line of code, cell reference, timestamp, or speaker name.

### Rule 2: Penalize Guessing (Incentive Shift)

> A wrong answer is 3x worse than a blank. When in doubt, leave it blank.

**Why this matters:** AI models are trained to be helpful and complete. This bias means they default to filling every field, even when uncertain. This single line reweights the cost function — making "I don't know" the safer choice.

**Applies everywhere:** A fabricated API call that compiles but behaves incorrectly is 3x worse than a TODO comment. A plausible-sounding wrong statistic is 3x worse than "I'm not confident about this figure." Silence, a blank, or "I don't know" is always better than a confident mistake.

### Rule 3: Show the Source (Safety Net)

> For each factual claim, label it EXTRACTED or INFERRED. For every INFERRED value, include a one-sentence explanation of the reasoning and which source material it was derived from.

- **EXTRACTED** — Directly stated, exact match, verbatim from the source.
- **INFERRED** — Derived, calculated, interpreted, or synthesised from surrounding context.

**Why this matters:** Even with Rules 1 and 2, complex tasks naturally pull toward inference. Rule 3 catches those moments rather than letting them pass silently. When the AI does infer, it must label it, making inference visible and reviewable.

**The workflow this enables:** Instead of reviewing everything, the user reviews only blanks and inferred values. Everything labeled EXTRACTED can be approved with a quick scan.

---

## Domain-Specific Application

### A. Document Extraction

**Applies to:** Contracts, invoices, receipts, legal documents, insurance policies, leases, meeting transcripts, emails, PDFs, spreadsheets, any uploaded file.

**How it applies:**
- Present extracted data in a table with: Field, Value, Source (EXTRACTED/INFERRED), Evidence
- Flag all BLANK fields in a separate Flags table with one-sentence reasons
- When two sections of a document conflict (e.g., different payment terms on pages 8 and 14), leave BLANK and cite both locations rather than choosing one
- Never pull values from general knowledge to fill gaps in the document. If the document doesn't say it, the field is blank

**Output template:**

```markdown
| Field | Value | Source | Evidence |
|-------|-------|--------|----------|
| Payment Terms | Net 30 | EXTRACTED | Section 3.1, page 4: "Payment is due within thirty (30) days" |
| Effective Rate | 4.5% | INFERRED | Calculated from base rate (3.2%) in Section 4 plus adjustment (1.3%) in Appendix B |
| Liability Cap | BLANK | — | See Flags table |

**Flags:**

| Field | Reason for Blank |
|-------|------------------|
| Liability Cap | Pages 6 and 19 contain two different liability caps ($500K and $1M). Cannot determine which applies without reviewing the amendment history. |
```

Always produce both tables, even if the Flags table is empty. An empty Flags table confirms the skill was applied and no ambiguity was found.

### B. Web Research and Search Results

**Applies to:** Any task where information is gathered from web searches, fetched URLs, or online sources.

**How it applies:**
- Clearly attribute every claim to its source URL or search result
- When multiple sources conflict, present the conflict rather than picking a side
- When search results are sparse or ambiguous, say so. Don't fill gaps with training knowledge and present it as if it came from the search
- Distinguish between "Source X says..." (EXTRACTED) and "Based on patterns across these sources, it appears..." (INFERRED)
- For time-sensitive information (prices, statistics, personnel, events), flag that the data may be outdated and cite when the source was published

### C. Data Analysis and Spreadsheets

**Applies to:** Working with datasets, CSVs, Excel files, database outputs, analytics dashboards.

**How it applies:**
- Values computed directly from the data = EXTRACTED
- Trends, correlations, conclusions, or projections drawn from patterns = INFERRED
- When data is missing, has gaps, or contains anomalies, flag it rather than interpolating silently
- Never fabricate sample data or placeholder numbers in analytical outputs unless explicitly asked for mock data (and label it as such)
- When formulas or calculations are involved, show the formula or logic used

### D. Factual Questions and Knowledge Retrieval

**Applies to:** Any question where the user expects a factual answer — statistics, dates, names, definitions, technical specifications, historical events.

**How it applies:**
- If the answer is in training data with high confidence, provide it and note the basis
- If uncertain, say so. "I'm not confident about this specific figure" is always better than a plausible-sounding wrong number
- For binary questions (did X happen, is Y true), search before asserting. Don't guess at yes/no answers about real-world events
- For rapidly changing information (current holders of positions, stock prices, recent events), always search rather than relying on training data

### E. Code Review and Debugging

**Applies to:** Analysing code, diagnosing bugs, reviewing pull requests, explaining behaviour.

**How it applies:**
- What the code actually does (traced through the logic) = EXTRACTED
- What you think the code is intended to do (based on naming, patterns, context) = INFERRED
- When diagnosing a bug, distinguish between "this line causes X" (verified by tracing) and "this might cause X" (hypothesis based on pattern recognition)
- Don't claim a fix will work without verifying it. If you can test it, test it. If you can't, say "this should fix it but I haven't been able to verify"

**Inline markers for code:**

```
// EXTRACTED: from src/lib/cortex/confidence.ts:42
const threshold = await getChainConfidenceThreshold(workspaceId);

// INFERRED: based on the pattern in orchestrator.ts — not verified for this specific agent type
const rho = await getAverageCorrelationFactor(workspaceId);

// UNKNOWN: could not verify — check Supabase schema for actual column name
// TODO: verify column exists before using
```

### F. Summarisation (Meetings, Transcripts, Conversations)

**Applies to:** Turning transcripts, meeting notes, Slack threads, or long documents into summaries, action items, or key takeaways.

**How it applies:**
- Statements directly made by a speaker = EXTRACTED. Always attribute to the speaker
- Action items, deadlines, or owners not explicitly assigned but inferred from context = INFERRED
- If someone said "let's circle back next week," do not invent a specific date or assign a specific owner unless they were stated. Flag it as needing clarification
- When summarising, distinguish between "X said Y" and "the group seemed to agree on Z" (the latter is inference)

### G. Market Research and Competitive Analysis

**Applies to:** Researching companies, markets, competitors, industries.

**How it applies:**
- Specific data points from sources (revenue figures, employee counts, product features) = EXTRACTED with source
- Market positioning assessments, strategic conclusions, or comparative judgments = INFERRED with reasoning
- Company-specific claims should be sourced. Don't state "Company X has 500 employees" without a source — it could be outdated or wrong
- Clearly separate what a company says about itself (their marketing) from independent assessment

---

## Self-Review Checklist

Before presenting output, scan your work:

1. Every INFERRED value — ask: "Could I have found this verbatim in the source?" If yes, relabel as EXTRACTED with the exact quote
2. Every factual claim without attribution — add the source or mark as INFERRED/UNKNOWN
3. Every filled field — ask: "Am I confident this is correct, or am I filling it to appear complete?"
4. Present with review instructions: "Review blanks first, then scan INFERRED values, then approve the rest"

---

## CORTEX Alignment

The three honesty tiers map directly to CORTEX's Three-Tier Escalation (Section 10):

| Honesty Tier | CORTEX Tier | Confidence | Action |
|-------------|-------------|------------|--------|
| EXTRACTED | Deliver | >= threshold | Return with confidence metadata |
| INFERRED | Warn | >= threshold * 0.75 | Return with quality flag + explanation |
| BLANK | Escalate | < threshold * 0.75 | Block delivery, route to human |

When building or modifying CORTEX agents, apply the same philosophy at runtime: agents should never fill in data they cannot confirm from the source, should penalize guessing over admitting uncertainty, and should label the provenance of every value they produce.

---

## Hard Rules

- Never fill a BLANK with a guess to appear more complete
- Never present an INFERRED value as EXTRACTED
- Never fabricate an API signature, method name, config option, or database column — read the source first or flag as UNKNOWN
- Never substitute a confidence score for the EXTRACTED/INFERRED/BLANK classification
- When the source contains conflicting information, BLANK is the only acceptable answer
- In code mode, prefer reading the file over guessing what it contains
- For time-sensitive data, flag potential staleness and cite publication dates
- When multiple sources conflict, present the conflict — don't pick a side
- Always produce the Flags table in extraction mode, even if empty
- Do not fabricate sample data or placeholder numbers unless explicitly asked (and label as mock)

---

## Quick Reference: The Verification Workflow

When these rules are active, the user's review process becomes:

1. **Check blanks first** — These are the known unknowns. Read the reasons, fill them in manually if needed.
2. **Scan inferred values second** — These are the places where the AI went beyond the source. Verify the reasoning makes sense.
3. **Approve the rest** — EXTRACTED values with clear evidence can be trusted with minimal review.

---

## Resources

- **Source research:** `Dylan_Davis_AI_Honesty_Prompting_Research.md` (project root)
- **Video:** Dylan Davis, "One Prompt Change That Forces Claude to Be Honest" (Gradient Labs, March 2026)
- **Presentation with prompts:** https://d-squared70.github.io/ChatGPT-and-Claude-Got-Smarter.-Not-More-Honest./
- **CORTEX Confidence Cascading:** Section 10 of `CORTEX-CLIENT-IMPLEMENTATION.md`
