# Multi-Job Resume Tailoring Workflow

## Overview

Handles 3-5 similar jobs efficiently by consolidating experience discovery while maintaining per-job research depth.

**Architecture:** Shared Discovery + Per-Job Tailoring

**Target Use Case:**
- Small batches (3-5 jobs)
- Moderately similar roles (60%+ requirement overlap)
- Continuous workflow (add jobs incrementally)

## Phase 0: Job Intake & Batch Initialization

Collect all JDs (text or URL), company names, role titles, priority, and notes for each job. Assign job_ids (job-1, job-2, etc.). Run standard library initialization once for the entire batch.

**Batch state structure:**
```json
{
  "batch_id": "batch-{YYYY-MM-DD}-{slug}",
  "current_phase": "intake",
  "jobs": [
    {
      "job_id": "job-1",
      "company": "Company",
      "role": "Role Title",
      "priority": "high/medium/low",
      "status": "pending",
      "requirements": [],
      "gaps": []
    }
  ],
  "discoveries": [],
  "aggregate_gaps": {}
}
```

**Checkpoint:** Confirm batch is complete before proceeding.

## Phase 1: Aggregate Gap Analysis

1. Extract requirements from all JDs (quick parse: must-have, nice-to-have, technical skills, soft skills)
2. Match each requirement against library, score confidence
3. Flag as gap if confidence <60%
4. Deduplicate gaps across jobs and prioritize:
   - **Critical (priority 3):** Appears in 3+ jobs
   - **Important (priority 2):** Appears in 2 jobs
   - **Job-specific (priority 1):** Appears in 1 job

**Output to user:** Coverage per job, gap counts by priority, recommended discovery time estimate.

**Checkpoint:** User chooses: start discovery / skip discovery / review gaps first.

## Phase 2: Shared Experience Discovery

Single branching interview covering ALL gaps. Process in priority order: critical → important → job-specific.

For each gap, provide multi-job context:
```
"{SKILL} appears in {N} of your target jobs ({Company1}, {Company2}...).
This is a {HIGH/MEDIUM/LOW}-LEVERAGE gap.
Current best match: {X}% confidence.
[Standard branching question from branching-questions.md]"
```

After each discovery, update user with real-time coverage improvement across all jobs.

**Integration decision per experience:**
1. Add to library for all jobs
2. Add to library, use selectively
3. Skip

**Checkpoint:** User approves before moving to per-job processing.

## Phase 3: Per-Job Processing

**Processing modes:**
- **INTERACTIVE:** Checkpoints at template and content mapping approval for each job
- **EXPRESS:** Auto-approve using best judgment, review all final resumes together

For each job (sequential):
1. **Research:** Company + role benchmarking (same depth as single-job Phase 1)
2. **Template:** Role consolidation, title reframing, bullet allocation
3. **Content Matching:** Uses enriched library (includes discovered experiences)
4. **Generation:** MD + DOCX + Report

Output files per job: `{Name}_{Company}_{Role}_Resume.md`, `.docx`, `_Report.md`

**Progress update after each job:** Coverage %, match breakdown, files generated, jobs remaining.

## Phase 4: Batch Finalization

Generate `_batch_summary.md` with per-job summaries, batch statistics, discovery impact, and application priority recommendations.

**Review options:**
1. **APPROVE ALL** — Save all resumes to library
2. **REVIEW INDIVIDUALLY** — Approve/revise each resume separately
3. **REVISE BATCH** — Apply changes across multiple resumes (e.g., "make all summaries shorter")
4. **SAVE BUT DON'T UPDATE LIBRARY** — Keep files, skip enrichment

## Incremental Batch Support

Add new jobs to existing completed batches:
1. Load existing batch state
2. Intake new jobs (append to existing list)
3. Run incremental gap analysis — only identify NEW gaps not covered by previous discoveries
4. Run short discovery session for new gaps only
5. Process new jobs through Phase 3
6. Update batch summary

**Key benefit:** If 3 jobs discovered 8 experiences, those are already in the library — new jobs inherit them without re-asking.

## Error Handling

**Diverse jobs (<40% overlap):** Suggest splitting into sub-batches by role type.

**Experience only relevant to 1 job:** Tag as job-specific, offer to explore transferable aspects.

**Research fails for one job:** Fall back to JD-only for that job, continue batch.

**User wants to add/remove jobs mid-process:** Add → quick incremental gap check; Remove → archive files, keep discoveries in library.

**Batch interrupted:** Auto-save state after each major milestone. Resume by saying "resume batch {batch_id}".

**No gaps found:** Skip discovery, proceed directly to per-job processing.

### Graceful Degradation

```
Research fails → JD-only analysis
Library too small → Emphasize discovery phase
One job fails → Continue with others
DOCX generation fails → Provide markdown only
```
