#!/bin/bash
# validate-run-completion.sh - Stop hook for claudikins-namer:run
# Checks that the run pipeline completed successfully.
#
# Matcher: claudikins-namer:run
# Exit codes:
#   0 - Always (never blocks session stop)

set -uo pipefail

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
STATE_FILE="$CLAUDE_DIR/namer-state.json"

# Read input JSON from stdin
INPUT=$(cat)

MSG=""

if [ -f "$STATE_FILE" ]; then
    PHASE=$(jq -r '.phase // "unknown"' "$STATE_FILE")
    SESSION_ID=$(jq -r '.session_id // "unknown"' "$STATE_FILE")
    NAMES_GENERATED=$(jq -r '.names_generated // 0' "$STATE_FILE")

    if [ "$PHASE" = "complete" ]; then
        MSG="Namer run ${SESSION_ID} completed successfully: ${NAMES_GENERATED} names generated"
    else
        MSG="Namer run ${SESSION_ID} stopped at phase: ${PHASE}. Resume with /namer:run --resume"
    fi
else
    MSG="No namer state found — run may not have started"
fi

MSG_ESCAPED=$(printf '%s' "$MSG" | jq -Rs '.')
cat <<EOF
{
  "systemMessage": $MSG_ESCAPED
}
EOF

exit 0
