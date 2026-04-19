#!/usr/bin/env bash
# release_notes.sh — generate App Store "What's New" from git log
# Usage: release_notes.sh [since-tag]
# If no tag given, uses commits since last tag; falls back to last 20 commits.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"   # scripts/pipeline → scripts → project
cd "$PROJECT_ROOT"

since="${1:-}"
if [[ -z "$since" ]]; then
    since=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
fi

if [[ -n "$since" ]]; then
    range="${since}..HEAD"
else
    range="-20"
fi

current_version=$(plutil -extract CFBundleShortVersionString raw -o - "Simone/Info.plist" 2>/dev/null || echo "?.?")

cat <<HEADER
What's new in Simone ${current_version}

HEADER

# Extract user-facing changes: skip "chore:", "test:", "wip:", merge commits.
# Keep "fix:", "polish:", "feat:", "tune:", or anything v-prefixed.
git log ${range} --pretty=format:'%s' --no-merges 2>/dev/null \
    | grep -Eiv '^(chore|test|wip|ci|build|refactor|style|docs):' \
    | grep -Ev '^Merge ' \
    | awk '!seen[$0]++' \
    | head -8 \
    | sed 's/^/• /'

echo ""
echo ""
echo "Thanks for listening."
