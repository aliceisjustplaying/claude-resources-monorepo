#!/bin/bash
# Finds and prints the latest plan (or one matching a query)
# Usage: latest-plan.sh [query]
#   No args: prints the highest-numbered plan
#   With query: finds plans matching the query (by number or name)

set -euo pipefail

PLANS_DIR=".claude/plans"

if [[ ! -d "$PLANS_DIR" ]]; then
  echo "No plans directory found at $PLANS_DIR" >&2
  exit 1
fi

# Check if any .md files exist (macOS/BSD compatible)
if [[ -z "$(find "$PLANS_DIR" -maxdepth 1 -name '*.md' -print -quit 2>/dev/null)" ]]; then
  echo "No plans found in $PLANS_DIR" >&2
  exit 1
fi

if [[ -z "${1:-}" ]]; then
  # No query - get the highest numbered plan
  LATEST=$(find "$PLANS_DIR" -maxdepth 1 -name '*.md' -exec basename {} \; \
    | grep -E '^[0-9]{4}-' \
    | sort -n \
    | tail -1 || true)
  if [[ -n "$LATEST" ]]; then
    cat "$PLANS_DIR/$LATEST"
  else
    echo "No numbered plans found" >&2
    exit 1
  fi
else
  # Query provided - search by number or name
  QUERY="$1"
  MATCH=$(find "$PLANS_DIR" -maxdepth 1 -name '*.md' -exec basename {} \; \
    | grep -iE "$QUERY" \
    | sort -n \
    | tail -1 || true)
  if [[ -n "$MATCH" ]]; then
    cat "$PLANS_DIR/$MATCH"
  else
    echo "No plan matching '$QUERY' found" >&2
    exit 1
  fi
fi
