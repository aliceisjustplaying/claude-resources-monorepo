# Claude Code Skills Monorepo

## Project Overview

This is a monorepo containing Claude Code skills, commands, scripts, and plugins. Key components include:
- **Skills** - EPUB reader and PDF-to-Markdown converter
- **plan-saver plugin** - Automatically distributes plans from Claude Code's plan mode to their respective project directories

## Tech Stack

- **Shell scripts (Bash)** - Automation, daemon scripts, and utilities
- **TypeScript/Node.js** - EPUB skill CLI tool
- **Python** - PDF-to-Markdown skill (uses docling for AI-powered extraction)
- **jq** - JSON manipulation for session registry
- **fswatch** - File system monitoring (macOS)
- **launchd** - Daemon management (macOS)

## Project Structure

```
├── commands/                    # Claude Code slash commands (.md files)
├── scripts/                     # Standalone utility scripts (.sh)
├── skills/                      # Claude Code skills
│   ├── epub/                    # EPUB ebook reader (TypeScript)
│   └── pdf-to-markdown/         # PDF to Markdown converter (Python)
├── plugins/                     # Claude Code plugins
│   └── plan-saver/              # Auto-distributes plans to projects
├── .claude/plans/               # Example plans for this repo
└── setup.sh                     # Installation script
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
- `skills/epub/SKILL.md` - EPUB skill definition
- `skills/epub/scripts/epub-reader/src/index.ts` - EPUB reader CLI implementation
- `skills/pdf-to-markdown/SKILL.md` - PDF skill definition
- `skills/pdf-to-markdown/scripts/pdf_to_md.py` - PDF converter CLI implementation
- `plugins/plan-saver/install.sh` - Installs plan-saver daemon
- `plugins/plan-saver/daemon/plan-saver-daemon.sh` - Main daemon logic
- `plugins/plan-saver/hooks/hooks.json` - Session lifecycle hooks

## Skills

### epub
Reads and extracts content from EPUB ebook files. Capabilities include:
- View metadata (title, author, publisher)
- List table of contents
- Read specific chapters
- Extract entire book as Markdown
- Search text with context

**Tech:** TypeScript CLI using commander, jszip, xml2js, turndown

### pdf-to-markdown
Converts PDF documents to structured Markdown. Capabilities include:
- Text extraction with formatting preservation
- Table extraction using IBM's TableFormer AI
- Image extraction with caching
- Multi-column layout support

**Tech:** Python using docling for AI-powered document understanding

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
