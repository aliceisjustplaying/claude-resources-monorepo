#!/bin/bash
# Install the plan-saver daemon system

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAN_SAVER_DIR="$HOME/.claude/.plan-saver"
DAEMON_DIR="$PLAN_SAVER_DIR/daemon"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.alice.claude-plan-saver.plist"

echo "Installing Plan Saver Daemon..."

# Check for fswatch
if ! command -v fswatch &>/dev/null; then
  echo "fswatch not found. Installing via homebrew..."
  if command -v brew &>/dev/null; then
    brew install fswatch
  else
    echo "Error: Please install fswatch manually (brew install fswatch)"
    exit 1
  fi
fi

# Check for jq
if ! command -v jq &>/dev/null; then
  echo "jq not found. Installing via homebrew..."
  if command -v brew &>/dev/null; then
    brew install jq
  else
    echo "Error: Please install jq manually (brew install jq)"
    exit 1
  fi
fi

# Create directories
mkdir -p "$DAEMON_DIR"
mkdir -p "$HOME/.claude/plans"

# Copy daemon script
cp "$PLUGIN_DIR/daemon/plan-saver-daemon.sh" "$DAEMON_DIR/"
chmod +x "$DAEMON_DIR/plan-saver-daemon.sh"

# Initialize files
touch "$DAEMON_DIR/processed.txt"

# Initialize sessions file if needed
SESSIONS_FILE="$PLAN_SAVER_DIR/sessions.json"
if [[ ! -f "$SESSIONS_FILE" ]]; then
  echo '{"sessions":{}}' > "$SESSIONS_FILE"
fi

# Unload existing agent if present
if [[ -f "$LAUNCHD_PLIST" ]]; then
  echo "Unloading existing agent..."
  launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
fi

# Install launchd plist
mkdir -p "$(dirname "$LAUNCHD_PLIST")"
cat > "$LAUNCHD_PLIST" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.alice.claude-plan-saver</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>exec "$HOME/.claude/.plan-saver/daemon/plan-saver-daemon.sh"</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/claude-plan-saver.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claude-plan-saver.stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
    </dict>
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
PLIST

# Load the agent
echo "Loading launchd agent..."
launchctl load "$LAUNCHD_PLIST"

echo ""
echo "Installation complete!"
echo ""
echo "Status: $(launchctl list 2>/dev/null | grep claude-plan-saver || echo 'Agent loaded')"
echo ""
echo "Logs:"
echo "  Daemon: $PLAN_SAVER_DIR/daemon.log"
echo "  stdout: /tmp/claude-plan-saver.stdout.log"
echo "  stderr: /tmp/claude-plan-saver.stderr.log"
echo ""
echo "Run './status.sh' to check daemon health"
