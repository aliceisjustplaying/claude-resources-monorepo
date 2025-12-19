# Claude Code Skills Monorepo

A centralized repository for Claude Code extensions including skills, commands, scripts, and plugins.

---

## ✨ Features

| Component | Description |
|-----------|-------------|
| **Skills** | EPUB reader and PDF-to-Markdown converter for document processing |
| **Plan Saver Plugin** | Automatically saves plans from plan mode to project directories |
| **Slash Commands** | `/latest-plan`, `/reflect`, `/handoff` for workflow enhancement |
| **Utility Scripts** | Standalone scripts for plan management |

---

## 🚀 Installation

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

---

## 📦 Components

### Plugins

#### plan-saver (v2.2.0)

Automatically distributes plans created in Claude Code's plan mode to their respective project directories.

**How it works:**
1. When Claude Code starts, a session is registered with the working directory
2. The daemon watches `~/.claude/plans/` for new plan files
3. When a plan is saved, it's matched to the correct project via session tracking
4. Plans are copied to `{project}/.claude/plans/NNNN-title.md` with auto-incrementing numbers
5. When plans are updated, the existing destination is updated (no duplicate files)

**Commands:**
```bash
# Check daemon status
plugins/plan-saver/status.sh

# Uninstall
plugins/plan-saver/uninstall.sh
```

#### handoff (v1.0.0)

Automatically detects handoff files and prompts Claude to continue previous work.

**How it works:**
1. On session start, checks if `.claude/handoff.md` exists in the project
2. If found, injects a prompt telling Claude to read it and continue
3. Near-zero overhead when no handoff file exists (~5ms shell check)

**Install:**
```bash
cd plugins/handoff
./install.sh
```

**Usage:**
1. Run `/handoff` when context is running low
2. Start a new session — Claude automatically picks up where you left off
3. Claude deletes the handoff file after absorbing the context

---

### Skills

#### epub

Read and extract content from EPUB ebook files.

| Capability | Description |
|------------|-------------|
| Metadata | View title, author, publisher, description |
| TOC | List table of contents with chapter references |
| Read | Read specific chapters by number |
| Extract | Export entire book as Markdown |
| Search | Search text with surrounding context |

**Requirements:** Node.js, built with `bun install && bun run build` in `skills/epub/scripts/epub-reader/`

#### pdf-to-markdown

Convert PDF documents to clean, structured Markdown for full context loading.

| Capability | Description |
|------------|-------------|
| Text | Formatting preservation (headers, bold, italic, lists) |
| Tables | IBM TableFormer AI extraction (~93.6% accuracy) |
| Images | Extraction with caching |
| Layout | Multi-column support |

**Requirements:** Python 3.11+, virtual environment created automatically on first use

---

### Commands

| Command | Description |
|---------|-------------|
| `/latest-plan` | Load the most recent plan from `.claude/plans/` |
| `/latest-plan <query>` | Find a plan by number or name |
| `/reflect` | Reflect on session learnings and update CLAUDE.md |
| `/handoff` | Create a handoff document for session continuity |

#### `/reflect`

Prompts Claude to think carefully about what was learned during the session and update the project's CLAUDE.md with durable, non-obvious, actionable insights for future sessions.

#### `/handoff`

Creates a structured handoff document at `.claude/handoff.md` containing:
- **Goal** — what you're trying to accomplish
- **Progress** — what's done, files changed, decisions made
- **Current State** — where work stopped, any partial work
- **Remaining Work** — what's left to do
- **Context** — file paths, patterns, gotchas discovered
- **Blockers** — anything stuck or needing answers

Start a new session with "Continue from .claude/handoff.md" to pick up where you left off.

---

### Scripts

| Script | Description |
|--------|-------------|
| `latest-plan.sh` | Find and display the latest plan file |
| `save-plan.sh` | Save a plan to `.claude/plans/` with auto-numbering |

---

## 📁 Directory Structure

```
claude-code-skills-monorepo/
├── commands/                       # Slash command definitions
│   ├── handoff.md
│   ├── latest-plan.md
│   └── reflect.md
├── scripts/                        # Utility scripts
│   ├── latest-plan.sh
│   └── save-plan.sh
├── skills/                         # Claude Code skills
│   ├── epub/                       # EPUB reader (TypeScript)
│   │   ├── SKILL.md
│   │   ├── README.md
│   │   └── scripts/epub-reader/
│   └── pdf-to-markdown/            # PDF converter (Python)
│       ├── SKILL.md
│       ├── README.md
│       └── scripts/
├── plugins/
│   ├── handoff/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── hooks/
│   │   │   └── hooks.json
│   │   ├── scripts/
│   │   │   └── check-handoff.sh
│   │   └── install.sh
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
├── .claude-plugin/
│   └── marketplace.json
├── setup.sh                        # Main installation script
├── CLAUDE.md                       # Project instructions for Claude
└── README.md
```

---

## ➕ Adding New Components

### Adding a Skill

1. Create a new directory under `skills/`
2. Add your skill definition `.md` file
3. Run `./setup.sh` to create symlinks

### Adding a Command

1. Create a `.md` file in `commands/`
2. Run `./setup.sh` to create symlinks

### Adding a Script

1. Create your `.sh` script in `scripts/`
2. Make it executable: `chmod +x scripts/your-script.sh`
3. Run `./setup.sh` to create symlinks

---

## 📋 Shell Script Standards

All shell scripts in this repository follow these standards:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- **Shellcheck compliant** — run `shellcheck` before committing
- **Proper quoting** — all variable expansions are quoted
- **Modern syntax** — use `[[ ]]` for conditionals

---

## 📌 Requirements

| Requirement | Purpose |
|-------------|---------|
| macOS | launchd-based daemon |
| Homebrew | dependency installation |
| Claude Code CLI | core functionality |
| Node.js / Bun | epub skill |
| Python 3.11+ | pdf-to-markdown skill |

---

## 🔧 Troubleshooting

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

---

## 📄 License

MIT
