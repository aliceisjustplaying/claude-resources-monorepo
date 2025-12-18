# EPUB Reader Skill for Claude Code

A Claude Code skill that enables efficient reading of EPUB ebook files.

## Capabilities

- **Metadata extraction** - title, author, publisher, date, language
- **Table of contents** - view chapter structure
- **Chapter reading** - read specific chapters by number
- **Full extraction** - extract entire book as markdown
- **Search** - find text with surrounding context

## Directory Structure

```
~/.claude/skills/epub/
├── SKILL.md                              # Skill definition (triggers on EPUB-related requests)
├── AGENTS.md                             # This documentation
├── CLAUDE.md -> AGENTS.md                # Symlink
└── scripts/epub-reader/
    ├── package.json
    ├── tsconfig.json
    ├── src/index.ts                      # TypeScript source
    └── dist/                             # Compiled JavaScript
```

## Technology Stack

- **TypeScript** - main implementation language
- **jszip** - extract EPUB contents (EPUBs are ZIP archives)
- **xml2js** - parse OPF/NCX metadata files
- **turndown** - convert HTML content to Markdown
- **commander** - CLI argument parsing

## CLI Commands

```bash
# View metadata
node ~/.claude/skills/epub/scripts/epub-reader/dist/index.js metadata "<file.epub>"

# List table of contents
node ~/.claude/skills/epub/scripts/epub-reader/dist/index.js toc "<file.epub>"

# Read specific chapter (1-indexed)
node ~/.claude/skills/epub/scripts/epub-reader/dist/index.js chapter "<file.epub>" <number>

# Extract entire book
node ~/.claude/skills/epub/scripts/epub-reader/dist/index.js full "<file.epub>"

# Search for text
node ~/.claude/skills/epub/scripts/epub-reader/dist/index.js search "<file.epub>" "<query>"
```

## How the Skill Works

1. **SKILL.md** defines when Claude should use this skill (any EPUB-related request)
2. Claude automatically invokes the appropriate CLI command based on user intent
3. Output is clean Markdown suitable for reading and analysis

## Rebuilding

If you need to modify and rebuild:

```bash
cd ~/.claude/skills/epub/scripts/epub-reader
npm install
npm run build
```

Restart Claude Code after any changes to SKILL.md for them to take effect.

## Changelog

### 2025-11-26: TOC-to-Chapter Navigation Fix

**Problem:** The table of contents (TOC) display showed sequential numbering that didn't correspond to the `chapter` command's spine-based indexing. Users had no way to know which chapter number to use.

**Solution:**
- TOC now displays inline chapter references: `Chapter Five [ch: 14]`
- Users can see exactly which number to use with the `chapter` command
- Fixed title extraction to properly search the nested TOC tree by href instead of assuming index alignment

**Changes made to `src/index.ts`:**
1. Added `buildHrefToSpineMap()` - creates href-to-spine index mapping
2. Added `findTocItemByHref()` - recursively searches TOC tree for matching href
3. Updated `formatToc()` - shows `[ch: N]` inline with each entry
4. Fixed `getChapterContent()` - uses proper TOC lookup for title extraction

### 2025-11-26: Open-Ended Search Documentation

Added documentation for handling broad/conceptual queries using LLM-assisted query expansion. For queries like "what are the main themes?" or "find references to the protagonist's childhood", Claude expands the query into multiple specific search terms using domain knowledge, runs parallel searches, and synthesizes the results. This leverages Claude's knowledge to catch synonyms and related concepts without requiring fuzzy search infrastructure.
