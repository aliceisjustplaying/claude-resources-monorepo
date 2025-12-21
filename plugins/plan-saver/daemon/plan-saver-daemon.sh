#!/bin/bash
# Plan Saver Daemon - Watches ~/.claude/plans/ for new files
# and copies them to the appropriate project directory

set -euo pipefail

PLAN_SAVER_DIR="$HOME/.claude/.plan-saver"
DAEMON_DIR="$PLAN_SAVER_DIR/daemon"
WATCH_DIR="$HOME/.claude/plans"
SESSIONS_FILE="$PLAN_SAVER_DIR/sessions.json"
PROCESSED_FILE="$DAEMON_DIR/processed.json"
LOG_FILE="$PLAN_SAVER_DIR/daemon.log"
PID_FILE="$DAEMON_DIR/watcher.pid"

# Ensure directories exist
mkdir -p "$DAEMON_DIR"
mkdir -p "$WATCH_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [daemon] $*" >> "$LOG_FILE"
}

# Initialize processed.json if it doesn't exist or migrate from old format
if [[ ! -f "$PROCESSED_FILE" ]]; then
  echo '{}' > "$PROCESSED_FILE"
elif ! jq empty "$PROCESSED_FILE" 2>/dev/null; then
  # Old format was plain text - migrate to JSON
  log "Migrating processed.txt to processed.json"
  echo '{}' > "$PROCESSED_FILE"
fi

# Check if already running
if [[ -f "$PID_FILE" ]]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    log "Daemon already running with PID $OLD_PID, exiting"
    exit 1
  else
    log "Removing stale PID file"
    rm -f "$PID_FILE"
  fi
fi

echo $$ > "$PID_FILE"
log "Daemon started with PID $$"

# Cleanup on exit
cleanup() {
  rm -f "$PID_FILE"
  log "Daemon stopped"
}
trap cleanup EXIT

# Wait for a file to be fully written (size stabilizes)
wait_for_stable_file() {
  local FILE="$1"
  local PREV_SIZE=0
  local CURR_SIZE

  for _ in {1..20}; do
    CURR_SIZE=$(stat -f%z "$FILE" 2>/dev/null || echo "0")
    if [[ "$CURR_SIZE" == "$PREV_SIZE" ]] && [[ "$CURR_SIZE" -gt 0 ]]; then
      return 0
    fi
    PREV_SIZE="$CURR_SIZE"
    sleep 0.25
  done
  return 1
}

# Refresh session slugs by reading JSONL files
# This fixes the race condition where sessions are registered before slugs are available
refresh_session_slugs() {
  if [[ ! -f "$SESSIONS_FILE" ]]; then
    return 0
  fi

  local PROJECTS_DIR="$HOME/.claude/projects"
  local UPDATED=false

  # Get all sessions with empty slugs
  local SESSION_IDS
  SESSION_IDS=$(jq -r '.sessions | to_entries[] | select(.value.slug == "") | .key' "$SESSIONS_FILE" 2>/dev/null)

  for SESSION_ID in $SESSION_IDS; do
    # Get the cwd for this session
    local CWD
    CWD=$(jq -r --arg id "$SESSION_ID" '.sessions[$id].cwd // empty' "$SESSIONS_FILE" 2>/dev/null)
    if [[ -z "$CWD" ]]; then
      continue
    fi

    # Convert cwd to encoded path (replace / with -)
    local ENCODED_CWD="${CWD//\//-}"
    local SESSION_FILE="$PROJECTS_DIR/$ENCODED_CWD/${SESSION_ID}.jsonl"

    if [[ ! -f "$SESSION_FILE" ]]; then
      continue
    fi

    # Extract slug from the JSONL file (appears on user messages)
    local SLUG
    SLUG=$(grep -m1 '"slug"' "$SESSION_FILE" 2>/dev/null | jq -r '.slug // empty' 2>/dev/null || true)

    if [[ -n "$SLUG" ]]; then
      log "Updating session $SESSION_ID with slug: $SLUG"
      # Update sessions.json with the found slug
      local TEMP_FILE="${SESSIONS_FILE}.tmp.$$"
      jq --arg id "$SESSION_ID" --arg slug "$SLUG" \
        '.sessions[$id].slug = $slug' "$SESSIONS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SESSIONS_FILE"
      UPDATED=true
    fi
  done

  if [[ "$UPDATED" == "true" ]]; then
    log "Session slugs refreshed"
  fi
}

