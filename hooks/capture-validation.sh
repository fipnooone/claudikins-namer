#!/bin/bash
# capture-validation.sh - SubagentStop hook for name-validator
# Captures name-validator agent output and updates state.
#
# Matcher: name-validator
# Exit codes:
#   0 - Always (capture only, never blocks)

set -euo pipefail

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
STATE_FILE="$CLAUDE_DIR/namer-state.json"
OUTPUTS_DIR="$CLAUDE_DIR/namer-outputs"

# Read input JSON from stdin
INPUT=$(cat)

# Extract agent info
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // ""')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.agent_transcript_path // ""')

# Only act on name-validator completions
if [ "$AGENT_NAME" != "name-validator" ]; then
    exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_EPOCH=$(date +%s)

# Create output directory if needed
mkdir -p "$OUTPUTS_DIR"

# Get session_id from namer-state.json
SESSION_ID="unknown"
if [ -f "$STATE_FILE" ]; then
    SESSION_ID=$(jq -r '.session_id // "unknown"' "$STATE_FILE")
fi

# Try to extract validation output from transcript
VALIDATION_OUTPUT=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    # Extract the last JSON block that contains "validated_at" and "names" fields
    VALIDATION_OUTPUT=$(python3 -c "
import sys, json, re

text = open('$TRANSCRIPT_PATH').read()
blocks = re.findall(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', text)
result = ''
for block in reversed(blocks):
    try:
        obj = json.loads(block)
        if 'validated_at' in obj and 'names' in obj:
            result = block
            break
    except:
        pass
print(result)
" 2>/dev/null || echo "")
fi

# If no structured output found, create a basic record
if [ -z "$VALIDATION_OUTPUT" ]; then
    VALIDATION_OUTPUT=$(cat <<EOF
{
  "validated_at": "${TIMESTAMP}",
  "names": [],
  "note": "Output not captured - check transcript",
  "transcript_path": "${TRANSCRIPT_PATH}"
}
EOF
)
fi

# Backup first (per A-6 pattern)
BACKUP_FILE="$OUTPUTS_DIR/.backup-validation-${TIMESTAMP_EPOCH}.json"
echo "$VALIDATION_OUTPUT" > "$BACKUP_FILE"

# Save validation output
OUTPUT_FILE="$OUTPUTS_DIR/validation-${SESSION_ID}.json"
echo "$VALIDATION_OUTPUT" > "$OUTPUT_FILE"

# Count validated names
VALIDATED_COUNT=$(echo "$VALIDATION_OUTPUT" | jq '.names | length' 2>/dev/null || echo "0")

# Update namer-state.json if it exists
if [ -f "$STATE_FILE" ]; then
    jq --argjson validated "${VALIDATED_COUNT:-0}" \
       '.names_validated = $validated | .phase = "reporting"' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi

# Output system message
MSG=$(printf 'name-validator completed: %s names validated, phase set to reporting' "$VALIDATED_COUNT")
MSG_ESCAPED=$(printf '%s' "$MSG" | jq -Rs '.')
cat <<EOF
{
  "systemMessage": $MSG_ESCAPED
}
EOF

exit 0
