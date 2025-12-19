# Circle Tweet Cleaner Web App

## Overview
Port the CLI circle-tweet-cleaner to a standalone Vite + React static site where users can drop in their Twitter archive zip and get back a cleaned zip with circle tweets removed.

## Tech Stack
- Vite + React + TypeScript
- JSZip (browser zip handling)
- idb-keyval (IndexedDB for progress persistence > 5MB localStorage limit)
- No backend needed - syndication API is CORS-enabled

## Project Structure
```
circle-tweet-cleaner-web/
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   ├── components/
│   │   ├── DropZone.tsx          # Zip upload + resume detection
│   │   ├── ProgressBar.tsx       # Detection progress
│   │   ├── StatsPanel.tsx        # Real-time stats
│   │   ├── StatusLog.tsx         # Scrolling event log
│   │   └── DownloadButton.tsx    # Cleaned zip download
│   ├── lib/
│   │   ├── syndication.ts        # Port from CLI (token calc, API)
│   │   ├── types.ts              # Port from CLI
│   │   ├── zip.ts                # JSZip wrapper
│   │   ├── parse-tweets.ts       # Parse window.YTD format
│   │   ├── detection.ts          # Detection orchestration
│   │   ├── cleaning.ts           # Filter + rebuild zip
│   │   └── storage.ts            # IndexedDB persistence
│   └── hooks/
│       ├── useDetection.ts       # Detection state machine
│       └── useProgress.ts        # Persistence layer
```

## Implementation Steps

### Phase 1: Project Setup
1. Create new Vite + React + TS project in `circle-tweet-cleaner-web/`
2. Install deps: `jszip`, `idb-keyval`
3. Port `src/types.ts` verbatim from CLI
4. Port `src/syndication.ts` (remove console.log, keep BigInt token calc)

### Phase 2: Zip I/O
1. Create `lib/zip.ts` - JSZip wrapper for parseArchive/generateCleanedZip
2. Create `lib/parse-tweets.ts` - Parse `window.YTD.tweets.part0 = [...]` format
3. Filter out `__MACOSX` entries (same bug we just fixed in community-archive)

### Phase 3: Detection Logic
1. Create `lib/detection.ts` - async generator yielding progress events
2. Port date filtering (May 2022 - Nov 2023), RT skipping, deleted-tweets exclusion
3. Batch processing with 20 concurrent requests
4. Exponential backoff on 429s

### Phase 4: Persistence
1. Create `lib/storage.ts` - IndexedDB via idb-keyval
2. Hash archive (SHA-256) to identify same file on resume
3. Save progress every 100 tweets
4. Resume flow: detect existing progress, offer resume or fresh start

### Phase 5: UI Components
1. DropZone - drag/drop + click to select, validates zip, shows resume prompt
2. ProgressBar - % complete, ETA, rate limit indicator
3. StatsPanel - candidates, checked, circle found, public, errors
4. StatusLog - scrolling log of `[CIRCLE] id`, `[ERROR] id`, rate limit warnings
5. DownloadButton - generates cleaned zip blob, triggers download

### Phase 6: Polish
1. Error states (invalid archive, network failures)
2. Pause/resume controls
3. Mobile-friendly layout
4. Accessible (aria labels)

## Key Files to Port From CLI
- `src/syndication.ts` - BigInt token calculation, retry logic (lines 1-80)
- `src/types.ts` - Tweet, Progress, SyndicationResult interfaces
- `src/detect.ts` - Date range constants, candidate filtering logic
- `src/clean.ts` - tweets.js serialization format preservation

## Deployment
Static site - deploy to Vercel/Netlify/GitHub Pages with zero config.

## Location
New branch `web` in current repo (circle-tweet-cleaner). Web app code goes in `web/` folder to keep it separate from CLI code in `src/`.
