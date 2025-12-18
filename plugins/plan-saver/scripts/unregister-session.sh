#!/bin/bash
# Mark a Claude Code session as inactive
# Called by Stop hook
# We keep the session data for plan matching (don't delete)

set -euo pipefail

PLAN_SAVER_DIR="$HOME/.claude/.plan-saver"
SESSIONS_FILE="$PLAN_SAVER_DIR/sessions.json"
LOG_FILE="$PLAN_SAVER_DIR/daemon.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [unregister] $*" >> "$LOG_FILE"
}

# Read hook input from stdin
INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [[ -z "$SESSION_ID" ]] || [[ ! -f "$SESSIONS_FILE" ]]; then
  exit 0
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Use a temp file and atomic move for safety
TEMP_FILE="${SESSIONS_FILE}.tmp.$$"

# Mark session inactive but preserve data for matching
jq --arg id "$SESSION_ID" \
   --arg now "$NOW" \
   'if .sessions[$id] then
       .sessions[$id].active = false |
       .sessions[$id].last_active = $now
    else . end' "$SESSIONS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SESSIONS_FILE"

log "Marked session $SESSION_ID as inactive"
