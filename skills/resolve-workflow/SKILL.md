---
name: resolve-workflow
description: Modular ticket resolution workflow orchestrator. Loads steps dynamically based on mode and current state.
---

# Resolve - Modular Workflow Orchestrator

<context>
This skill orchestrates the complete ticket resolution workflow by loading and executing
individual step files. Each step is a separate file containing focused instructions,
loaded only when needed to minimize context usage.
</context>

## Input

Arguments passed from command: `$ARGUMENTS`

## Step 1: Parse Arguments

<instructions>
Extract from arguments:
- `ticket_id`: Optional (see Step 1.5 for resolution)
- Flags: `--init`, `--auto`, `--continue`, `--refine-plan`, `--plan-only`
- Options: `--source`, `--target`, `--skip-simplify`, `--skip-review`, `--skip-visual-verify`, `--pr`, `--draft`
</instructions>

## Step 1.5: Resolve Ticket ID (if not provided)

<ticket_resolution>
If `ticket_id` is NOT provided in arguments (and NOT `--init` mode):

### 1. List existing feature directories

```bash
ls -1 .claude/feature/ 2>/dev/null || echo ""
```

### 2. Handle based on mode and results

| Mode | 0 tickets | 1 ticket | Multiple tickets |
|------|-----------|----------|------------------|
| **AUTO** | ERROR: "Aucun ticket en cours. Specifiez un ticket-id." | Use that ticket automatically | ERROR: "Plusieurs tickets en cours: {list}. Specifiez le ticket-id." |
| **INTERACTIVE** | Prompt for ticket ID | Ask to confirm or enter different | Ask user to choose from list |

### 3. INTERACTIVE - No tickets found

```yaml
AskUserQuestion:
  question: "Aucun ticket en cours. Quel ticket voulez-vous traiter ?"
  header: "Ticket"
  options:
    - label: "Saisir le ticket ID"
      description: "Entrer manuellement le numero de ticket"
```

### 4. INTERACTIVE - One ticket found

```yaml
AskUserQuestion:
  question: "Ticket en cours detecte: {ticket-id}. Continuer avec celui-ci ?"
  header: "Ticket"
  options:
    - label: "Oui, continuer avec {ticket-id}"
      description: "Reprendre le workflow existant"
    - label: "Non, autre ticket"
      description: "Saisir un autre ticket ID"
```

### 5. INTERACTIVE - Multiple tickets found

```yaml
AskUserQuestion:
  question: "Plusieurs tickets en cours. Lequel traiter ?"
  header: "Ticket"
  options:
    - label: "{ticket-1}"
      description: "State: {state from status.json}"
    - label: "{ticket-2}"
      description: "State: {state from status.json}"
    # ... up to 4 options, then "Autre" for more
```

</ticket_resolution>

## Step 2: Determine Mode

<mode_detection>
| Flag              | Mode        | Starting Step            |
|-------------------|-------------|--------------------------|
| `--init`          | INIT        | 00-initialization (config only) |
| `--continue`      | CONTINUE    | 06-implement             |
| `--refine-plan`   | REFINE      | 05-plan-validation       |
| `--auto`          | AUTO        | 00-initialization        |
| (default)         | INTERACTIVE | 00-initialization        |
</mode_detection>

## Step 3: Load Current Step

<workflow>
1. Check mode to determine starting point
2. If CONTINUE or REFINE:
   - Read status from `.claude/feature/{ticket-id}/status.json` (where ticket-id comes from arguments)
   - Verify status.json exists and is valid (ERROR if not found)
   - Load ticket context and plan from `.claude/feature/{ticket-id}/`
3. Read step file: `~/.claude/skills/resolve-workflow/steps/{step-number}-{step-name}.md`
4. Execute step instructions
5. Read step frontmatter for `next` directive
6. Continue to next step or STOP
</workflow>

<critical_paths>
**IMPORTANT - Feature directory structure:**
All workflow files are stored in `.claude/feature/{ticket-id}/`:
- `status.json` - Workflow state and options
- `ticket.md` - Ticket content
- `plan.md` - Implementation plan

**NEVER** use `docs/` for workflow files. Always use `.claude/feature/{ticket-id}/`.
</critical_paths>

<base_branch_rule>
**CRITICAL - Base Branch Usage:**

All git diff operations MUST use the base branch from `status.json`:

```bash
# Read base branch from status
BASE_BRANCH=$(cat .claude/feature/{ticket-id}/status.json | jq -r '.options.base_branch')

# Use it in all diff operations
git diff ${BASE_BRANCH}...HEAD
git diff --name-only ${BASE_BRANCH}...HEAD
```

**NEVER** hardcode `main`, `master`, or `develop` in git diff commands.
**NEVER** use `HEAD~1` to detect changes - always compare against base branch.

**Base Branch Lifecycle:**
1. **Step 00 (initialization)**: Initial detection (may default to `main`)
2. **Step 01 (fetch-ticket)**: **MUST UPDATE** base_branch from ticket's milestone/target
   - YouTrack: Extract from "Milestone" field (e.g., "2025-12-continue" → branch "2025-12")
   - GitHub: Extract from milestone or base branch if PR
3. **Steps 02+**: Use updated base_branch from status.json

The **ticket's milestone takes precedence** over default detection.
</base_branch_rule>

## Step Execution Flow

<step_flow>
### Standard Flow (INTERACTIVE/AUTO)
```
00-initialization → 01-fetch-ticket → 02-analyze-complexity → 03-exploration
→ 04-create-plan → 05-plan-validation → 06-implement → 07-simplify
→ 08-review → 09-finalize
```

### CONTINUE Flow
```
(verify status) → 06-implement → 07-simplify → 08-review → 09-finalize
```

### REFINE Flow
```
(load context) → 05-plan-validation (refine loop) → 06-implement → ...
```

### INIT Flow
```
00-initialization (config only) → STOP
```

### PLAN-ONLY Flow
```
00-initialization → ... → 05-plan-validation → STOP (display plan + next steps)
```
</step_flow>

## Mode Reference

See `~/.claude/skills/resolve-workflow/references/modes.md` for detailed mode behaviors.

## Step Files

| Step | File | Description |
|------|------|-------------|
| 00 | `steps/00-initialization.md` | Setup, config loading, feature directory |
| 01 | `steps/01-fetch-ticket.md` | Retrieve ticket, extract Figma URLs, user context |
| 02 | `steps/02-analyze-complexity.md` | Score complexity, determine workflow type |
| 03 | `steps/03-exploration.md` | Explore codebase based on complexity |
| 04 | `steps/04-create-plan.md` | Generate implementation plan |
| 05 | `steps/05-plan-validation.md` | Validate/refine plan interactively |
| 06 | `steps/06-implement.md` | Execute plan, visual verification |
| 07 | `steps/07-simplify.md` | Code simplification pass |
| 08 | `steps/08-review.md` | Code review |
| 09 | `steps/09-finalize.md` | Push and create PR |

## Error Handling

<constraints>
- If step file not found: ERROR with clear message
- If status.json invalid for CONTINUE: ERROR "Plan not validated"
- If ticket not found: ERROR with troubleshooting hints
- Always update status.json after each step completion
</constraints>

## Language

All user communication in French.
Technical output (git, code, files) in English.

## NOW

<instructions>
1. Parse the arguments provided
2. Determine the execution mode
3. Load and execute the appropriate starting step
4. Follow the step's `next` directive until STOP or completion
</instructions>

Begin workflow for: `$ARGUMENTS`
