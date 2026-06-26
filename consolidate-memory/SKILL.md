---
name: consolidating-memory
description: Reads the past 24hrs of conversation logs from ~/.claude/history.jsonl, extracts key decisions, preferences, and facts, updates recent-memory.md and long-term-memory.md accordingly. Promotes important patterns from recent to long-term. Use when triggered by nightly cron or when user asks to "consolidate memory", "update memory", or "sync memory".
---

# Consolidate Memory

## When to use this skill
- Nightly cron trigger
- User asks to "consolidate memory", "update memory", or "sync memory"
- After a long session with many architectural decisions

## Workflow

### Phase 1: Read Conversation Logs

1. Read `~/.claude/history.jsonl` — each line is a JSON object:
   ```json
   {"display":"user message text","timestamp":1774023313617,"project":"D:\\path","sessionId":"uuid"}
   ```
2. Filter to entries from the **last 24 hours** (compare `timestamp` to current epoch ms)
3. Filter to entries matching the **current project path** (from the `project` field)
4. Collect all `display` values — these are the user's messages/prompts

### Phase 2: Resolve Memory Directory

1. Identify the current working directory
2. Map to the project memory folder: `~/.claude/projects/<slugified-cwd>/memory/`
3. Verify `recent-memory.md` and `long-term-memory.md` exist in that directory
4. If either is missing, create it using the templates below

### Phase 3: Extract Key Information

From the collected conversation prompts, identify and categorize:

- **Decisions**: Architecture choices, tech selections, approach preferences
  - Look for: "let's use", "go with", "switch to", "chose", "decided"
- **Changes Made**: Features built, bugs fixed, files modified
  - Look for: "add", "create", "fix", "update", "implement", "wire", "remove"
- **Preferences/Feedback**: How the user wants things done
  - Look for: "don't", "always", "never", "prefer", "stop doing", "keep doing"
- **Active Issues**: Bugs, errors, things to monitor
  - Look for: "error", "bug", "broken", "timeout", "failed", "investigate"
- **Project State**: What's done, what's in progress, what's next
  - Look for: "done", "complete", "next", "todo", "remaining", "blocked"

Also read the existing `recent-memory.md` to understand current state — avoid duplicating information already captured.

### Phase 4: Update recent-memory.md

Write the extracted information into `recent-memory.md`:

```markdown
## YYYY-MM-DD

### Session Context
- [Brief description of what was worked on]

### Key Changes Made
- **[Feature/Fix name]** (`path/to/file`): [One-line description]

### Decisions
- [Decision and reasoning]

### Active Issues
- [Issue description and current status]
```

**Rules for recent-memory.md:**
- Rolling 48hr window — remove entries with dates older than 2 days
- Keep it under 150 lines
- Group by date, most recent first
- Include file paths where relevant

### Phase 5: Promote to long-term-memory.md

Read `long-term-memory.md` and check each recent-memory entry:

**Auto-promote if:**
- It's an architecture decision (new pattern, tech choice, data model change)
- It's a lesson learned (error that taught something reusable)
- It's a user preference or feedback (how they want things done)
- It's a milestone (feature completed, phase transition)
- The same pattern/decision appeared in 2+ sessions

**Do NOT promote:**
- Transient debugging steps
- One-off fixes that don't establish a pattern
- Session-specific context that won't matter in 48hrs

**When promoting:**
- Add to the appropriate section in `long-term-memory.md`
- If the section doesn't exist, create it
- If the fact updates an existing entry, update in-place (don't duplicate)
- Keep `long-term-memory.md` under 300 lines — archive old entries by summarizing

### Phase 6: Cross-check with Existing Memory Files

Read any other memory files (e.g., `user_jaron.md`, `project_spacefactor_platform.md`, `feedback_*.md`):
- If a promoted fact belongs better in one of those files, update that file instead
- If a new category of memory emerges (new feedback, new user preference), create a new memory file following the existing frontmatter convention and add it to `MEMORY.md`

### Phase 7: Report

Output a summary:
- Entries processed from history.jsonl
- Items added to recent-memory.md
- Items promoted to long-term-memory.md
- Items expired from recent-memory.md (older than 48hrs)
- Any new memory files created

---

## Templates

### recent-memory.md (if missing)
```markdown
---
name: recent-memory
description: Rolling 48-hour context window — recent decisions, changes, and conversation state.
type: reference
---

# Recent Memory (48hr Rolling)

<!-- Auto-updated by consolidate-memory skill. Entries older than 48hrs are promoted or discarded. -->
```

### long-term-memory.md (if missing)
```markdown
---
name: long-term-memory
description: Persistent project state — architecture decisions, proven patterns, and accumulated knowledge.
type: reference
---

# Long-Term Memory

## User Profile

## Architecture Decisions

## Past Errors (Lessons Learned)

## Project Milestones
```

---

## Rules

- Never delete information from `long-term-memory.md` — only update or summarize
- Always preserve existing memory file structure — extend, don't reorganize
- The history.jsonl contains ONLY user prompts, not assistant responses. Infer what was done from the task descriptions.
- If the working directory doesn't match any project in `~/.claude/projects/`, skip — this skill only runs for projects with an established memory directory
- Keep timestamps as absolute dates (YYYY-MM-DD), never relative ("yesterday")
- This skill is read-only for code — it only writes to memory files
