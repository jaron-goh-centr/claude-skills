---
name: research-scout
description: Hunts for new strategies, tools, announcements, and workflow changes relevant to the current project using web search, Reddit, Hacker News, and Quora. Cross-references against existing docs to filter redundant findings. Stores validated new learnings in memory. Use when the user asks to research updates, scout for changes, or when triggered by cron.
---

# Research Scout

## When to use this skill
- Cron-triggered nightly research runs
- User asks to "check for updates", "scout for new info", or "research what's changed"
- User asks to review or promote staged learnings

## Workflow

### Phase 1: Build Search Queries from Project Context

1. Discover the current project's context files:
   - Read `CLAUDE.md` from the working directory (and any nested `CLAUDE.md` files)
   - Read `AGENTS.md` if present
   - Read `package.json`, `requirements.txt`, `Cargo.toml`, or equivalent to extract dependencies and versions
   - Read the project's memory files from `~/.claude/projects/<project>/memory/`
2. Extract from these sources:
   - Tech stack (frameworks, libraries, services with versions)
   - AI models and APIs in use
   - Key architectural patterns
   - External services and integrations
3. Generate 5-8 targeted search queries scoped to the current year. Examples:
   - `"[framework] [version] breaking changes [year]"`
   - `"[database/service] latest updates [year]"`
   - `"[key library] deprecation migration guide"`
   - `"[AI provider] API SDK changes [month] [year]"`

### Phase 2: Execute Searches

For each query, search across multiple sources:

```
WebSearch: [query]
WebSearch: [query] site:reddit.com
WebSearch: [query] site:news.ycombinator.com
```

- Use `WebFetch` to read promising links when the search snippet is insufficient
- Cap at 20 total web fetches per run to stay within rate limits
- Prioritise official docs, changelogs, and GitHub releases over blog posts

### Phase 3: Filter Against Existing Knowledge

For each finding, check whether it's genuinely new:

- [ ] Read current `CLAUDE.md` and memory files
- [ ] Search codebase with `Grep` for the tool/pattern/API mentioned
- [ ] If the finding is already documented or implemented, **discard it**
- [ ] If the finding contradicts existing docs, **flag as contradiction**
- [ ] If the finding is net-new information, **stage it**

### Phase 4: Store Validated Findings

Determine the active project's memory directory dynamically:

1. Run: `ls ~/.claude/projects/` to list project directories
2. Match the current working directory to the correct project folder (the folder name is a slugified version of the working directory path)
3. The memory path is: `~/.claude/projects/<matched-folder>/memory/`

Append validated findings to `new_learnings.md` inside that memory directory.
Create the file if it doesn't exist, using this frontmatter:

```markdown
---
name: new_learnings
description: Staged findings from research-scout runs — new tools, breaking changes, deprecations, and best practices discovered via web research.
type: reference
---
```

Then add a pointer in `MEMORY.md` under a `## Reference` section:
`- [new_learnings.md](new_learnings.md) — Staged findings from research-scout runs`

Use this format for each finding:

```markdown
## New Learnings (Staged)

### [YYYY-MM-DD HH:MM] — [One-line summary]
- **Source:** [URL]
- **Category:** breaking-change | new-feature | deprecation | best-practice | security | tool-update
- **Affects:** [file path or system area]
- **Detail:** [2-3 sentences on what changed and why it matters]
- **Action:** update-docs | update-code | monitor | no-action
- **Status:** staged
```

After appending, update `MEMORY.md` to include a pointer to `new_learnings.md` if not already present.

### Phase 5: Report

Output a summary to the user:
- Number of searches performed
- Number of findings staged (with one-line summaries)
- Number of contradictions found (highlight these)
- Number of items discarded as redundant

---

## Weekly Review Mode

When invoked with the prompt "review and promote learnings" (from weekly cron):

1. Resolve the project memory directory (same method as Phase 4)
2. Read all entries in `<memory-dir>/new_learnings.md` with `Status: staged`
2. For each entry:
   - If the same finding appeared 2+ times across runs, **promote** it:
     - Update the relevant memory file (e.g., `project_spacefactor_platform.md`)
     - Or create a new memory file if it's a new topic
     - Update `MEMORY.md` index
     - Change status from `staged` to `promoted`
   - If a finding appeared only once and is older than 5 days, mark as `expired`
   - If a finding is a breaking change or security issue, promote immediately regardless of frequency
3. Clear all `promoted` and `expired` entries from `new_learnings.md`
4. Output a weekly digest: what was promoted, what expired, what remains staged

---

## Rules

- Never store findings that are already in `CLAUDE.md` or existing memory files
- Always include the source URL — no unsourced claims
- Contradictions to existing docs take priority over net-new info
- Breaking changes and security issues are auto-promoted on first sight
- Keep `new_learnings.md` under 200 lines — archive old promoted entries
- Do not modify project code — this skill is read-only research. Flag needed code changes as `Action: update-code`
