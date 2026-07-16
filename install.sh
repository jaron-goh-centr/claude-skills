#!/usr/bin/env bash
# install.sh — Install Jaron's Claude Code skills on macOS / Linux
# Usage: curl -fsSL https://raw.githubusercontent.com/jaron-goh-centr/claude-skills/master/install.sh | bash
# Or:    git clone https://github.com/jarongoh/claude-skills && cd claude-skills && bash install.sh

set -euo pipefail

FORCE=0
DRY_RUN=0
for arg in "$@"; do
  case $arg in
    --force|-f) FORCE=1 ;;
    --dry-run)  DRY_RUN=1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
TARGET="${HOME}/.claude/skills"

# If run via curl | bash, BASH_SOURCE[0] is empty — clone to tmp
if [[ "$SCRIPT_DIR" == "/" || ! -d "$SCRIPT_DIR/.git" && ! -f "$SCRIPT_DIR/install.sh" ]]; then
  TMP="$(mktemp -d)"
  git clone https://github.com/jaron-goh-centr/claude-skills "$TMP"
  SCRIPT_DIR="$TMP"
fi

echo "Source : $SCRIPT_DIR"
echo "Target : $TARGET"

mkdir -p "$TARGET"

installed=0
skipped=0

for skill_dir in "$SCRIPT_DIR"/*/; do
  name="$(basename "$skill_dir")"
  [[ "$name" == .* ]] && continue   # skip hidden dirs

  dest="$TARGET/$name"

  if [[ -d "$dest" && "$FORCE" -eq 0 ]]; then
    echo "  skip  $name (exists — use --force to overwrite)"
    ((skipped++)) || true
    continue
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  dry   $name"
    ((installed++)) || true
    continue
  fi

  [[ -d "$dest" ]] && rm -rf "$dest"
  cp -r "$skill_dir" "$dest"
  echo "  +     $name"
  ((installed++)) || true
done

echo ""
echo "Done. $installed installed, $skipped skipped."
echo "Restart Claude Code to pick up new skills."
