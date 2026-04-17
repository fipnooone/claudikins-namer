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

# Try to extract names output from transcript
NAMES_OUTPUT=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    # Extract the last JSON block that contains "strategy" and "names" fields
    NAMES_OUTPUT=$(cat "$TRANSCRIPT_PATH" | \
        grep -o '{[^}]*"strategy"[^}]*"names"[^}]*}' | \
        tail -1 || echo "")

    # If simple grep didn't work, try extracting larger JSON blocks
    if [ -z "$NAMES_OUTPUT" ]; then
        NAMES_OUTPUT=$(python3 -c "
import sys, json, re

text = open('$TRANSCRIPT_PATH').read()
# Find all JSON-like blocks
blocks = re.findall(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', text)
result = ''
for block in reversed(blocks):
    try:
        obj = json.loads(block)
        if 'strategy' in obj and 'names' in obj:
            result = block
            break
    except:
        pass
print(result)
" 2>/dev/null || echo "")
    fi
fi

# If no structured output found, create a basic record
if [ -z "$NAMES_OUTPUT" ]; then
    NAMES_OUTPUT=$(cat <<EOF
{
  "strategy": "unknown",
  "names": [],
  "note": "Output not captured - check transcript",
  "transcript_path": "${TRANSCRIPT_PATH}"
}
EOF
)
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
# Read all *.json (not .backup-*) from names directory and merge
MERGE_SCRIPT=$(cat <<'PYEOF'
import sys, json, os, glob

names_dir = sys.argv[1]
merged_file = sys.argv[2]

all_names = []
# Read all non-backup JSON files
for fpath in sorted(glob.glob(os.path.join(names_dir, "*.json"))):
    basename = os.path.basename(fpath)
    if basename.startswith(".backup-"):
        continue
    try:
        with open(fpath) as f:
            data = json.load(f)
        if "names" in data and isinstance(data["names"], list):
            for name_entry in data["names"]:
                if isinstance(name_entry, dict):
                    all_names.append(name_entry)
                elif isinstance(name_entry, str):
                    all_names.append({"name": name_entry, "score": 0})
    except Exception:
        pass

# Deduplicate by lowercased name, keeping higher score variant
seen = {}
for entry in all_names:
    name = entry.get("name", "")
    key = name.lower()
    score = entry.get("score", 0)
    if key not in seen or score > seen[key].get("score", 0):
        seen[key] = entry

deduped = list(seen.values())

merged = {
    "merged_at": sys.argv[3],
    "source_count": len(glob.glob(os.path.join(names_dir, "*.json"))) - len(glob.glob(os.path.join(names_dir, ".backup-*.json"))),
    "names": deduped
}

with open(merged_file, "w") as f:
    json.dump(merged, f, indent=2)

print(len(deduped))
PYEOF
)

NAME_COUNT=$(python3 -c "$MERGE_SCRIPT" "$NAMES_DIR" "$MERGED_FILE" "$TIMESTAMP" 2>/dev/null || echo "0")

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