# Find the target directory for a plan based on its slug
# Only matches if there's an exact slug match - no fallback to avoid routing plans to wrong projects
find_target_cwd() {
  local SLUG="$1"

  if [[ ! -f "$SESSIONS_FILE" ]]; then
    return 1
  fi

  # Exact slug match only - no fallback
  # The slug is the unique identifier that ties a plan to a specific Claude Code session
  local MATCH
  MATCH=$(jq -r --arg slug "$SLUG" '
    .sessions | to_entries[]
    | select(.value.slug == $slug)
    | .value.cwd
  ' "$SESSIONS_FILE" 2>/dev/null | head -1)

  if [[ -n "$MATCH" ]] && [[ -d "$MATCH" ]]; then
    echo "$MATCH"
    return 0
  fi

  # No match found - don't fall back to "most recently active session"
  # as that would route plans to the wrong project
  return 1
}

# Get the current mtime of a file
get_mtime() {
  stat -f%m "$1" 2>/dev/null || echo "0"
}

# Check if a file was already processed and get its destination
get_processed_dest() {
  local BASENAME="$1"
  jq -r --arg name "$BASENAME" '.[$name].dest // empty' "$PROCESSED_FILE" 2>/dev/null
}

# Get the stored mtime for a processed file
get_processed_mtime() {
  local BASENAME="$1"
  jq -r --arg name "$BASENAME" '.[$name].mtime // "0"' "$PROCESSED_FILE" 2>/dev/null
}

# Record a processed file with its destination
record_processed() {
  local BASENAME="$1"
  local DEST="$2"
  local MTIME="$3"
  local TEMP_FILE="${PROCESSED_FILE}.tmp.$$"
  jq --arg name "$BASENAME" --arg dest "$DEST" --arg mtime "$MTIME" \
    '.[$name] = {dest: $dest, mtime: $mtime}' "$PROCESSED_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$PROCESSED_FILE"
}

# Process a single plan file
process_plan() {
  local PLAN_FILE="$1"
  local BASENAME
  BASENAME=$(basename "$PLAN_FILE")

  # Skip non-markdown files
  if [[ "$BASENAME" != *.md ]]; then
    return 0
  fi

  # Skip numbered files (already processed by us)
  if [[ "$BASENAME" =~ ^[0-9]{4}- ]]; then
    return 0
  fi

  # Check if this file was already processed
  local EXISTING_DEST
  EXISTING_DEST=$(get_processed_dest "$BASENAME")
  local CURRENT_MTIME
  CURRENT_MTIME=$(get_mtime "$PLAN_FILE")

  if [[ -n "$EXISTING_DEST" ]]; then
    # File was processed before - check if it changed
    local STORED_MTIME
    STORED_MTIME=$(get_processed_mtime "$BASENAME")

    if [[ "$CURRENT_MTIME" == "$STORED_MTIME" ]]; then
      # No change, skip
      return 0
    fi

    # File changed - update existing destination
    log "Updating: $BASENAME (mtime: $STORED_MTIME -> $CURRENT_MTIME)"

    # Wait for file to be fully written
    if ! wait_for_stable_file "$PLAN_FILE"; then
      log "Warning: File $BASENAME may not be fully written"
    fi

    # Re-read mtime after waiting for stable
    CURRENT_MTIME=$(get_mtime "$PLAN_FILE")

    if [[ -f "$EXISTING_DEST" ]]; then
      cp "$PLAN_FILE" "$EXISTING_DEST"
      record_processed "$BASENAME" "$EXISTING_DEST" "$CURRENT_MTIME"
      log "Updated: $EXISTING_DEST"
    else
      log "Warning: Destination no longer exists: $EXISTING_DEST, will re-create"
      # Fall through to create new file
      EXISTING_DEST=""
    fi
  fi

  # New file or destination was deleted - create new numbered file
  if [[ -z "$EXISTING_DEST" ]]; then
    log "Processing: $BASENAME"

    # Wait for file to be fully written
    if ! wait_for_stable_file "$PLAN_FILE"; then
      log "Warning: File $BASENAME may not be fully written"
    fi

    # Re-read mtime after waiting for stable
    CURRENT_MTIME=$(get_mtime "$PLAN_FILE")

    # Extract slug from filename
    # Pattern: word-word-word.md or word-word-word-agent-hash.md
    local SLUG
    SLUG=$(echo "$BASENAME" | sed 's/-agent-[a-f0-9]*\.md$//' | sed 's/\.md$//')

    log "Slug: $SLUG"

    # Refresh session slugs before matching (fixes race condition)
    refresh_session_slugs

    # Find target directory
    local TARGET_CWD
    if ! TARGET_CWD=$(find_target_cwd "$SLUG"); then
      log "No matching session found for slug: $SLUG, skipping"
      # Record as processed with empty dest so we don't retry forever
      record_processed "$BASENAME" "" "$CURRENT_MTIME"
      return 0
    fi

    log "Target: $TARGET_CWD"

    # Create destination directory
    local DEST_DIR="$TARGET_CWD/.claude/plans"
    mkdir -p "$DEST_DIR"

    # Find next number
    local NEXT=0
    if [[ -d "$DEST_DIR" ]]; then
      local HIGHEST
      HIGHEST=$(find "$DEST_DIR" -maxdepth 1 -name '*.md' -exec basename {} \; 2>/dev/null \
        | grep -E '^[0-9]{4}-' \
        | sed 's/-.*//' \
        | sort -n \
        | tail -1 || true)
      if [[ -n "$HIGHEST" ]]; then
        NEXT=$((10#$HIGHEST + 1))
      fi
    fi

    # Extract title from plan content (first # header)
    local TITLE
    TITLE=$(head -10 "$PLAN_FILE" | grep -m1 '^# ' | sed 's/^#[[:space:]]*//' || true)
    if [[ -z "$TITLE" ]]; then
      TITLE="$SLUG"
    fi

    # Convert to kebab-case
    local KEBAB
    KEBAB=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
    if [[ -z "$KEBAB" ]]; then
      KEBAB="$SLUG"
    fi

    local NUM
    NUM=$(printf "%04d" "$NEXT")
    local DEST_FILE="$DEST_DIR/${NUM}-${KEBAB}.md"

    cp "$PLAN_FILE" "$DEST_FILE"
    record_processed "$BASENAME" "$DEST_FILE" "$CURRENT_MTIME"

    log "Saved: $DEST_FILE"
  fi
}

# Process any existing unprocessed files on startup
log "Checking for unprocessed plans..."
for FILE in "$WATCH_DIR"/*.md; do
  [[ -e "$FILE" ]] || continue
  process_plan "$FILE"
done
log "Startup processing complete"

# Start watching for new files
log "Starting fswatch on $WATCH_DIR"
fswatch -0 --event Created --event Updated --event Renamed "$WATCH_DIR" | while IFS= read -r -d '' FILE; do
  [[ -e "$FILE" ]] || continue
  process_plan "$FILE"
done
