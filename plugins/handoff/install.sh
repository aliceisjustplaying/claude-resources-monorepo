#!/usr/bin/env bash
# Install the handoff plugin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="handoff"
CLAUDE_PLUGINS_DIR="$HOME/.claude/plugins"

echo "Installing $PLUGIN_NAME plugin..."

# Create plugins directory if needed
mkdir -p "$CLAUDE_PLUGINS_DIR"

# Symlink the plugin
if [[ -L "$CLAUDE_PLUGINS_DIR/$PLUGIN_NAME" ]]; then
  rm "$CLAUDE_PLUGINS_DIR/$PLUGIN_NAME"
fi

ln -s "$SCRIPT_DIR" "$CLAUDE_PLUGINS_DIR/$PLUGIN_NAME"

echo "Done! Plugin installed to $CLAUDE_PLUGINS_DIR/$PLUGIN_NAME"
echo ""
echo "The plugin will automatically detect .claude/handoff.md on session start"
echo "and prompt Claude to continue from where you left off."
