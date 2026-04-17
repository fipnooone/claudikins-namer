<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://github.com/anthropics/claude-code"><img src="https://img.shields.io/badge/Claude_Code-Plugin-blueviolet.svg" alt="Claude Code Plugin"></a>
  <img src="https://img.shields.io/badge/names-AI_generated-orange.svg" alt="Names: AI Generated">
</p>

<h1 align="center">Claudikins Namer</h1>

<p align="center"><strong>Because "BrandNameGPT-Ultra-Pro-Max" was, ironically, a terrible name.</strong></p>

<p align="center"><em>A brand naming pipeline powered by a squad of opinionated AI agents.</em></p>

---

## Why?

**You asked Claude for a brand name. He gave you "SynergyFlow".**

**You asked for something creative. He suggested "InnovateTech Solutions" and called it a day.**

**You asked for 20 options. He gave you 20 variations of the same word with different suffixes.**

claudikins-namer treats naming like a proper creative process. Multiple strategies running in parallel, real domain checks, cultural screening across languages, and a final report that actually helps you decide - not just a list of words that sound vaguely corporate.

> **Good names don't come from one angle.** They come from exploring many angles and validating the survivors.

---

## The Pipeline

```
┌──────────┐     ┌───────────────────────────────────────────────┐
│  /brief  │────▶│                   /run                        │
└──────────┘     │                                               │
      │          │  Confirm    Generate     Validate     Report  │
      ▼          │  strategies  (parallel)   (domain,    (ranked │
  brand-         │              name-crafter  social,     + full  │
  strategist     │              x4            SEO,        analysis)│
                 │                            cultural)           │
                 │                                      Review   │
                 │                                      ──────   │
                 │                            Iterate?  Accept?  │
                 └───────────────────────────────────────────────┘
```

**Two commands, one goal.** `/brief` figures out what you need. `/run` generates, validates, and reports.

---

## Quick Start

```bash
# Prerequisites: jq, python3 (for hook scripts)

# Add the Claudikins marketplace
/marketplace add fipnooone/claudikins-marketplace

# Install the plugin
/plugin install claudikins-namer
```

Restart Claude Code. Then:

```bash
# Start naming
/namer:brief
```

---

## Meet the Team

| Agent                | Role        | Personality                                                                                                                                                              |
| -------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **brand-strategist** | Interviewer | The brand consultant. Asks the right questions, picks the right strategies. Knows that "fun and professional" isn't a contradiction - it's a brief.                      |
| **name-crafter**     | Generator   | The creative. Gets one strategy, obsesses over it, produces 5-8 polished candidates. Runs in parallel - four of them brainstorming independently.                        |
| **name-validator**   | Checker     | The realist. Checks if your perfect name has an available .com, whether someone already has that Twitter handle, and if it means something unfortunate in Portuguese.    |
| **brand-reporter**   | Analyst     | The strategist. Takes raw candidates and validation data, produces a ranked report with phonetic analysis across 10 languages. The one who tells you _why_ a name works. |

---

## The Two Commands

### `/brief` - "What are we naming?"

Interactive interview to build a structured naming brief.

1. **Context gathering** - brand-strategist asks about your product, audience, market, tone.
2. **Strategy selection** - Picks from 7 naming strategies based on your answers.
3. **Brief output** - Structured JSON with everything `/run` needs.

**Output:** `brief-{session_id}.json` in `.claude/namer-briefs/`

---

### `/run` - "Generate the names"

The full pipeline. Reads the brief, spawns agents, validates results, delivers a report.

1. **Strategy confirmation** - Review and adjust the strategies from your brief.
2. **Parallel generation** - One name-crafter per strategy, running simultaneously. 20-30 candidates total.
3. **Validation** - Domain availability (RDAP), social media handles (Apify), SEO competitiveness, cultural screening.
4. **Report** - Ranked candidates with scores, availability data, and phonetic analysis.
5. **Review** - Accept the top pick, see the full report, or iterate with refinements.

**Key feature:** Iteration loop. Don't like the results? Refine your brief and re-generate - crafters know not to repeat themselves.

**Output:** `report-{session_id}.md` in `.claude/namer-outputs/`

---

## The Seven Strategies

Names don't come from one technique. The pipeline picks the right mix for your brand:

