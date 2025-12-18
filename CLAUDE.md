# Claude Code Skills Monorepo

## Project Overview

This is a monorepo containing Claude Code skills, commands, scripts, and plugins. The primary component is the **plan-saver** plugin which automatically distributes plans from Claude Code's plan mode to their respective project directories.

## Tech Stack

- **Shell scripts (Bash)** - All automation and daemon scripts
- **jq** - JSON manipulation for session registry
- **fswatch** - File system monitoring (macOS)
- **launchd** - Daemon management (macOS)

## Project Structure

```
├── commands/           # Claude Code slash commands (.md files)
├── scripts/            # Standalone utility scripts (.sh)
├── skills/             # Claude Code skills (skill definitions)
├── plugins/            # Claude Code plugins
│   └── plan-saver/     # Auto-distributes plans to projects
├── .claude/plans/      # Example plans for this repo
└── setup.sh            # Installation script
```

## Shell Script Standards

**CRITICAL: All shell scripts MUST follow these standards:**

- Always run `shellcheck` on all `.sh` files before committing
- All scripts MUST use bash defensive mode at the top:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  ```
- Use `[[ ]]` for conditionals, not `[ ]`
- Quote all variable expansions: `"$var"` not `$var`
- Use lowercase for local variables, UPPERCASE for exported/environment variables

## Development Guidelines

- Use `bun` for any TypeScript/JavaScript tooling
- Test scripts manually before committing
- Keep scripts focused and single-purpose
- Document all scripts with a comment block at the top explaining purpose

## Key Files

- `setup.sh` - Symlinks skills/commands/scripts to `~/.claude/`
- `plugins/plan-saver/install.sh` - Installs plan-saver daemon
- `plugins/plan-saver/daemon/plan-saver-daemon.sh` - Main daemon logic
- `plugins/plan-saver/hooks/hooks.json` - Session lifecycle hooks

## Adding New Components

### New Skill
- Create a directory in `skills/` with a skill definition `.md` file
- Run `./setup.sh` to symlink

### New Command
- Add `.md` file to `commands/`
- Run `./setup.sh` to symlink

### New Script
- Add `.sh` file to `scripts/`
- Make executable: `chmod +x scripts/your-script.sh`
- Run `./setup.sh` to symlink

## Testing

- Test shell scripts with `shellcheck scripts/*.sh`
- Test plan-saver daemon with `plugins/plan-saver/status.sh`
- Check daemon logs at `~/.claude/.plan-saver/daemon.log`
