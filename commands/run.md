---
name: claudikins-namer:run
description: "Name generation pipeline. Reads brief, spawns parallel name-crafter agents, validates candidates, generates final report. Step 2/2 pipeline."
argument-hint: "[BRIEF_PATH] [--resume] [--skip-validation] [--max-crafters N]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
  - AskUserQuestion
  - TodoWrite
  - Write
  - Skill
  - WebSearch
  - mcp__plugin_claudikins-tool-executor_tool-executor__search_tools
  - mcp__plugin_claudikins-tool-executor_tool-executor__get_tool_schema
  - mcp__plugin_claudikins-tool-executor_tool-executor__execute_code
skills:
  - naming-strategies
  - validation-methods
output-schema:
  type: object
  properties:
    session_id:
      type: string
    status:
      type: string
      enum: [completed, paused, aborted]
    report_path:
      type: string
    names_generated:
      type: integer
    names_validated:
      type: integer
  required: [session_id, status]
---

# /namer:run — Name Generation Pipeline

## Pipeline Position

> `brief` -> **`run`** (Step 2 of 2)

- **Previous step:** `/namer:brief` — produces the brief JSON with project context, constraints, and selected strategies.
- **This command:** Orchestrates the entire generation + validation + reporting pipeline. Reads the brief, spawns parallel name-crafter agents, validates candidates, and generates a final report.

## Language Behaviour

Detect the language from the earliest human message in the conversation. All output, prompts, and reports must use that language. If ambiguous, default to English.

## Flag Handling

```
BRIEF_PATH        Path to brief JSON (default: most recent file in .claude/namer-briefs/)
--resume           Resume from checkpoint saved in namer-state.json
--skip-validation  Skip the name-validator phase, go straight to report (for speed/debugging)
--max-crafters N   Override max parallel name-crafter agents (default: 4)
```

Parse flags from the argument string before entering Phase 0.

---

## Phase 0: Initialization

1. **Load brief:**
   - If `BRIEF_PATH` argument is provided, load that file.
   - Otherwise, find the most recent `.json` file in `.claude/namer-briefs/` (sort by filename timestamp).
   - If no brief found, stop immediately:
     > "No brief found. Run `/namer:brief` first to create one."

2. **Validate brief JSON** — confirm required fields exist:
   - `project_name`
   - `description`
   - `strategies_selected`
   - `constraints`
   - `session_id`

   If any required field is missing, report which fields are absent and stop.

3. **Check for `--resume`:**
   - If `--resume` flag is set, read `.claude/namer-state.json`.
   - Restore phase, iteration count, and agent progress.
   - Jump to the saved phase instead of starting from Phase 1.

4. **Initialize state** — create or update `.claude/namer-state.json`:

   ```json
   {
     "session_id": "namer-YYYY-MM-DD-HHMM",
     "started_at": "ISO timestamp",
     "phase": "strategy-selection",
     "brief_path": ".claude/namer-briefs/brief-{session_id}.json",
     "strategies_selected": [],
     "agents_spawned": 0,
     "agents_completed": 0,
     "names_generated": 0,
     "names_validated": 0,
     "iteration": 1,
     "mcp_available": false,
     "human_decisions": []
   }
   ```

5. **Detect MCP availability:**
   - Call `search_tools("username availability")` and record whether it returns results.
   - Set `state.mcp_available` accordingly. MCP tools enable richer validation (e.g., live domain/social checks).

---

## Phase 1: Strategy Confirmation

1. Read `strategies_selected` from the loaded brief.

2. Present strategies to the user via `AskUserQuestion`:

   ```
   Selected strategies from brief:

   1. {strategy_name} — {reason}
   2. {strategy_name} — {reason}
   ...

   [Proceed] [Add strategy] [Remove strategy] [Change strategies]
   ```

3. Handle user response:
   - **Proceed** — continue to Phase 2.
   - **Add strategy** — ask which strategy to add, update brief file, re-present.
   - **Remove strategy** — ask which to remove, update brief file, re-present.
   - **Change strategies** — ask for new set, update brief file, re-present.

4. Record the decision in `state.human_decisions` and update `state.strategies_selected`.

5. Update state: `phase` -> `"generation"`.

---

## Phase 2: Parallel Name Generation

1. Determine the number of strategies. Set max parallel agents to 4 (or the value of `--max-crafters`).

2. For each strategy in `brief.strategies_selected`, spawn a **name-crafter** agent:

   ```
   Task(name-crafter, {
     prompt: `
       strategy: ${strategy.strategy}
       brief: ${JSON.stringify(brief)}
       iteration: ${state.iteration}
     `,
     context: "fork",
     background: true
   })
   ```

3. If more than `max-crafters` strategies exist, batch them in groups. Wait for each batch to complete before spawning the next.

4. Increment `state.agents_spawned` for each agent launched.

5. The `SubagentStop` hook (`capture-names.sh`) saves each agent's results to:

   ```
   .claude/namer-outputs/names/{strategy}.json
   ```

6. Wait for all agents in the current batch to complete before proceeding.

7. **Merge results:**
   - Read all files from `.claude/namer-outputs/names/`.
   - Combine into a single candidate list.

