#!/usr/bin/env bash
# Check for handoff file and output continuation prompt if found

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [[ -z "$CWD" ]]; then
  exit 0
fi

HANDOFF_FILE="$CWD/.claude/handoff.md"

if [[ -f "$HANDOFF_FILE" ]]; then
  echo "A handoff file exists from a previous session. Read .claude/handoff.md and continue that work. After you've fully absorbed the context, delete the handoff file."
fi
