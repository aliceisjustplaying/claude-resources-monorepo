#!/bin/bash
# Plan Saver Daemon - Watches ~/.claude/plans/ for new files
# and copies them to the appropriate project directory

set -euo pipefail

PLAN_SAVER_DIR="$HOME/.claude/.plan-saver"
DAEMON_DIR="$PLAN_SAVER_DIR/daemon"
WATCH_DIR="$HOME/.claude/plans"
SESSIONS_FILE="$PLAN_SAVER_DIR/sessions.json"
PROCESSED_FILE="$DAEMON_DIR/processed.txt"
LOG_FILE="$PLAN_SAVER_DIR/daemon.log"
PID_FILE="$DAEMON_DIR/watcher.pid"

# Ensure directories exist
mkdir -p "$DAEMON_DIR"
mkdir -p "$WATCH_DIR"
touch "$PROCESSED_FILE"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [daemon] $*" >> "$LOG_FILE"
}

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

# Find the target directory for a plan based on its slug
find_target_cwd() {
  local SLUG="$1"

  if [[ ! -f "$SESSIONS_FILE" ]]; then
    return 1
  fi

  # Strategy 1: Exact slug match
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

  # Strategy 2: Most recently active session
  MATCH=$(jq -r '
    .sessions | to_entries
    | sort_by(.value.last_active)
    | reverse
    | .[0].value.cwd // empty
  ' "$SESSIONS_FILE" 2>/dev/null)

  if [[ -n "$MATCH" ]] && [[ -d "$MATCH" ]]; then
    echo "$MATCH"
    return 0
  fi

  return 1
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

  # Skip if already processed
  if grep -qxF "$BASENAME" "$PROCESSED_FILE" 2>/dev/null; then
    return 0
  fi

  # Skip numbered files (already processed by us)
  if [[ "$BASENAME" =~ ^[0-9]{4}- ]]; then
    return 0
  fi

  log "Processing: $BASENAME"

  # Wait for file to be fully written
  if ! wait_for_stable_file "$PLAN_FILE"; then
    log "Warning: File $BASENAME may not be fully written"
  fi

  # Extract slug from filename
  # Pattern: word-word-word.md or word-word-word-agent-hash.md
  local SLUG
  SLUG=$(echo "$BASENAME" | sed 's/-agent-[a-f0-9]*\.md$//' | sed 's/\.md$//')

  log "Slug: $SLUG"

  # Find target directory
  local TARGET_CWD
  if ! TARGET_CWD=$(find_target_cwd "$SLUG"); then
    log "No matching session found for slug: $SLUG, skipping"
    # Still mark as processed so we don't retry forever
    echo "$BASENAME" >> "$PROCESSED_FILE"
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
  echo "$BASENAME" >> "$PROCESSED_FILE"

  log "Saved: $DEST_FILE"
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
