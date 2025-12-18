#!/bin/bash
# Saves a plan to .claude/plans/NNNN-name.md
# Usage: save-plan.sh <name> < plan-content.md
#    or: echo "plan content" | save-plan.sh <name>
#    or: save-plan.sh <name> <file>

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: save-plan.sh <name> [file]" >&2
  echo "  Reads from stdin if no file provided" >&2
  exit 1
fi

NAME="$1"
PLANS_DIR=".claude/plans"

mkdir -p "$PLANS_DIR"

# Find the next number (macOS/BSD compatible)
NEXT=0
if [[ -d "$PLANS_DIR" ]]; then
  HIGHEST=$(find "$PLANS_DIR" -maxdepth 1 -name '*.md' -exec basename {} \; 2>/dev/null \
    | grep -E '^[0-9]{4}-' \
    | sed 's/-.*//' \
    | sort -n \
    | tail -1 || true)
  if [[ -n "$HIGHEST" ]]; then
    NEXT=$((10#$HIGHEST + 1))
  fi
fi

# Zero-pad to 4 digits
NUM=$(printf "%04d" "$NEXT")
FILENAME="${NUM}-${NAME}.md"
FILEPATH="$PLANS_DIR/$FILENAME"

# Read content from file arg or stdin
if [[ -n "${2:-}" ]] && [[ -f "$2" ]]; then
  cp "$2" "$FILEPATH"
else
  cat > "$FILEPATH"
fi

echo "$FILEPATH"
