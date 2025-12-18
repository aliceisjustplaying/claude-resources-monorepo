#!/usr/bin/env bash
# Symlinks skills and commands from this monorepo to ~/.claude/

set -euo pipefail

MONOREPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/scripts"

# Link skills (each skill is a directory)
for skill in "$MONOREPO/skills"/*/; do
  name=$(basename "$skill")
  target="$CLAUDE_DIR/skills/$name"
  if [ -L "$target" ]; then
    echo "Updating: $name"
    rm "$target"
  elif [ -e "$target" ]; then
    echo "Skipping $name (exists and is not a symlink)"
    continue
  fi
  ln -s "$skill" "$target"
  echo "Linked: skills/$name"
done

# Link commands (each command is a .md file)
for cmd in "$MONOREPO/commands"/*.md; do
  [ -e "$cmd" ] || continue
  name=$(basename "$cmd")
  target="$CLAUDE_DIR/commands/$name"
  if [ -L "$target" ]; then
    echo "Updating: $name"
    rm "$target"
  elif [ -e "$target" ]; then
    echo "Skipping $name (exists and is not a symlink)"
    continue
  fi
  ln -s "$cmd" "$target"
  echo "Linked: commands/$name"
done

# Link scripts (.sh and .py files)
for script in "$MONOREPO/scripts"/*.sh "$MONOREPO/scripts"/*.py; do
  [ -e "$script" ] || continue
  name=$(basename "$script")
  target="$CLAUDE_DIR/scripts/$name"
  if [ -L "$target" ]; then
    echo "Updating: $name"
    rm "$target"
  elif [ -e "$target" ]; then
    echo "Skipping $name (exists and is not a symlink)"
    continue
  fi
  ln -s "$script" "$target"
  echo "Linked: scripts/$name"
done

echo "Done."
