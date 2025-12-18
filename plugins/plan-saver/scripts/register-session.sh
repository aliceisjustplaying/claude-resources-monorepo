#!/bin/bash
# Register a Claude Code session in the session registry
# Called by SessionStart hook

set -euo pipefail

PLAN_SAVER_DIR="$HOME/.claude/.plan-saver"
SESSIONS_FILE="$PLAN_SAVER_DIR/sessions.json"
LOG_FILE="$PLAN_SAVER_DIR/daemon.log"

mkdir -p "$PLAN_SAVER_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [register] $*" >> "$LOG_FILE"
}

# Read hook input from stdin
INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [[ -z "$SESSION_ID" ]] || [[ -z "$CWD" ]]; then
  log "Missing session_id or cwd, skipping"
  exit 0
fi

# Find the session's JSONL file to extract the slug
# Session files are in ~/.claude/projects/[encoded-cwd]/[session-id].jsonl
ENCODED_CWD="${CWD//\//-}"
SESSION_FILE="$HOME/.claude/projects/$ENCODED_CWD/${SESSION_ID}.jsonl"

SLUG=""
if [[ -f "$SESSION_FILE" ]]; then
  # Extract slug from the first message that has one
  SLUG=$(grep -m1 '"slug"' "$SESSION_FILE" 2>/dev/null | jq -r '.slug // empty' 2>/dev/null || true)
fi

# If we couldn't find the slug from the session file, try the transcript
if [[ -z "$SLUG" ]]; then
  TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    SLUG=$(grep -m1 '"slug"' "$TRANSCRIPT_PATH" 2>/dev/null | jq -r '.slug // empty' 2>/dev/null || true)
  fi
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Initialize sessions file if needed
if [[ ! -f "$SESSIONS_FILE" ]]; then
  echo '{"sessions":{}}' > "$SESSIONS_FILE"
fi

# Use a temp file and atomic move for safety
TEMP_FILE="${SESSIONS_FILE}.tmp.$$"

jq --arg id "$SESSION_ID" \
   --arg cwd "$CWD" \
   --arg now "$NOW" \
   --arg slug "$SLUG" \
   '.sessions[$id] = {
       "cwd": $cwd,
       "slug": $slug,
       "started_at": $now,
       "last_active": $now,
       "active": true
   }' "$SESSIONS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SESSIONS_FILE"

log "Registered session $SESSION_ID (cwd: $CWD, slug: $SLUG)"
