# Jaron's Claude Code Skills

93 custom skills for Claude Code — invokable via `/skill-name` in any project.

## Install

**Windows (PowerShell):**
```powershell
git clone https://github.com/jaron-goh-centr/claude-skills
cd claude-skills
.\install.ps1
```

Force-overwrite existing skills:
```powershell
.\install.ps1 -Force
```

**macOS / Linux:**
```bash
git clone https://github.com/jaron-goh-centr/claude-skills
cd claude-skills
bash install.sh
```

Force-overwrite:
```bash
bash install.sh --force
```

## Update

Pull latest and re-run with `--force`:
```powershell
git pull && .\install.ps1 -Force
```

## Skill categories

| Prefix | Category |
|--------|----------|
| `gsap-*` | GSAP animation (core, react, scrolltrigger, timeline, plugins…) |
| `threejs-*` | Three.js (geometry, materials, lighting, shaders, loaders…) |
| `pp-*` | Prompt patterns (airbnb, notion, slack, yahoo-finance…) |
| `ponytail*` | Lean implementation discipline |
| `printing-press*` | Content pipeline (catalog, import, publish, retro…) |
| `soft-skill`, `taste-skill` | High-end UI/UX design standards |
| `brainstorming-ideas` | Creative exploration before implementation |
| `red-team-security-audit` | Security audit harness |
| `three-brain` | Multi-LLM validation workflow |
| `agent-loop*` | Iterative agent execution (lite/standard/deep) |
| `consolidate-memory` | Session memory sync |
| `lishasui` | Custom language protocol |
| `ponytail` | Lean shipping discipline |
