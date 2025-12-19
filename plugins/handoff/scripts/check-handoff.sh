#!/usr/bin/env bash
# Check for handoff file and output continuation prompt if found

set -euo pipefail

LOG_FILE="$HOME/.claude/.plan-saver/handoff.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [handoff] $*" >> "$LOG_FILE"
}

# Read hook input from stdin
INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

log "CWD: $CWD"

if [[ -z "$CWD" ]]; then
  log "No CWD, exiting"
  exit 0
fi

HANDOFF_FILE="$CWD/.claude/handoff.md"

log "Checking for: $HANDOFF_FILE"

if [[ -f "$HANDOFF_FILE" ]]; then
  log "Found handoff file, outputting prompt"
  echo "A handoff file exists from a previous session. Read .claude/handoff.md and continue that work. After you've fully absorbed the context, delete the handoff file."
else
  log "No handoff file found"
fi
