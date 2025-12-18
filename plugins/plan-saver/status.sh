#!/bin/bash
# Check the status of the plan-saver daemon

set -euo pipefail

PLAN_SAVER_DIR="$HOME/.claude/.plan-saver"
DAEMON_DIR="$PLAN_SAVER_DIR/daemon"
SESSIONS_FILE="$PLAN_SAVER_DIR/sessions.json"

echo "=== Plan Saver Daemon Status ==="
echo ""

# Check launchd
echo "Launchd Agent:"
if launchctl list 2>/dev/null | grep -q claude-plan-saver; then
  echo "  Status: RUNNING"
  launchctl list 2>/dev/null | grep claude-plan-saver | awk '{print "  PID: " $1 ", Exit: " $2}'
else
  echo "  Status: NOT RUNNING"
fi

# Check PID file
echo ""
echo "Process:"
if [[ -f "$DAEMON_DIR/watcher.pid" ]]; then
  PID=$(cat "$DAEMON_DIR/watcher.pid")
  if kill -0 "$PID" 2>/dev/null; then
    echo "  PID: $PID (alive)"
  else
    echo "  PID: $PID (stale - process not running)"
  fi
else
  echo "  No PID file found"
fi

# Session stats
echo ""
echo "Sessions:"
if [[ -f "$SESSIONS_FILE" ]]; then
  TOTAL=$(jq '.sessions | length' "$SESSIONS_FILE" 2>/dev/null || echo "0")
  ACTIVE=$(jq '[.sessions[] | select(.active == true)] | length' "$SESSIONS_FILE" 2>/dev/null || echo "0")
  echo "  Total: $TOTAL"
  echo "  Active: $ACTIVE"
else
  echo "  No session registry found"
fi

# Processed files
echo ""
echo "Processed Plans:"
if [[ -f "$DAEMON_DIR/processed.txt" ]]; then
  COUNT=$(wc -l < "$DAEMON_DIR/processed.txt" | tr -d ' ')
  echo "  Count: $COUNT"
else
  echo "  No processed files tracker found"
fi

# Watch directory
echo ""
echo "Watch Directory:"
if [[ -d "$HOME/.claude/plans" ]]; then
  PLAN_COUNT=$(find "$HOME/.claude/plans" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
  echo "  Path: ~/.claude/plans"
  echo "  Plans: $PLAN_COUNT"
else
  echo "  Not found: ~/.claude/plans"
fi

# Recent logs
echo ""
echo "=== Recent Logs (last 10 lines) ==="
if [[ -f "$PLAN_SAVER_DIR/daemon.log" ]]; then
  tail -10 "$PLAN_SAVER_DIR/daemon.log"
else
  echo "(no daemon log found)"
fi

echo ""
echo "=== Errors (last 5 lines) ==="
if [[ -f "/tmp/claude-plan-saver.stderr.log" ]]; then
  tail -5 "/tmp/claude-plan-saver.stderr.log" 2>/dev/null || echo "(empty)"
else
  echo "(no stderr log found)"
fi
