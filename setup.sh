#!/usr/bin/env bash
# Symlinks skills, commands, scripts, and plugins from this monorepo to ~/.claude/
# Also installs Codex user-level skills, scripts, and prompts in ~/.codex/

set -euo pipefail

MONOREPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"

mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/scripts" "$CLAUDE_DIR/plugins"
mkdir -p "$CODEX_DIR/skills" "$CODEX_DIR/scripts" "$CODEX_DIR/prompts"

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

  # Codex user-level skills
  codex_target="$CODEX_DIR/skills/$name"
  if [ -L "$codex_target" ]; then
    echo "Updating (codex): $name"
    rm "$codex_target"
  elif [ -e "$codex_target" ]; then
    echo "Skipping $name for codex (exists and is not a symlink)"
  else
    ln -s "$skill" "$codex_target"
    echo "Linked (codex): skills/$name"
  fi
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

  # Codex compatibility layer: generate prompt files from Claude commands
  codex_prompt="$CODEX_DIR/prompts/$name"
  {
    cat <<'EOF'
---
description: "Generated from claude-code-skills-monorepo commands for Codex."
---

EOF
    # Rewrite Claude paths for Codex
    sed -e 's#~/.claude#~/.codex#g' -e 's#\.claude#\.codex#g' "$cmd"
  } > "$codex_prompt"
  echo "Generated (codex prompt): prompts/$name"
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

  # Codex user-level scripts
  codex_target="$CODEX_DIR/scripts/$name"
  if [ -L "$codex_target" ]; then
    echo "Updating (codex): $name"
    rm "$codex_target"
  elif [ -e "$codex_target" ]; then
    echo "Skipping $name for codex (exists and is not a symlink)"
  else
    ln -s "$script" "$codex_target"
    echo "Linked (codex): scripts/$name"
  fi
done

# Link plugins (each plugin is a directory)
for plugin in "$MONOREPO/plugins"/*/; do
  [ -d "$plugin" ] || continue
  name=$(basename "$plugin")
  target="$CLAUDE_DIR/plugins/$name"
  if [[ -L "$target" ]]; then
    echo "Updating: $name"
    rm "$target"
  elif [[ -e "$target" ]]; then
    echo "Skipping $name (exists and is not a symlink)"
    continue
  fi
  ln -s "$plugin" "$target"
  echo "Linked: plugins/$name"

  # Run plugin's install.sh if it exists (for extra setup like daemons)
  if [[ -x "$plugin/install.sh" ]]; then
    echo "Running $name installer..."
    "$plugin/install.sh"
  fi
done

echo "Done."