8. **Deduplication:**
   - Normalize each name: lowercase, trim whitespace.
   - If two names match after normalization, keep the variant with the better reasoning score or richer metadata.
   - Preserve the original casing of the kept variant.

9. Save the merged, deduplicated list to `.claude/namer-outputs/names-merged.json`.

10. Update state:
    - `agents_completed` — total agents that finished.
    - `names_generated` — count of unique names after dedup.

11. Present summary to user:
    > "Generated {N} unique names across {M} strategies."

---

## Phase 3: Validation

**Skip this phase if `--skip-validation` flag is set.** Jump directly to Phase 4.

1. Spawn a **name-validator** agent:

   ```
   Task(name-validator, {
     prompt: `
       names: ${names_from_merged}
       brief: ${JSON.stringify(brief)}
     `,
     context: "fork",
     background: true
   })
   ```

2. The `SubagentStop` hook (`capture-validation.sh`) saves validation results to:

   ```
   .claude/namer-outputs/validation-{session_id}.json
   ```

3. Wait for the validator to complete.

4. Read validation results. Each name should have:
   - Domain availability assessment
   - Social media handle availability
   - Trademark/conflict risk
   - Linguistic/cultural checks
   - Overall score

5. Update state:
   - `phase` -> `"reporting"`
   - `names_validated` — count of names that passed through validation.

---

## Phase 4: Report Generation

1. Spawn a **brand-reporter** agent:

   ```
   Task(brand-reporter, {
     prompt: `
       brief: ${JSON.stringify(brief)}
       names: ${names_with_scores}
       validation: ${validation_results}
     `,
     context: "fork"
   })
   ```

   Note: This agent is NOT spawned in background — wait for it to complete since the report is needed for the next phase.

2. The brand-reporter saves its report to:

   ```
   .claude/namer-outputs/report-{session_id}.md
   ```

3. Update state: `phase` -> `"review"`.

---

## Phase 5: User Review

1. Read the report and extract the top 5-10 candidates (ranked by overall score).

2. Present to the user via `AskUserQuestion`:

   ```
   Top candidates:

   1. Vexora (8.2/10) — .com available, all socials free
   2. Lumyra (7.9/10) — .com available, Twitter taken
   3. Brevvo (7.6/10) — .io available, all socials free
   ...

   [Accept top pick] [See full report] [Iterate with refinements] [Done]
   ```

3. Handle user response:
   - **Accept top pick** — record selection, proceed to Phase 6.
   - **See full report** — display the full report path and contents summary, then re-present the choices.
   - **Iterate with refinements** — enter refinement flow:
     1. Ask: "What would you like to change? (e.g., different tone, more playful, avoid certain patterns, focus on a specific strategy)"
     2. Record feedback in `state.human_decisions`.
     3. Increment `state.iteration`.
     4. Update the brief with refinement notes.
     5. Return to **Phase 2** with the updated brief. Name-crafter agents will see `iteration > 1` and generate NEW names, not repeats.
   - **Done** — proceed to Phase 6 with current results.

---

## Phase 6: Completion

1. Present the final report path to the user:

   > "Report saved to `.claude/namer-outputs/report-{session_id}.md`. Session complete."

2. Update state:
   - `phase` -> `"complete"`

3. Return the output schema:

   ```json
   {
     "session_id": "{session_id}",
     "status": "completed",
     "report_path": ".claude/namer-outputs/report-{session_id}.md",
     "names_generated": N,
     "names_validated": M
   }
   ```

---

## State Management

State is persisted to `.claude/namer-state.json` and updated at every phase transition. Full schema:

```json
{
  "session_id": "namer-YYYY-MM-DD-HHMM",
  "started_at": "ISO timestamp",
  "phase": "brief|strategy-selection|generation|validation|reporting|review|complete",
  "brief_path": ".claude/namer-briefs/brief-{session_id}.json",
  "strategies_selected": ["neologisms", "compound-words"],
  "agents_spawned": 0,
  "agents_completed": 0,
  "names_generated": 0,
  "names_validated": 0,
  "iteration": 1,
  "mcp_available": true,
  "human_decisions": []
}
```

Key fields:

- `phase` — determines where `--resume` jumps to.
- `iteration` — incremented on each refinement round. Crafter agents use this to avoid generating duplicates.
- `human_decisions` — audit trail of user choices at each checkpoint.
- `mcp_available` — whether MCP tools were detected for enhanced validation.

---

## Error Recovery

- **On any phase failure:** Save current state to `.claude/namer-state.json` as a checkpoint. Present options:

  ```
  Phase {N} failed: {error description}

  [Retry phase] [Skip phase] [Abort]
  ```

- **On context exhaustion:** Save state immediately and inform the user:

  > "Context limit approaching. State saved. Run `/namer:run --resume` to continue from where we left off."

- **On agent failure:** If a name-crafter agent fails, log it and continue with results from successful agents. Report the gap:

  > "Strategy '{strategy}' agent failed. Continuing with {N-1} strategies. You can retry later with --resume."

- **On abort:** Update state with `phase` set to current phase and return:
  ```json
  {
    "session_id": "{session_id}",
    "status": "aborted"
  }
  ```
