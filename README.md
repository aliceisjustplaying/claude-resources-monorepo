# Claude Code Skills Monorepo

A centralized repository for Claude Code extensions including skills, commands, scripts, and plugins.

## Features

- **Plan Saver Plugin** - Automatically saves and distributes plans from Claude Code's plan mode to their respective project directories
- **Slash Commands** - Custom commands like `/latest-plan` for quick access to recent work
- **Utility Scripts** - Standalone scripts for plan management and other automation
- **Skills** - Reusable skill definitions for Claude Code

## Installation

### Quick Setup

Run the setup script to symlink all components to your Claude Code configuration:

```bash
./setup.sh
```

This creates symlinks in `~/.claude/` for:
- Skills → `~/.claude/skills/`
- Commands → `~/.claude/commands/`
- Scripts → `~/.claude/scripts/`

### Plan Saver Plugin

The plan-saver plugin requires additional installation:

```bash
cd plugins/plan-saver
./install.sh
```

This will:
- Install dependencies (`fswatch`, `jq`) via Homebrew
- Set up the daemon as a launchd service
- Create the session registry at `~/.claude/.plan-saver/`

## Components

### Plugins

#### plan-saver (v2.0.0)

Automatically distributes plans created in Claude Code's plan mode to their respective project directories.

**How it works:**
- When Claude Code starts, a session is registered with the working directory
- The daemon watches `~/.claude/plans/` for new plan files
- When a plan is saved, it's matched to the correct project via session tracking
- Plans are copied to `{project}/.claude/plans/NNNN-title.md` with auto-incrementing numbers

**Commands:**
```bash
# Check daemon status
plugins/plan-saver/status.sh

# Uninstall
plugins/plan-saver/uninstall.sh
```

### Commands

| Command | Description |
|---------|-------------|
| `/latest-plan` | Load the most recent plan from `.claude/plans/` |
| `/latest-plan <query>` | Find a plan by number or name |

### Scripts

| Script | Description |
|--------|-------------|
| `latest-plan.sh` | Find and display the latest plan file |
| `save-plan.sh` | Save a plan to `.claude/plans/` with auto-numbering |

## Directory Structure

```
claude-code-skills-monorepo/
├── commands/                    # Slash command definitions
│   └── latest-plan.md
├── scripts/                     # Utility scripts
│   ├── latest-plan.sh
│   └── save-plan.sh
├── skills/                      # Skill definitions (add yours here)
├── plugins/
│   └── plan-saver/
│       ├── daemon/
│       │   └── plan-saver-daemon.sh
│       ├── hooks/
│       │   └── hooks.json
│       ├── scripts/
│       │   ├── register-session.sh
│       │   └── unregister-session.sh
│       ├── install.sh
│       ├── uninstall.sh
│       └── status.sh
├── .claude/plans/               # Example plans
├── .claude-plugin/
│   └── marketplace.json
├── setup.sh                     # Main installation script
├── CLAUDE.md                    # Project instructions for Claude
└── README.md
```

## Adding New Components

### Adding a Skill

- Create a new directory under `skills/`
- Add your skill definition `.md` file
- Run `./setup.sh` to create symlinks

### Adding a Command

- Create a `.md` file in `commands/`
- Run `./setup.sh` to create symlinks

### Adding a Script

- Create your `.sh` script in `scripts/`
- Make it executable: `chmod +x scripts/your-script.sh`
- Run `./setup.sh` to create symlinks

## Shell Script Standards

All shell scripts in this repository follow these standards:

- **Defensive mode** - All scripts begin with:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  ```
- **Shellcheck compliant** - Run `shellcheck` before committing
- **Proper quoting** - All variable expansions are quoted
- **Modern syntax** - Use `[[ ]]` for conditionals

## Requirements

- macOS (for launchd-based daemon)
- Homebrew (for dependency installation)
- Claude Code CLI

## Troubleshooting

### Daemon not running

```bash
# Check status
plugins/plan-saver/status.sh

# View logs
tail -f ~/.claude/.plan-saver/daemon.log

# Restart daemon
launchctl unload ~/Library/LaunchAgents/com.claude.plan-saver.plist
launchctl load ~/Library/LaunchAgents/com.claude.plan-saver.plist
```

### Plans not being saved

- Ensure the daemon is running
- Check that a session was registered (look in `~/.claude/.plan-saver/sessions.json`)
- Verify the plan slug matches the session

## License

MIT
