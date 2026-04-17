#!/bin/bash
# capture-names.sh - SubagentStop hook for name-crafter
# Captures name-crafter agent output and saves to per-strategy file.
# Performs dedup merge of all strategy files into names-merged.json.
#
# Matcher: name-crafter
# Exit codes:
#   0 - Always (capture only, never blocks)

set -euo pipefail

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
STATE_FILE="$CLAUDE_DIR/namer-state.json"
NAMES_DIR="$CLAUDE_DIR/namer-outputs/names"
MERGED_FILE="$CLAUDE_DIR/namer-outputs/names-merged.json"

# Read input JSON from stdin
INPUT=$(cat)

# Extract agent info
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // ""')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.agent_transcript_path // ""')

# Only act on name-crafter completions
if [ "$AGENT_NAME" != "name-crafter" ]; then
    exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_EPOCH=$(date +%s)

# Create output directory if needed
mkdir -p "$NAMES_DIR"

# Extract last JSON block containing "strategy" and "names" from transcript.
# Scans the transcript for lines containing opening braces, accumulates lines
# until valid JSON is formed, and keeps the last match with required fields.
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
            # Look for a line containing opening brace
            if echo "$line" | grep -q '{'; then
                in_block=true
                buffer="$line"
                # Count braces
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
            # Try to parse as JSON with required fields
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

NAMES_OUTPUT=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    NAMES_OUTPUT=$(extract_json_block "$TRANSCRIPT_PATH" "strategy" "names")
fi

# If no structured output found, create a basic record
if [ -z "$NAMES_OUTPUT" ]; then
    TRANSCRIPT_ESCAPED=$(printf '%s' "$TRANSCRIPT_PATH" | jq -Rs '.')
    NAMES_OUTPUT=$(jq -n \
        --arg transcript "$TRANSCRIPT_PATH" \
        '{strategy: "unknown", names: [], note: "Output not captured - check transcript", transcript_path: $transcript}')
fi

# Extract strategy name
STRATEGY=$(echo "$NAMES_OUTPUT" | jq -r '.strategy // "unknown"' 2>/dev/null || echo "unknown")

# Backup first (per A-6 pattern)
BACKUP_FILE="$NAMES_DIR/.backup-${STRATEGY}-${TIMESTAMP_EPOCH}.json"
echo "$NAMES_OUTPUT" > "$BACKUP_FILE"

# Save to per-strategy file
OUTPUT_FILE="$NAMES_DIR/${STRATEGY}.json"
echo "$NAMES_OUTPUT" > "$OUTPUT_FILE"

# --- DEDUP MERGE ---
# Read all non-backup *.json from names directory, collect all name entries,
# deduplicate by lowercased name keeping the variant with the higher score,
# and write the merged result to names-merged.json.

# Collect all names from strategy files into a single array
ALL_NAMES="[]"
for f in "$NAMES_DIR"/*.json; do
    [ -f "$f" ] || continue
    basename=$(basename "$f")
    # Skip backup files
    case "$basename" in .backup-*) continue ;; esac

    # Extract .names array, normalize string entries to {name, score} objects
    FILE_NAMES=$(jq -c '
        .names // [] | map(
            if type == "string" then {name: ., score: 0}
            elif type == "object" then .
            else empty
            end
        )
    ' "$f" 2>/dev/null || echo "[]")

    ALL_NAMES=$(echo "$ALL_NAMES" | jq --argjson new "$FILE_NAMES" '. + $new')
done

# Deduplicate: group by lowercased name, keep highest score
DEDUPED=$(echo "$ALL_NAMES" | jq '
    group_by(.name | ascii_downcase)
    | map(sort_by(-.score) | first)
')

NAME_COUNT=$(echo "$DEDUPED" | jq 'length')

# Count source files
SOURCE_COUNT=$(ls "$NAMES_DIR"/*.json 2>/dev/null | grep -cv '\.backup-' || echo "0")

# Write merged file
jq -n \
    --arg merged_at "$TIMESTAMP" \
    --argjson source_count "$SOURCE_COUNT" \
    --argjson names "$DEDUPED" \
    '{merged_at: $merged_at, source_count: $source_count, names: $names}' \
    > "${MERGED_FILE}.tmp" && mv "${MERGED_FILE}.tmp" "$MERGED_FILE"

# Update namer-state.json if it exists
if [ -f "$STATE_FILE" ]; then
    AGENTS_COMPLETED=$(jq -r '.agents_completed // 0' "$STATE_FILE")
    AGENTS_COMPLETED=$((AGENTS_COMPLETED + 1))
    jq --argjson agents "$AGENTS_COMPLETED" \
       --argjson names "${NAME_COUNT:-0}" \
       '.agents_completed = $agents | .names_generated = $names' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi

# Output system message
MSG=$(printf 'name-crafter completed: strategy=%s, total merged names=%s' "$STRATEGY" "$NAME_COUNT")
MSG_ESCAPED=$(printf '%s' "$MSG" | jq -Rs '.')
cat <<EOF
{
  "systemMessage": $MSG_ESCAPED
}
EOF

exit 0
