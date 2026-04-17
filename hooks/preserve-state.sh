#!/bin/bash
# preserve-state.sh - PreCompact hook for claudikins-namer
# Preserves critical state before context compaction.
#
# Matcher: *
# Exit codes:
#   0 - Always (capture only, never blocks)

set -euo pipefail

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
STATE_FILE="$CLAUDE_DIR/namer-state.json"
MERGED_FILE="$CLAUDE_DIR/namer-outputs/names-merged.json"

# Read input JSON from stdin
INPUT=$(cat)

PRESERVED_ITEMS=""

# Check and backup namer-state.json
if [ -f "$STATE_FILE" ]; then
    cp "$STATE_FILE" "$CLAUDE_DIR/namer-state.backup.json"
    PRESERVED_ITEMS="namer-state.json"
fi

# Check if names-merged.json exists
if [ -f "$MERGED_FILE" ]; then
    if [ -n "$PRESERVED_ITEMS" ]; then
        PRESERVED_ITEMS="${PRESERVED_ITEMS}, names-merged.json (at ${MERGED_FILE})"
    else
        PRESERVED_ITEMS="names-merged.json (at ${MERGED_FILE})"
    fi
fi

# Build message
if [ -n "$PRESERVED_ITEMS" ]; then
    MSG="Pre-compact state preserved: ${PRESERVED_ITEMS}"
else
    MSG="Pre-compact: no namer state files found to preserve"
fi

MSG_ESCAPED=$(printf '%s' "$MSG" | jq -Rs '.')
cat <<EOF
{
  "systemMessage": $MSG_ESCAPED
}
EOF

exit 0
