---
description: Main orchestrator for ticket resolution workflow - fetch, analyze, plan, implement, simplify, review, PR
argument-hint: <ticket-id> [--auto] [--continue] [--init] [--source youtrack|github] [--skip-workspace] [--skip-simplify] [--skip-review] [--pr] [--draft]
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
- `--source`: Force source (youtrack, github, file)
- `--skip-workspace`: Skip workspace setup (used by resolve-worktree.sh wrapper)
- `--skip-simplify`: Skip code simplification phase
- `--skip-review`: Skip code review phase
- `--pr`: Create pull request after implementation (implied in auto mode)
- `--draft`: Create PR as draft (default: true, use `--no-draft` for ready PR)
- `--target`: Target branch for PR (default: auto-detect)

---

## Mode Determination

| Flag         | Mode        | Description                        |
|--------------|-------------|------------------------------------|
| `--init`     | INIT        | Configure project, then STOP       |
| `--continue` | CONTINUE    | Resume from validated plan         |
| `--auto`     | AUTO        | Complete workflow automatically    |
| (default)    | INTERACTIVE | User validates plan, controls flow |

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

### AUTO MODE (`--auto`)

Execute in order:

1. STEP: WORKSPACE SETUP (unless `--skip-workspace`)
2. STEP: INITIALIZATION
3. STEP: FETCH TICKET
4. STEP: ANALYZE COMPLEXITY
5. STEP: EXPLORATION
6. STEP: CREATE PLAN
7. STEP: PLAN VALIDATION (auto-validate)
8. STEP: IMPLEMENT
9. STEP: SIMPLIFY (unless `--skip-simplify`)
10. STEP: REVIEW (unless `--skip-review`)
11. STEP: FINALIZE (push + PR)

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

## STEP: WORKSPACE SETUP

**AUTO mode only** (skip if `--skip-workspace`)

1. Determine workspace type from config `workspace.prefer_worktree`
2. Generate branch name: `{prefix}/{ticket-id}-{slug}`
3. Create workspace:
   ```bash
   git fetch origin
   git checkout {base-branch}
   git pull origin {base-branch}
   git checkout -b {branch-name}
   ```
4. Update status: `phases.workspace = "completed"`

**Note**: For worktree with directory change, use `resolve-worktree.sh` wrapper.

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

Execute implementation via solo-implement.sh:

```bash
~/.claude/scripts/solo-implement.sh --feature {ticket-id}
```

Update status: `phases.implement = "completed"`, `state = "implementing"`

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

| Aspect          | Interactive      | Auto          |
|-----------------|------------------|---------------|
| Workspace setup | User manages     | Automatic     |
| Plan validation | Interactive loop | Auto-validate |
| After plan      | STOP or continue | Continue      |
| Push/PR         | User manages     | Automatic     |

### Interactive Flow

```
/resolve PROJ-123
  → Fetch → Analyze → Explore → Plan
  → VALIDATION LOOP
    → "Valider et implementer" → /compact → implement → simplify → review → STOP
    → "Valider et arreter" → STOP (--continue later)
```

### Auto Flow

```
/resolve PROJ-123 --auto
  → Workspace → Fetch → Analyze → Explore → Plan (auto-validated)
  → implement → simplify → review → push → PR
```

---

## Configuration Reference

Project config: `.claude/ticket-config.json`

```json
{
  "default_source": "auto",
  "workspace": {
    "prefer_worktree": false,
    "skip_in_interactive": true
  },
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
