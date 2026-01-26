---
name: initialization
description: Setup initial configuration, create feature directory, check for resume
order: 0

skip_if:
  - flag: "--continue"
  - flag: "--refine-plan"

next:
  default: fetch-ticket
  conditions:
    - if: "mode == 'INIT'"
      then: STOP

tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
---

# Step: Initialization

<context>
This step initializes the workflow by loading configuration, creating the feature
directory, and handling resume scenarios. For INIT mode, it only configures the
project and stops.
</context>

## Instructions

<instructions>

### 1. Load Configuration

```bash
cat .claude/ticket-config.json 2>/dev/null || echo "{}"
```

Merge with defaults from `~/.claude/skills/ticket-workflow/references/default-config.json`

### 2. Handle INIT Mode

If `--init` flag is present:
- Apply skill: `~/.claude/skills/init-project/SKILL.md`
- **STOP** after configuration is saved

### 3. Create Feature Directory

```bash
mkdir -p .claude/feature/{ticket-id}
```

### 4. Check for Resume (INTERACTIVE only)

If `.claude/feature/{ticket-id}/status.json` exists with incomplete state:

```yaml
AskUserQuestion:
  question: "Un workflow existe deja pour {ticket-id}. Que faire ?"
  header: "Resume"
  options:
    - label: "Reprendre"
      description: "Continuer le workflow existant"
    - label: "Recommencer"
      description: "Supprimer et recommencer de zero"
    - label: "Annuler"
      description: "Arreter sans rien faire"
```

### 5. Detect Base Branch

**CRITICAL**: The base branch MUST be determined and stored for all git diff operations.

Detection order:
1. `--target` flag if provided → use it
2. Project config `.claude/ticket-config.json` → `branches.default_base`
3. Auto-detect from git:
   ```bash
   git rev-parse --abbrev-ref HEAD@{upstream} 2>/dev/null | sed 's|origin/||' || \
   git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || \
   echo ""
   ```
4. If still empty in INTERACTIVE mode, ask user:
   ```yaml
   AskUserQuestion:
     question: "Quelle est la branche cible (base) pour ce ticket ?"
     header: "Base"
     options:
       - label: "develop"
         description: "Branche develop"
       - label: "main"
         description: "Branche main"
       - label: "master"
         description: "Branche master"
   ```
5. If still empty in AUTO mode: ERROR "Cannot determine base branch. Use --target."

### 6. Initialize Status

Create or update `.claude/feature/{ticket-id}/status.json`:

```json
{
  "ticket_id": "{ticket-id}",
  "mode": "{mode}",
  "state": "initialized",
  "started_at": "{ISO timestamp}",
  "phases": {
    "initialization": "completed"
  },
  "options": {
    "auto": false,
    "skip_simplify": false,
    "skip_review": false,
    "skip_visual_verify": false,
    "plan_only": false,
    "base_branch": "{detected or provided base branch - REQUIRED}"
  }
}
```

</instructions>

## Output

<output>
- Directory: `.claude/feature/{ticket-id}/`
- File: `.claude/feature/{ticket-id}/status.json`
- Status: `phases.initialization = "completed"`
</output>

## Auto Behavior

<auto_behavior>
- Skip resume prompt, always start fresh
- Create status with `options.auto = true`
</auto_behavior>

## Interactive Behavior

<interactive_behavior>
- Prompt for resume if previous workflow exists
- Allow cancellation
</interactive_behavior>
