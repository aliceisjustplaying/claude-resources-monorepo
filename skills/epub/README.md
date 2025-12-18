# EPUB Reader Skill for Claude Code

A Claude Code skill that enables efficient reading of EPUB ebook files.

## Features

- **Metadata extraction** - title, author, publisher, date, language
- **Table of contents** - view chapter structure with chapter references (`[ch: N]`)
- **Chapter reading** - read specific chapters by number
- **Full extraction** - extract entire book as markdown
- **Search** - find text with surrounding context
- **Open-ended search** - broad queries are automatically expanded using Claude's domain knowledge

## Installation

The skill is installed at `~/.claude/skills/epub/`. Restart Claude Code after installation for the skill to be discovered.

## Usage

Just ask Claude naturally about EPUB files:

- "What's in this EPUB file?"
- "Show me the table of contents"
- "Read chapter 5"
- "Search for 'democracy' in the book"
- "Extract the entire book as markdown"
- "What does the book say about the main character's motivation?" (open-ended queries work too!)

Claude will automatically use this skill when it detects EPUB-related requests.

## CLI Commands

The skill uses a TypeScript CLI tool under the hood:

```bash
# View metadata
node ~/.claude/skills/epub/scripts/epub-reader/dist/index.js metadata "book.epub"

# List table of contents
node ~/.claude/skills/epub/scripts/epub-reader/dist/index.js toc "book.epub"

# Read specific chapter (1-indexed)
node ~/.claude/skills/epub/scripts/epub-reader/dist/index.js chapter "book.epub" 3

# Extract entire book
node ~/.claude/skills/epub/scripts/epub-reader/dist/index.js full "book.epub"

# Search for text
node ~/.claude/skills/epub/scripts/epub-reader/dist/index.js search "book.epub" "query"
```

## Technology Stack

- **TypeScript** - main implementation language
- **jszip** - extract EPUB contents (EPUBs are ZIP archives)
- **xml2js** - parse OPF/NCX metadata files
- **turndown** - convert HTML content to Markdown
- **commander** - CLI argument parsing

## Development

To modify and rebuild:

```bash
cd ~/.claude/skills/epub/scripts/epub-reader
npm install
npm run build
```

Restart Claude Code after any changes to `SKILL.md`.

## License

MIT
