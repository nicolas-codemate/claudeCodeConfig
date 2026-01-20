---
description: Main orchestrator for ticket resolution workflow - fetch, analyze, plan, implement, simplify, review, PR
argument-hint: <ticket-id> [--auto] [--continue] [--refine-plan] [--plan-only] [--init] [--source youtrack|github] [--skip-simplify] [--skip-review] [--pr] [--draft]
allowed-tools: Read, Glob, Grep, Bash, Write, Task, AskUserQuestion, mcp__youtrack__get_issue, mcp__youtrack__get_issue_comments, mcp__youtrack__get_issue_attachments
---

# RESOLVE - Ticket Resolution Workflow Orchestrator

Lightweight orchestrator that coordinates the complete ticket resolution workflow by invoking specialized skills.

## Input

```
$ARGUMENTS
```

## Parse Arguments

Extract from arguments:

- `ticket_id`: Required (except with --init) - the ticket identifier (e.g., PROJ-123, #456)
- `--init`: Initialize project configuration (no ticket needed)
- `--auto`: Automatic mode, no questions asked (default: interactive)
- `--continue`: Resume from validated plan (skip to implementation)
- `--refine-plan`: Refine existing plan interactively (challenge, find edge cases)
- `--plan-only`: Stop after plan creation, suggest solo-implement.sh for epics
- `--source`: Force source (youtrack, github, file)
- `--skip-simplify`: Skip code simplification phase
- `--skip-review`: Skip code review phase
- `--pr`: Create pull request after implementation (implied in auto mode)
- `--draft`: Create PR as draft (default: true, use `--no-draft` for ready PR)
- `--target`: Target branch for PR (default: auto-detect)

**Note**: User must create their branch/worktree BEFORE running /resolve. This command does not manage workspace creation.

---

## Mode Determination

| Flag              | Mode        | Description                            |
|-------------------|-------------|----------------------------------------|
| `--init`          | INIT        | Configure project, then STOP           |
| `--continue`      | CONTINUE    | Resume from validated plan             |
| `--refine-plan`   | REFINE      | Load existing plan, interactive loop   |
| `--auto`          | AUTO        | Complete workflow automatically        |
| `--auto --plan-only` | PLAN-ONLY | Stop after plan, suggest solo-implement |
| (default)         | INTERACTIVE | User validates plan, controls flow     |

---

## Workflow Execution

### INIT MODE (`--init`)

Apply skill: `~/.claude/skills/init-project/SKILL.md`

**STOP** after configuration is saved.

---

### CONTINUE MODE (`--continue`)

1. **Verify Status**
    - Read `.claude/feature/{ticket-id}/status.json`
    - If not found: ERROR "No workflow found for {ticket-id}"
    - If `state` is not `plan_validated`: ERROR "Plan not validated"

2. **Load Plan**
    - Verify `.claude/feature/{ticket-id}/plan.md` exists

3. **Display Resume Message**
   ```markdown
   ## Reprise du workflow: {ticket-id}
   Plan valide le {plan_validated_at}.
   Execution de /compact pour vider le contexte...
   ```

4. **Execute Compact**
    - Run `/compact` command

5. **Jump to Implementation**
    - Continue to STEP: IMPLEMENT

---

### REFINE MODE (`--refine-plan`)

Refine an existing plan interactively. Useful after `--auto --plan-only` to challenge the plan, find edge cases, and iterate before implementation.

1. **Verify Plan Exists**
    - Read `.claude/feature/{ticket-id}/plan.md`
    - If not found: ERROR "No plan found for {ticket-id}. Run /resolve first."

2. **Load Context**
    - Read `.claude/feature/{ticket-id}/ticket.md` (if exists)
    - Read `.claude/feature/{ticket-id}/analysis.md` (if exists)
    - Read `.claude/feature/{ticket-id}/status.json`

3. **Display Context Summary**
   ```markdown
   ## Raffinement du plan: {ticket-id}

   ### Contexte
   - Ticket: {ticket summary}
   - Complexite: {complexity level}
   - Plan cree le: {created_at}

   ### Plan actuel
   {display plan content}
   ```

4. **Interactive Refinement Loop**

   Apply skill: `~/.claude/skills/plan-validation/SKILL.md`

   Options:
   - **Poser des questions** → Claude asks clarifying questions about edge cases, missing scenarios
   - **Challenger le plan** → User challenges choices, Claude defends or adapts
   - **Modifier le plan** → Apply specific changes
   - **Regenerer le plan** → Regenerate with new instructions
   - **Valider et arreter** → Mark as validated, STOP
   - **Valider et implementer** → /compact → continue to STEP: IMPLEMENT

5. **Update Status**
   When validated:
   ```json
   {
     "state": "plan_validated",
     "plan_validated_at": "{timestamp}",
     "refined": true
   }
   ```

---

### AUTO MODE (`--auto`)

**Prerequisite**: User must create branch/worktree before running.

Execute in order:

1. STEP: INITIALIZATION
2. STEP: FETCH TICKET
3. STEP: ANALYZE COMPLEXITY
4. STEP: EXPLORATION
5. STEP: CREATE PLAN
6. STEP: PLAN VALIDATION (auto-validate)

**If `--plan-only`**: STOP here and display the plan + next steps:

1. **Display the full plan** from `.claude/feature/{ticket-id}/plan.md`:
   ```markdown
   ## Plan d'implémentation: {ticket-id}

   {full plan content}
   ```

2. **Display next steps**:
   ```markdown
   ---

   ## Prochaines étapes

   Le plan est sauvegardé dans `.claude/feature/{ticket-id}/plan.md`

   **Options**:

   1. **Raffiner le plan** (recommandé pour les epics complexes):
      ```bash
      /resolve {ticket-id} --refine-plan
      ```
      → Challenger le plan, trouver les edge cases, itérer

   2. **Implémenter directement**:
      ```bash
      solo-implement.sh --feature {ticket-id}
      ```
      → Exécute chaque phase dans une session Claude séparée
   ```

**END OF PLAN-ONLY MODE**

7. STEP: IMPLEMENT (execute /compact first, then implement in this session)
8. STEP: SIMPLIFY (unless `--skip-simplify`)
9. STEP: REVIEW (unless `--skip-review`)
10. STEP: FINALIZE (push + PR)

---

### INTERACTIVE MODE (default)

Execute in order:

1. STEP: INITIALIZATION
2. STEP: FETCH TICKET
3. STEP: ANALYZE COMPLEXITY
4. STEP: EXPLORATION
5. STEP: CREATE PLAN
6. STEP: PLAN VALIDATION (interactive loop)
    - If "Valider et arreter" → **STOP**
    - If "Valider et implementer" → /compact → continue
7. STEP: IMPLEMENT
8. STEP: SIMPLIFY (unless `--skip-simplify`)
9. STEP: REVIEW (unless `--skip-review`)
10. **STOP** (user manages push/PR)

---

## STEP: INITIALIZATION

1. **Load Configuration**
   ```bash
   cat .claude/ticket-config.json 2>/dev/null || echo "{}"
   ```
   Merge with defaults from `~/.claude/skills/ticket-workflow/references/default-config.json`

2. **Create Feature Directory**
   ```bash
   mkdir -p .claude/feature/{ticket-id}
   ```

3. **Check for Resume** (INTERACTIVE only)
   If `.claude/feature/{ticket-id}/status.json` exists with incomplete state:
   ```
   AskUserQuestion:
     question: "Un workflow existe deja pour {ticket-id}. Que faire ?"
     header: "Resume"
     options:
       - label: "Reprendre"
       - label: "Recommencer"
       - label: "Annuler"
   ```

4. **Initialize Status**
   Create `.claude/feature/{ticket-id}/status.json` with initial state.

---

## STEP: FETCH TICKET

Apply skill: `~/.claude/skills/fetch-ticket/SKILL.md`

- Detect source from ticket ID pattern
- Retrieve ticket via MCP (YouTrack) or gh CLI (GitHub)
- Save to `.claude/feature/{ticket-id}/ticket.md`
- Update status: `phases.fetch = "completed"`

---

## STEP: ANALYZE COMPLEXITY

Apply skill: `~/.claude/skills/analyze-ticket/SKILL.md`

- Calculate complexity score
- Determine workflow type (simple/standard/full)
- Save to `.claude/feature/{ticket-id}/analysis.md`

**INTERACTIVE**: Ask user to confirm workflow type
**AUTO**: Use detected complexity

Update status: `phases.analyze = "completed"`

---

## STEP: EXPLORATION

Based on workflow type:

| Workflow   | Action                          |
|------------|---------------------------------|
| Simple     | Skip exploration                |
| Standard   | 1 explore agent                 |
| Full (AEP) | Up to 3 parallel explore agents |

Use Task tool with `subagent_type=Explore` for exploration.

Append findings to `analysis.md`.

---

## STEP: CREATE PLAN

1. **Determine Planning Approach**
    - Simple: Basic plan, 1-2 phases
    - Standard: Standard plan, 2-4 phases
    - Full: Apply `~/.claude/skills/architect/SKILL.md` for detailed plan

2. **Generate Plan**
   Create implementation plan with phased steps, validation criteria, risk mitigations.

   **Plan format** - The plan MUST include a YAML frontmatter block:
   ```markdown
   ---
   feature: {ticket-id-slug}
   ticket_id: {ticket-id}
   created: {ISO timestamp}
   status: pending
   total_phases: {N}
   ---

   # {ticket-id}: Implementation Plan - {title}

   ## Overview
   {Brief description}

   ---

   ## Phase 1: {Phase Title}

   **Goal**: {What this phase accomplishes}

   ### Files to modify/create
   - `path/to/file.ext` - Description

   ### Validation
   {Command to validate: make test, phpunit, etc.}

   ### Commit message
   ```
   {conventional commit message}
   ```

   ---

   ## Phase 2: ...
   ```

3. **Save Plan**
   Write to `.claude/feature/{ticket-id}/plan.md`
   Update status: `phases.plan = "completed"`, `state = "planned"`

---

## STEP: PLAN VALIDATION

Apply skill: `~/.claude/skills/plan-validation/SKILL.md`

**AUTO mode**: Auto-validate, continue to implement
**INTERACTIVE mode**: Validation loop with options:

- Valider et implementer → /compact → continue
- Valider et arreter → STOP (resume via --continue)
- Modifier le plan → apply changes, loop
- Regenerer le plan → regenerate, loop

Update status: `state = "plan_validated"`, `plan_validated_at = "{timestamp}"`

---

## STEP: IMPLEMENT

1. **Execute /compact** to clear context before implementation

2. **Read the plan** from `.claude/feature/{ticket-id}/plan.md`

3. **Implement each phase** sequentially:
   - Read phase details (goal, files, validation)
   - Implement the changes
   - Run validation command if specified
   - Commit with the suggested commit message
   - Move to next phase

4. Update status: `phases.implement = "completed"`, `state = "implementing"`

**Note**: For very large epics with many phases, use `--plan-only` flag and run `solo-implement.sh` separately. This launches each phase in its own Claude session with fresh context.

---

## STEP: SIMPLIFY

Skip if `--skip-simplify` or config `simplify.enabled = false`.

1. Detect simplifier agent (auto/symfony/laravel/generic)
2. Get modified files: `git diff --name-only {base-branch}...HEAD`
3. Apply simplifier agent from `~/.claude/agents/{agent}-simplifier.md`

**INTERACTIVE**: Ask before applying changes
**AUTO**: Apply if `simplify.auto_apply = true`

If changes applied:

```bash
git add -A
git commit -m "refactor: simplify code ({agent}-simplifier)"
```

Update status: `phases.simplify = "completed"`

---

## STEP: REVIEW

Skip if `--skip-review` or config `review.enabled = false`.

Apply agent: `~/.claude/agents/code-reviewer.md`

1. Gather context (ticket.md, plan.md, git diff)
2. Execute dual review (functional + technical)
3. Present results

**INTERACTIVE**: Ask how to handle issues
**AUTO**: Auto-fix if `review.auto_fix = true`, block on critical if configured

Update status: `phases.review = "completed"`, `state = "reviewed"`

---

## STEP: FINALIZE

Apply skill: `~/.claude/skills/create-pr/SKILL.md`

1. Push branch: `git push -u origin {branch-name}`
2. Check for existing PR
3. Create PR (draft by default)

**INTERACTIVE**: Ask for PR options (draft/ready, target branch)
**AUTO**: Create draft PR targeting base branch

Update status: `phases.finalize = "completed"`, `state = "finalized"`

---

## Error Handling

| Error                  | Message                               |
|------------------------|---------------------------------------|
| Ticket not found       | Verifiez l'ID et vos permissions      |
| Branch creation failed | La branche existe peut-etre deja      |
| Planning failed        | Le ticket est peut-etre trop vague    |
| Push failed            | Verifiez votre authentification git   |
| PR creation failed     | Verifiez vos droits sur le repository |

---

## Mode Summary

**Prerequisite for all modes**: User creates branch/worktree BEFORE running /resolve.

| Aspect          | Interactive      | Auto          |
|-----------------|------------------|---------------|
| Workspace setup | User manages     | User manages  |
| Plan validation | Interactive loop | Auto-validate |
| After plan      | STOP or continue | Continue      |
| Push/PR         | User manages     | Automatic     |

### Interactive Flow

```bash
git checkout -b feat/PROJ-123
/resolve PROJ-123
  → Fetch → Analyze → Explore → Plan
  → VALIDATION LOOP
    → "Valider et implementer" → /compact → implement → simplify → review → STOP
    → "Valider et arreter" → STOP (--continue later)
```

### Auto Flow

```bash
git checkout -b feat/PROJ-123
/resolve PROJ-123 --auto
  → Fetch → Analyze → Explore → Plan (auto-validated)
  → /compact → implement → simplify → review → push → PR
```

### Epic Flow (--plan-only)

```bash
git checkout -b feat/PROJ-123
/resolve PROJ-123 --auto --plan-only
  → Fetch → Analyze → Explore → Plan (auto-validated)
  → STOP + suggest: solo-implement.sh --feature PROJ-123
```

### Refine Flow (--refine-plan)

```bash
# After --plan-only, review the plan and refine interactively
/resolve PROJ-123 --refine-plan
  → Load plan + context
  → INTERACTIVE REFINEMENT LOOP
    → Poser des questions / Challenger / Modifier / Regenerer
    → "Valider et implementer" → /compact → implement → ...
    → "Valider et arreter" → STOP (--continue later)
```

**Typical Epic Workflow**:
```bash
# 1. Generate plan automatically
/resolve PROJ-123 --auto --plan-only

# 2. Review the plan, think about it...

# 3. Refine interactively (challenge, find edge cases)
/resolve PROJ-123 --refine-plan

# 4. Implement (after "Valider et arreter")
solo-implement.sh --feature PROJ-123
```

---

## Configuration Reference

Project config: `.claude/ticket-config.json`

```json
{
  "default_source": "auto",
  "branches": {
    "default_base": "main",
    "prefix_mapping": {
      "bug": "fix",
      "feature": "feat"
    }
  },
  "complexity": {
    "auto_detect": true,
    "simple_threshold": 2,
    "complex_threshold": 6
  },
  "simplify": {
    "enabled": true,
    "auto_apply": false
  },
  "review": {
    "enabled": true,
    "auto_fix": false,
    "block_on_critical": true
  },
  "pr": {
    "draft_by_default": true
  }
}
```

---

## Language

All user communication in French.
Technical output (git, code) in English.

---

## NOW

Begin workflow for: `$ARGUMENTS`

1. Parse arguments and determine mode
2. Execute appropriate workflow path
3. Apply skills as specified for each step
4. Handle user interactions based on mode
