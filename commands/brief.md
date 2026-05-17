---
name: claudikins-namer:brief
description: "Interactive brand naming brief collection. Conducts interview, selects strategies, saves brief for /namer:run."
argument-hint: "[--resume SESSION_ID] [--list-sessions]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Task
  - AskUserQuestion
  - TodoWrite
skills:
  - naming-strategies
output-schema:
  type: object
  properties:
    session_id:
      type: string
    status:
      type: string
      enum: [completed, paused, aborted]
    brief_path:
      type: string
  required: [session_id, status, brief_path]
---

# /namer:brief -- Interactive Brand Naming Brief

## Command Overview

This command is **Step 1** of the namer pipeline: `brief` -> `run`.

It collects naming requirements through an interactive interview with the user, then saves a structured brief that `/namer:run` consumes to generate name candidates.

Output location: `.claude/namer-briefs/brief-{session_id}.json`

## Language Behaviour

Detect the language from the earliest human message in the conversation. All user-facing responses and `AskUserQuestion` content MUST be in that detected language. Internal reasoning and agent instructions remain in English.

## Flag Handling

```
--resume SESSION_ID  -> Load the existing brief from .claude/namer-briefs/brief-{SESSION_ID}.json,
                        continue the interview from the last answered question.
--list-sessions      -> Read .claude/namer-briefs/, list available session IDs with
                        their timestamps and statuses, then exit.
                        No interview is started.
```

If no flags are provided, start a new session.

## Phase 1: Session Initialisation

1. Generate a session ID in the format: `namer-YYYY-MM-DD-HHMM` (using current date/time).
2. If `--resume` was passed, locate the existing brief and state files. If not found, inform the user and offer to start fresh.
3. Create (or update) the state file at `.claude/namer-state.json`:

```json
{
  "session_id": "namer-YYYY-MM-DD-HHMM",
  "started_at": "ISO 8601 timestamp",
  "phase": "brief",
  "brief_path": ".claude/namer-briefs/brief-{session_id}.json",
  "iteration": 1
}
```

4. Ensure the directory `.claude/namer-briefs/` exists (create via Read/Glob check if needed).

## Phase 2: Spawn brand-strategist

Delegate the entire interview to the `brand-strategist` agent:

```
Task(brand-strategist, {
  prompt: "Conduct naming brief interview for: ${user_input}",
  context: "fork"
})
```

The `brand-strategist` agent is responsible for:

- Asking structured interview questions about the brand, audience, tone, competitive landscape
- Presenting available naming strategies (from the `naming-strategies` skill)
- Letting the user select or rank preferred strategies
- Saving the completed brief to `.claude/namer-briefs/brief-{session_id}.json`

Do NOT duplicate interview logic here. The orchestrator waits for the agent to complete and return its output.

## Phase 3: Brief Confirmation

After `brand-strategist` completes:

1. Read the saved brief from `.claude/namer-briefs/brief-{session_id}.json`.
2. Present a human-readable summary of the brief to the user via `AskUserQuestion`.
3. Offer the following choices:
   - **Proceed to /namer:run** -- move to name generation immediately
   - **Edit brief** -- re-enter the interview to modify specific answers
   - **Start over** -- discard this brief and begin a new session
   - **Done for now** -- save the brief and exit (can resume later with `--resume`)

## Completion

If the user selects **Proceed to /namer:run**:

```
Skill(claudikins-namer:run)
```

This hands off to the next pipeline step with the current session context.

For all other choices:

- Update `.claude/namer-state.json` with the current status.
- Return the output schema with the appropriate `status` value (`completed`, `paused`, or `aborted`).

## State Management

State file: `.claude/namer-state.json`

```json
{
  "session_id": "namer-YYYY-MM-DD-HHMM",
  "started_at": "ISO 8601 timestamp",
  "phase": "brief",
  "brief_path": ".claude/namer-briefs/brief-{session_id}.json",
  "iteration": 1
}
```

- `phase` tracks where in the pipeline we are (`brief` or `run`).
- `iteration` increments if the user edits and re-confirms the brief.
- This file is the single source of truth for session continuity across `--resume` calls.

## Error Recovery

On any failure (agent crash, malformed output, missing files):

1. Save a checkpoint of whatever state exists to `.claude/namer-state.json`.
2. Present the user with options via `AskUserQuestion`:
   - **Retry** -- re-spawn the `brand-strategist` agent from the last checkpoint
   - **Manual input** -- let the user provide brief data directly as JSON or free text
   - **Abort** -- abandon the session (status: `aborted`)
3. Never silently fail. Always surface the error context to the user.
