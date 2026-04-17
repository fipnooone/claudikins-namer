# claudikins-namer

Brand name generation pipeline for [Claude Code](https://claude.ai/code). Generates, validates, and scores brand name candidates using parallel AI agents.

## Installation

```bash
claude mcp add --plugin claudikins-namer
```

Or add to `.claude/plugins/`:

```json
{ "plugin": "claudikins-namer" }
```

Requires: Claude Code CLI with plugin support.

## Usage

The pipeline has two commands:

### 1. Create a brief

```
/namer:brief
```

Interactive interview that captures your product context, audience, tone, constraints, and naming strategies. Outputs a structured brief JSON to `.claude/namer-briefs/`.

Flags:

- `--resume SESSION_ID` — resume a previous session
- `--list-sessions` — show available sessions

### 2. Run the pipeline

```
/namer:run
```

Reads the brief, spawns parallel name-crafter agents (one per strategy), validates candidates, and generates a ranked report.

Flags:

- `BRIEF_PATH` — path to brief JSON (default: most recent)
- `--resume` — resume from checkpoint
- `--skip-validation` — skip validation phase
- `--max-crafters N` — max parallel agents (default: 4)

## Pipeline

```
/namer:brief                    /namer:run
┌──────────────┐    ┌────────────────────────────────────────────┐
│              │    │                                            │
│ Interview    │───>│ Strategy   → Parallel    → Validation      │
│ (brand-      │    │ Confirm     Generation    (domain, social, │
│  strategist) │    │             (name-        SEO, cultural)   │
│              │    │              crafter x4)                    │
│ Brief JSON   │    │                          → Report          │
│              │    │                            (brand-reporter) │
└──────────────┘    │                                            │
                    │            → User Review → Iterate?        │
                    └────────────────────────────────────────────┘
```

## Architecture

### Commands

| Command        | Description                                     |
| -------------- | ----------------------------------------------- |
| `/namer:brief` | Collect project context and naming constraints  |
| `/namer:run`   | Orchestrate generation + validation + reporting |

### Agents

| Agent              | Model  | Role                                                |
| ------------------ | ------ | --------------------------------------------------- |
| `brand-strategist` | Sonnet | Conducts brief interview, selects strategies        |
| `name-crafter`     | Opus   | Generates 5-8 names per strategy (runs in parallel) |
| `name-validator`   | Sonnet | Validates domain, social, SEO, cultural fit         |
| `brand-reporter`   | Opus   | Produces ranked report with phonetic analysis       |

### Skills

| Skill                | Purpose                                                                                                                 |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `naming-strategies`  | 7 strategies (neologisms, compounds, metaphors, acronyms, modifications, foreign language, evocative) + scoring weights |
| `validation-methods` | Domain (RDAP/DNS), social (Apify MCP), SEO, cultural checks with confidence levels                                      |

### Hooks

| Hook                    | Event                         | Purpose                                |
| ----------------------- | ----------------------------- | -------------------------------------- |
| `session-init.sh`       | SessionStart                  | Initialize state and directories       |
| `capture-names.sh`      | SubagentStop (name-crafter)   | Capture names, dedup merge             |
| `capture-validation.sh` | SubagentStop (name-validator) | Capture validation results             |
| `preserve-state.sh`     | PreCompact                    | Backup state before context compaction |

## Naming Strategies

The pipeline supports 7 naming strategies, selected during the brief:

1. **Neologisms** — invented words (Spotify, Hulu)
2. **Compound words** — merged concepts (YouTube, FaceBook)
3. **Metaphors** — symbolic associations (Amazon, Apple)
4. **Acronyms** — letter combinations (IBM, NASA)
5. **Word modifications** — altered spellings (Lyft, Tumblr)
6. **Foreign language** — words from other languages (Audi, Volvo)
7. **Evocative/sound symbolism** — phonetic impact (Zoom, Slack)

## Validation

Each name candidate is checked across 4 dimensions:

| Check                   | Method                          | Confidence                          |
| ----------------------- | ------------------------------- | ----------------------------------- |
| Domain availability     | RDAP protocol + DNS fallback    | verified / partial                  |
| Social media handles    | Apify MCP (80+ platforms)       | verified (MCP) / unchecked (no MCP) |
| SEO competitiveness     | Search analysis                 | ai-assessed                         |
| Cultural/linguistic fit | AI phonetic + cultural analysis | ai-assessed                         |

MCP tools are optional — without them, social checks are marked "unchecked" rather than faked.

## Scoring

Names are scored on a weighted 10-point scale:

| Criterion           | Weight |
| ------------------- | ------ |
| Memorability        | 20%    |
| Uniqueness          | 20%    |
| Pronounceability    | 15%    |
| Relevance           | 15%    |
| Emotional impact    | 15%    |
| Scalability         | 10%    |
| Domain-friendliness | 5%     |

## Output

The pipeline produces:

- **Brief JSON** — `.claude/namer-briefs/brief-{session_id}.json`
- **Per-strategy names** — `.claude/namer-outputs/names/{strategy}.json`
- **Merged candidates** — `.claude/namer-outputs/names-merged.json`
- **Validation results** — `.claude/namer-outputs/validation-{session_id}.json`
- **Final report** — `.claude/namer-outputs/report-{session_id}.md`

## State & Resume

State is persisted to `.claude/namer-state.json`. If the pipeline is interrupted (context exhaustion, abort), resume with:

```
/namer:run --resume
```

## File Structure

```
claudikins-namer/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── brand-reporter.md
│   ├── brand-strategist.md
│   ├── name-crafter.md
│   └── name-validator.md
├── commands/
│   ├── brief.md
│   └── run.md
├── hooks/
│   ├── hooks.json
│   ├── capture-names.sh
│   ├── capture-validation.sh
│   ├── preserve-state.sh
│   └── session-init.sh
├── skills/
│   ├── naming-strategies/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── phonetics.md
│   │       ├── scoring.md
│   │       └── strategies.md
│   └── validation-methods/
│       ├── SKILL.md
│       └── references/
│           ├── cultural-check.md
│           ├── domain-check.md
│           ├── seo-check.md
│           └── social-check.md
└── README.md
```

## License

MIT
