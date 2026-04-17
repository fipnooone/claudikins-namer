#!/bin/bash
# session-init.sh - SessionStart hook for claudikins-namer
# Initializes session state when any namer command starts.
#
# Matcher: claudikins-namer:*
# Exit codes:
#   0 - Always (capture only, never blocks)

set -euo pipefail

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
STATE_FILE="$CLAUDE_DIR/namer-state.json"

# Read input JSON from stdin
INPUT=$(cat)

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_EPOCH=$(date +%s)
SESSION_ID="namer-${TIMESTAMP_EPOCH}"

# Create required directories
mkdir -p "$CLAUDE_DIR/namer-briefs"
mkdir -p "$CLAUDE_DIR/namer-outputs/names"

# Create namer-state.json if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    cat > "$STATE_FILE" <<EOF
{
  "session_id": "${SESSION_ID}",
  "started_at": "${TIMESTAMP}",
  "phase": "init",
  "iteration": 1,
  "agents_completed": 0,
  "names_generated": 0,
  "names_validated": 0
}
EOF
else
    # Read existing session_id
    SESSION_ID=$(jq -r '.session_id // "unknown"' "$STATE_FILE")
fi

# Output system message
MSG="Namer session initialized: ${SESSION_ID}"
MSG_ESCAPED=$(printf '%s' "$MSG" | jq -Rs '.')
cat <<EOF
{
  "systemMessage": $MSG_ESCAPED
}
EOF

exit 0