| Strategy               | Technique                  | Examples                    |
| ---------------------- | -------------------------- | --------------------------- |
| **Neologisms**         | Invented words             | Spotify, Hulu, Kodak        |
| **Compound words**     | Merged concepts            | YouTube, FaceBook, Snapchat |
| **Metaphors**          | Symbolic associations      | Amazon, Apple, Jaguar       |
| **Acronyms**           | Letter combinations        | IBM, NASA, IKEA             |
| **Word modifications** | Altered spellings          | Lyft, Tumblr, Flickr        |
| **Foreign language**   | Words from other languages | Audi, Volvo, Samsung        |
| **Evocative**          | Sound symbolism            | Zoom, Slack, Crisp          |

---

## Validation

Every name gets checked. If the tools exist, we use them. If they don't, we say so - never fake results.

| Check            | How                                             | Confidence                           |
| ---------------- | ----------------------------------------------- | ------------------------------------ |
| **Domain**       | RDAP protocol + DNS fallback                    | Verified (programmatic)              |
| **Social media** | Apify username checker (80+ platforms)          | Verified with MCP, unchecked without |
| **SEO**          | Search analysis via Gemini/WebSearch            | AI-assessed                          |
| **Cultural**     | Phonetic + meaning analysis across 10 languages | AI-assessed                          |

MCP tools (via `claudikins-tool-executor`) are optional. Without them, social checks are marked "unchecked" - not guessed.

---

## The Safety Net

| Protection                   | What it does                                                                        |
| ---------------------------- | ----------------------------------------------------------------------------------- |
| **State persistence**        | Pipeline state saved to `.claude/namer-state.json`. Resume anytime with `--resume`. |
| **Hook capture**             | Agent outputs captured automatically by SubagentStop hooks. No lost work.           |
| **Backup-first writes**      | A-6 pattern: backup file written before primary. Always recoverable.                |
| **Pre-compact preservation** | State backed up before context compaction. Resume instructions included.            |
| **Human checkpoints**        | Strategy confirmation, result review, iteration decision - you drive every gate.    |

---

## Architecture

### Model Routing

| Model  | Agents                               | Reason                                                              |
| ------ | ------------------------------------ | ------------------------------------------------------------------- |
| Opus   | `name-crafter`, `brand-reporter`     | Creative generation and nuanced analysis need the strongest model   |
| Sonnet | `brand-strategist`, `name-validator` | Structured interviews and validation checklists - reliable and fast |

### Skills

| Skill                | What's inside                                                                                                                                                                                        |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `naming-strategies`  | 7 strategy definitions, phonetics reference, weighted scoring (memorability 20%, uniqueness 20%, pronounceability 15%, relevance 15%, emotional impact 15%, scalability 10%, domain-friendliness 5%) |
| `validation-methods` | Domain check (RDAP/DNS), social check (Apify), SEO analysis, cultural screening. Each with confidence levels and graceful degradation.                                                               |

### Hooks

5 lifecycle hooks keep the pipeline honest:

| Hook                         | Event        | Purpose                             |
| ---------------------------- | ------------ | ----------------------------------- |
| `session-init.sh`            | SessionStart | Create state file + directories     |
| `capture-names.sh`           | SubagentStop | Capture crafter output, dedup merge |
| `capture-validation.sh`      | SubagentStop | Capture validation results          |
| `preserve-state.sh`          | PreCompact   | Backup state before compaction      |
| `validate-run-completion.sh` | Stop         | Check pipeline completed            |

---

## Requirements

### System

- **jq** - JSON processing in hook scripts
- **python3** - Dedup merge logic in capture hooks

```bash
# macOS
brew install jq python3

# Ubuntu/Debian
sudo apt install jq python3

# Windows
winget install jqlang.jq Python.Python.3
```

### Recommended Plugins

| Plugin                     | Purpose                                                                     |
| -------------------------- | --------------------------------------------------------------------------- |
| `claudikins-tool-executor` | MCP access for Apify social checks, Gemini SEO analysis, Serena code search |

Without `tool-executor`, the pipeline still works - validation just marks MCP-dependent checks as "unchecked" instead of faking results.

---

## Status

**v0.1.0** - Initial Release.

[View the marketplace](https://github.com/fipnooone/claudikins-marketplace)

---

## License

MIT

---

<p align="center"><em>Because "BrandNameGPT-Ultra-Pro-Max" was, ironically, a terrible name.</em></p>
