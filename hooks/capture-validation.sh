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

# Extract last JSON block containing "validated_at" and "names" from transcript.
# Uses the same brace-counting approach as capture-names.sh.
extract_json_block() {
    local file="$1"
    local field1="$2"
    local field2="$3"
    local result=""
    local buffer=""
    local depth=0
    local in_block=false

    while IFS= read -r line; do
        if [ "$in_block" = false ]; then
            if echo "$line" | grep -q '{'; then
                in_block=true
                buffer="$line"
                local opens closes
                opens=$(echo "$line" | tr -cd '{' | wc -c | tr -d ' ')
                closes=$(echo "$line" | tr -cd '}' | wc -c | tr -d ' ')
                depth=$((opens - closes))
            fi
        else
            buffer="$buffer
$line"
            local opens closes
            opens=$(echo "$line" | tr -cd '{' | wc -c | tr -d ' ')
            closes=$(echo "$line" | tr -cd '}' | wc -c | tr -d ' ')
            depth=$((depth + opens - closes))
        fi

        if [ "$in_block" = true ] && [ "$depth" -le 0 ]; then
            if echo "$buffer" | jq -e "select(has(\"$field1\") and has(\"$field2\"))" >/dev/null 2>&1; then
                result="$buffer"
            fi
            in_block=false
            buffer=""
            depth=0
        fi
    done < "$file"

    echo "$result"
}

VALIDATION_OUTPUT=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    VALIDATION_OUTPUT=$(extract_json_block "$TRANSCRIPT_PATH" "validated_at" "names")
fi

# If no structured output found, create a basic record
if [ -z "$VALIDATION_OUTPUT" ]; then
    VALIDATION_OUTPUT=$(jq -n \
        --arg validated_at "$TIMESTAMP" \
        --arg transcript "$TRANSCRIPT_PATH" \
        '{validated_at: $validated_at, names: [], note: "Output not captured - check transcript", transcript_path: $transcript}')
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
