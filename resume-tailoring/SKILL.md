---
name: resume-tailoring
description: Use when creating tailored resumes for job applications - researches company/role, creates optimized templates, conducts branching experience discovery to surface undocumented skills, and generates professional multi-format resumes from user's resume library while maintaining factual integrity
---

# Resume Tailoring Skill

## Overview

Generates high-quality, tailored resumes optimized for specific job descriptions while maintaining factual integrity. Builds resumes around the holistic person by surfacing undocumented experiences through conversational discovery.

**Core Principle:** Truth-preserving optimization - maximize fit while maintaining factual integrity. Never fabricate experience, but intelligently reframe and emphasize relevant aspects.

**Mission:** A person's ability to get a job should be based on their experiences and capabilities, not on their resume writing skills.

## When to Use

Use this skill when:
- User provides a job description and wants a tailored resume
- User has multiple existing resumes in markdown format
- User wants to optimize their application for a specific role/company
- User needs help surfacing and articulating undocumented experiences

## Quick Start

**Required from user:**
1. Job description (text or URL)
2. Resume library location (defaults to `resumes/` in current directory)

**Workflow:**
1. Build library from existing resumes
2. Research company/role
3. Create template (with user checkpoint)
4. Optional: Branching experience discovery
5. Match content with confidence scoring
6. Generate MD + DOCX + PDF + Report
7. User review → Optional library update

## Implementation

See supporting files:
- `research-prompts.md` - Structured prompts for company/role research
- `matching-strategies.md` - Content matching algorithms and scoring
- `branching-questions.md` - Experience discovery conversation patterns
- `multi-job-workflow.md` - Batch processing for multiple job applications

## Workflow Details

### Multi-Job Detection

**Triggers when user provides:**
- Multiple JD URLs (comma or newline separated)
- Phrases: "multiple jobs", "several positions", "batch", "3 jobs"
- List of companies/roles: "Microsoft PM, Google TPM, AWS PM"

**If detected:** Ask user if they want multi-job mode (shared discovery session, batch processing).
**If confirmed Y:** Use multi-job-workflow.md
**If confirmed N or single job:** Use single-job workflow (Phase 0 onwards)

**Time Savings:**
- 3 jobs: ~40 min (vs 45 min sequential) = 11% savings
- 5 jobs: ~55 min (vs 75 min sequential) = 27% savings

### Phase 0: Library Initialization

**Always runs first - builds fresh resume database**

1. Locate resume directory (user provides path OR default to `./resumes/`)
2. Scan for markdown files using Glob tool
3. Parse each resume: extract roles, bullets, skills, education
4. Build experience database with JSON structure tracking role_id, company, title, dates, bullets (with themes, metrics, keywords, source_resumes)
5. Tag content automatically: themes, metrics, keywords

**Output:** In-memory database ready for matching

### Phase 1: Research Phase

**Goal:** Build comprehensive "success profile" beyond just the job description

1. **JD Parsing:** Extract requirements, keywords, implicit preferences, red flags, role archetype
2. **Company Research:** WebSearch for mission/values/culture/news
3. **Role Benchmarking:** WebSearch LinkedIn for similar role holders, analyze backgrounds/terminology
4. **Success Profile Synthesis:** Combine into structured profile with core requirements, valued capabilities, cultural fit signals, narrative themes, terminology map, risk factors

**Checkpoint:** Present success profile to user, wait for confirmation before proceeding.

### Phase 2: Template Generation

**Goal:** Create resume structure optimized for this specific role

1. Analyze library for role archetypes, career progression, experience clusters
2. Make role consolidation decisions (same company/responsibilities → consolidate; different companies → always separate)
3. Apply title reframing (stay truthful, emphasize most relevant aspect, use industry-standard terminology)
4. Generate template skeleton with section order, bullet allocation, guidance per slot

**Title Reframing Constraints:**
- NEVER claim work you didn't do
- NEVER inflate seniority beyond defensible
- Company name and dates MUST be exact

**Checkpoint:** Present template structure with consolidation/reframing decisions, wait for approval.

### Phase 2.5: Experience Discovery (OPTIONAL)

**Goal:** Surface undocumented experiences through conversational discovery

Triggered after template approval when gaps are identified. Conduct branching interview (see branching-questions.md):
1. Open probe per gap
2. Branch based on answer: YES → deep dive; INDIRECT → explore transferability; ADJACENT → explore related; NO → move on
3. Capture with context, scope, metrics, gap addressed, bullet draft
4. Ask integration preference per experience: add to resume / library only / refine / discard

**Important:** Never fabricate. Help articulate real experiences only. Time-box to 10-15 minutes.

### Phase 3: Assembly Phase

**Goal:** Fill template with best-matching content using transparent confidence scoring

For each template slot:
1. Extract all candidate bullets from library + discovered experiences
2. Score each candidate: Direct (40%) + Transferable (30%) + Adjacent (20%) + Impact (10%)
3. Confidence bands: 90-100% DIRECT | 75-89% TRANSFERABLE | 60-74% ADJACENT | <60% GAP
4. Present top 3 matches with analysis
5. Apply reframing where terminology misaligns (keyword alignment, emphasis shift, abstraction level, scale emphasis)
6. Handle gaps: reframe adjacent / flag for cover letter / omit slot / use best available

**Overall formula:** `(Direct × 0.4) + (Transferable × 0.3) + (Adjacent × 0.2) + (Impact × 0.1)`

**Checkpoint:** Present full coverage summary and mapping, wait for approval before generation.

### Phase 4: Generation Phase

**Goal:** Create professional multi-format outputs

1. **Markdown:** Compile approved mapping into clean resume markdown
2. **DOCX:** Use docx skill (Calibri 11pt body, proper bullet formatting, 0.5-1 inch margins)
3. **PDF:** Optional, if user requests
4. **Report:** Generation metadata (coverage %, match breakdown, reframings, source resumes, interview prep recommendations)

**Output files:**
- `{Name}_{Company}_{Role}_Resume.md`
- `{Name}_{Company}_{Role}_Resume.docx`
- `{Name}_{Company}_{Role}_Resume_Report.md`

### Phase 5: Library Update (CONDITIONAL)

After user reviews:
1. **YES - Save to library:** Move files, rebuild database, preserve metadata
2. **NO - Need revisions:** Collect feedback, iterate
3. **Save but don't add to library:** Keep files, skip enrichment

## Error Handling

- **Insufficient library (<2 resumes):** Warn, suggest adding more, emphasize discovery phase
- **No good matches (<60%):** Transparent gap identification, offer options
- **Research failures:** Fall back to JD-only, ask user for additional context
- **Generation failures:** Fall back to markdown-only
- **All checkpoints:** Allow going back to previous phase

## Usage Examples

**Single role:** Paste JD → skill researches company → builds template → optional discovery → confidence-scored matching → MD+DOCX+Report

**Batch (3 similar roles):** Provide 3 JDs → single shared discovery session → per-job processing → ~40 min vs 45 min sequential

**Career transition:** Skill reframes titles, surfaces transferable skills, flags genuine gaps with cover letter recommendations

**Career gap:** Startup/freelance/volunteer work included as legitimate roles, framed as entrepreneurial experience
