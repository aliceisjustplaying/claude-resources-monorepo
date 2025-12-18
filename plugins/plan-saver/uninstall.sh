#!/bin/bash
# Uninstall the plan-saver daemon system

set -euo pipefail

PLAN_SAVER_DIR="$HOME/.claude/.plan-saver"
DAEMON_DIR="$PLAN_SAVER_DIR/daemon"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.alice.claude-plan-saver.plist"

echo "Uninstalling Plan Saver Daemon..."

# Stop and unload the daemon
if [[ -f "$LAUNCHD_PLIST" ]]; then
  echo "Unloading launchd agent..."
  launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
  rm -f "$LAUNCHD_PLIST"
  echo "Removed launchd plist"
fi

# Kill any running process
if [[ -f "$DAEMON_DIR/watcher.pid" ]]; then
  PID=$(cat "$DAEMON_DIR/watcher.pid")
  if kill -0 "$PID" 2>/dev/null; then
    echo "Stopping daemon process (PID $PID)..."
    kill "$PID" 2>/dev/null || true
  fi
  rm -f "$DAEMON_DIR/watcher.pid"
fi

# Ask about data removal
echo ""
read -p "Remove daemon files and logs? (session data will be preserved) [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -rf "$DAEMON_DIR"
  echo "Removed daemon files"
fi

echo ""
read -p "Remove session registry? (will lose plan-to-project mappings) [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -f "$PLAN_SAVER_DIR/sessions.json"
  echo "Removed session registry"
fi

echo ""
echo "Uninstallation complete!"
echo ""
echo "Note: Plans saved to your projects' .claude/plans/ directories are preserved."
