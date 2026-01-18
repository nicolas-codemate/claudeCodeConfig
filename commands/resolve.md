---
description: Main orchestrator for ticket resolution workflow - fetch, analyze, setup workspace, plan, implement, simplify, PR
argument-hint: <ticket-id> [--auto] [--init] [--source youtrack|github] [--implement] [--skip-simplify] [--pr] [--draft]
allowed-tools: Read, Glob, Grep, Bash, Write, Task, AskUserQuestion, mcp__youtrack__get_issue, mcp__youtrack__get_issue_comments, mcp__youtrack__get_issue_attachments
---

# RESOLVE - Ticket Resolution Workflow Orchestrator

This command orchestrates the complete ticket resolution workflow from fetch to pull request creation.

## Input

```
$ARGUMENTS
```

## Parse Arguments

Extract from arguments:
- `ticket_id`: Required (except with --init) - the ticket identifier (e.g., PROJ-123, #456)
- `--init`: Optional - initialize project configuration (no ticket needed)
- `--auto`: Optional - automatic mode, no questions asked (default: interactive)
- `--source`: Optional - force source (youtrack, github, file)
- `--implement`: Optional - launch solo-implement.sh after planning
- `--skip-simplify`: Optional - skip code simplification phase
- `--pr`: Optional - create pull request after implementation (implied in auto mode)
- `--draft`: Optional - create PR as draft (default: true, use `--no-draft` for ready PR)
- `--target`: Optional - target branch for PR (default: auto-detect)

**Mode determination**:
- If `--init` present → INIT MODE (configure project, then stop)
- If `--auto` present → AUTOMATIC MODE (no questions, use defaults/detection)
  - In AUTO mode: always push and create PR after implementation
- Otherwise → INTERACTIVE MODE (ask user at key decision points)

---

## STEP 0: PROJECT INITIALIZATION (if --init)

If `--init` flag is present, run interactive configuration wizard:

### 0.1 Welcome

```markdown
# Configuration du projet pour /resolve

Ce wizard va creer le fichier `.claude/ticket-config.json` pour configurer
le workflow de resolution de tickets dans ce projet.
```

### 0.2 Source Configuration

```
AskUserQuestion:
  question: "Quelle source de tickets utilisez-vous principalement ?"
  header: "Source"
  options:
    - label: "YouTrack"
      description: "Tickets YouTrack via MCP"
    - label: "GitHub Issues"
      description: "Issues et PRs GitHub via gh CLI"
    - label: "Les deux"
      description: "Detection automatique selon le format"
```

If YouTrack selected or "Les deux":
```
AskUserQuestion:
  question: "Quel est le prefixe de votre projet YouTrack ?"
  header: "YouTrack"
  options:
    - label: "Entrer le prefixe"
      description: "Ex: PROJ, MYAPP, BACK..."
```
→ User enters prefix (e.g., "PROJ")

If GitHub selected or "Les deux":
```
AskUserQuestion:
  question: "Quel est le repository GitHub ?"
  header: "GitHub"
  options:
    - label: "Detecter automatiquement"
      description: "Utiliser 'git remote get-url origin'"
    - label: "Entrer manuellement"
      description: "Format: owner/repo"
```
→ If auto-detect: run `git remote get-url origin` and extract owner/repo
→ If manual: user enters "owner/repo"

### 0.3 Branch Configuration

```
AskUserQuestion:
  question: "Quelle est votre branche principale ?"
  header: "Base branch"
  options:
    - label: "main"
      description: "Convention moderne"
    - label: "master"
      description: "Convention classique"
    - label: "develop"
      description: "Gitflow - branche de dev"
```

```
AskUserQuestion:
  question: "Comment nommer les branches de feature ?"
  header: "Prefixes"
  options:
    - label: "Standard (Recommended)"
      description: "feat/, fix/, refactor/, docs/"
    - label: "Simple"
      description: "feature/, bugfix/"
    - label: "Avec ticket"
      description: "PROJ-123/description"
```

### 0.4 Complexity Defaults

```
AskUserQuestion:
  question: "Comportement par defaut pour la complexite ?"
  header: "Complexite"
  options:
    - label: "Detection automatique (Recommended)"
      description: "Analyser le contenu du ticket"
    - label: "Toujours simple"
      description: "Workflow rapide sans exploration"
    - label: "Toujours complet"
      description: "AEP + Architect systematique"
```

### 0.5 Generate Configuration

Build config object based on answers:

```json
{
  "default_source": "auto|youtrack|github",
  "youtrack": {
    "project_prefix": "PROJ"
  },
  "github": {
    "repo": "owner/repo"
  },
  "branches": {
    "default_base": "main|master|develop",
    "prefix_mapping": {
      "bug": "fix",
      "feature": "feat",
      "task": "feat",
      "refactoring": "refactor",
      "documentation": "docs"
    }
  },
  "complexity": {
    "auto_detect": true|false,
    "default_level": "simple|medium|complex"
  }
}
```

### 0.6 Save Configuration

```bash
mkdir -p .claude
```

Write to `.claude/ticket-config.json`.

### 0.7 Confirm

```markdown
# Configuration sauvegardee

Fichier cree: `.claude/ticket-config.json`

```json
{content of generated config}
```

## Utilisation

```bash
# Resoudre un ticket
/resolve PROJ-123

# Mode automatique
/resolve PROJ-123 --auto

# Modifier la config
/resolve --init
```

Le projet est pret pour utiliser /resolve !
```

**STOP HERE** - Do not continue to ticket workflow.

---

## STEP 1: INITIALIZATION

### 1.1 Load Configuration

Read project config if exists:
```bash
cat .claude/ticket-config.json 2>/dev/null || echo "{}"
```

Merge with defaults from `~/.claude/skills/ticket-workflow/references/default-config.json`.

### 1.2 Create Feature Directory

```bash
mkdir -p .claude/feature/{ticket-id}
```

### 1.3 Check for Resume

If `.claude/feature/{ticket-id}/status.json` exists:
- Read current status
- If incomplete, ask user (in interactive mode):

```
AskUserQuestion:
  question: "Un workflow existe deja pour {ticket-id} (etat: {state}). Que souhaitez-vous faire ?"
  header: "Resume"
  options:
    - label: "Reprendre"
      description: "Continuer depuis la derniere etape ({last_phase})"
    - label: "Recommencer"
      description: "Supprimer et repartir de zero"
    - label: "Annuler"
      description: "Ne rien faire"
```

In auto mode: always resume if possible.

### 1.4 Initialize Status

Create `.claude/feature/{ticket-id}/status.json`:
```json
{
  "ticket_id": "{ticket-id}",
  "started_at": "{ISO timestamp}",
  "mode": "interactive|auto",
  "state": "pending",
  "phases": {
    "fetch": "pending",
    "analyze": "pending",
    "workspace": "pending",
    "plan": "pending",
    "implement": "pending",
    "simplify": "pending",
    "finalize": "pending"
  }
}
```

---

## STEP 2: FETCH TICKET

Read and apply the fetch-ticket skill from `~/.claude/skills/fetch-ticket/SKILL.md`.

### 2.1 Detect Source

If `--source` provided, use it. Otherwise detect:
- Pattern `^[A-Z]+-\d+$` → YouTrack
- Pattern `^#?\d+$` → GitHub
- File path exists → File

### 2.2 Retrieve Ticket

**YouTrack**:
```
mcp__youtrack__get_issue(issueId: {ticket-id})
mcp__youtrack__get_issue_comments(issueId: {ticket-id})
```

**GitHub**:
```bash
gh issue view {number} --json title,body,state,labels,assignees,comments
# If fails, try PR:
gh pr view {number} --json title,body,state,labels,assignees,comments
```

### 2.3 Save Ticket

Write normalized content to `.claude/feature/{ticket-id}/ticket.md`.

Update status: `phases.fetch = "completed"`.

---

## STEP 3: ANALYZE COMPLEXITY

Read and apply the analyze-ticket skill from `~/.claude/skills/analyze-ticket/SKILL.md`.

### 3.1 Calculate Complexity Score

Analyze ticket content:
- Apply scoring factors
- Check for forcing labels
- Determine suggested level: SIMPLE, MEDIUM, or COMPLEX

### 3.2 Save Initial Analysis

Write analysis to `.claude/feature/{ticket-id}/analysis.md`.

### 3.3 INTERACTIVE: Confirm Workflow

**In INTERACTIVE mode**, present analysis and ask:

```
Display ticket summary:
- Title: {title}
- Type: {type}
- Priority: {priority}
- Suggested complexity: {level} (score: {score})

AskUserQuestion:
  question: "Quel type de workflow souhaitez-vous utiliser ?"
  header: "Workflow"
  options:
    - label: "Simple (Recommended)" if score <= 2
      description: "Plan direct sans exploration - ideal pour les quick fixes"
    - label: "Standard"
      description: "Exploration legere + plan structure"
    - label: "Complet (AEP)"
      description: "Exploration approfondie + Architect - pour les features complexes"
    - label: "Custom"
      description: "Choisir les options manuellement"
```

If "Custom" selected, ask additional questions:

```
AskUserQuestion:
  question: "Quelles phases activer ?"
  header: "Phases"
  multiSelect: true
  options:
    - label: "Exploration"
      description: "Rechercher du code similaire et analyser l'impact"
    - label: "AEP complet"
      description: "3 agents d'exploration en parallele"
    - label: "Architect"
      description: "Utiliser le skill Architect pour le plan"
```

**In AUTO mode**: use detected complexity without asking.

Update status with confirmed settings:
- `complexity = "{level}"`
- `workflow_type = "simple|standard|full"`
- `phases.analyze = "completed"`

---

## STEP 4: EXPLORATION (based on workflow)

### Simple Workflow
Skip exploration. Proceed to workspace setup.
Mark `phases.explore = "skipped"`.

### Standard Workflow
Launch 1 explore agent (Task tool with subagent_type=Explore):
- Find similar existing code
- Identify files to modify

Append findings to `analysis.md`.

### Full (AEP) Workflow
Launch up to 3 explore agents IN PARALLEL:

**Agent 1: Implementation Patterns**
- Search for similar features
- Find reusable patterns

**Agent 2: Impact Analysis**
- Trace dependencies
- Identify affected components

**Agent 3: Test Coverage**
- Find related tests
- Check testing patterns

Append all findings to `analysis.md`.

---

## STEP 5: SETUP WORKSPACE

### 5.1 Gather Branch Information

Determine defaults:
- Base branch: config `branches.default_base` or `main`
- Branch prefix: from ticket type via `branches.prefix_mapping`
- Branch name: `{prefix}/{ticket-id}-{slug}`

### 5.2 INTERACTIVE: Confirm Branch Settings

**In INTERACTIVE mode**, ask:

```
AskUserQuestion:
  question: "Quelle branche de base utiliser ?"
  header: "Base branch"
  options:
    - label: "main (Recommended)" if default is main
      description: "Branche principale"
    - label: "develop"
      description: "Branche de developpement"
    - label: "Branche courante ({current})"
      description: "Rester sur {current_branch}"
```

Then confirm branch name:

```
AskUserQuestion:
  question: "Nom de la branche a creer ?"
  header: "Branche"
  options:
    - label: "{prefix}/{ticket-id}-{slug} (Recommended)"
      description: "Nom genere automatiquement"
    - label: "{prefix}/{ticket-id}"
      description: "Sans le slug (plus court)"
    - label: "Personnaliser"
      description: "Entrer un nom custom"
```

**In AUTO mode**: use generated name without asking.

### 5.3 Create Branch

```bash
git fetch origin
git checkout {base-branch}
git pull origin {base-branch}
git checkout -b {branch-name}
```

### 5.4 Record Workspace

Update status:
```json
{
  "workspace": {
    "type": "branch",
    "name": "{branch-name}",
    "base": "{base-branch}"
  },
  "phases.workspace": "completed"
}
```

---

## STEP 6: CREATE PLAN

### 6.1 Determine Planning Approach

Based on confirmed workflow:

| Workflow | AEP | Architect | Plan Detail |
|----------|-----|-----------|-------------|
| Simple | No | No | Basic, 1-2 phases |
| Standard | Partial | No | Standard, 2-4 phases |
| Full | Full | Yes | Detailed, 3+ phases |

### 6.2 Apply Architect Skill (if Full workflow)

Read `~/.claude/skills/architect/SKILL.md` and apply:
- Phase design checklists
- Risk ordering principles
- Atomic phase rules

### 6.3 Generate Plan

Create implementation plan with:
- Context from ticket
- Findings from exploration
- Phased implementation steps
- Validation criteria
- Risk mitigations

### 6.4 Save Plan

Write to `.claude/feature/{ticket-id}/plan.md` with format:

```markdown
---
feature: {slug}
ticket_id: {ticket-id}
created: {ISO timestamp}
status: pending
complexity: {level}
total_phases: {N}
---

# Implementation Plan: {Ticket Title}

## Summary

{Brief description}

## Context

{What was learned from ticket and exploration}

## Phase 1: {Phase Name}

**Goal**: {What this phase achieves}

**Files**:
- `path/to/file.ext` - {Description}

**Validation**: {Command or check}

**Commit message**: `type: description`

## Phase 2: ...

...

## Risks & Mitigations

- {Risk}: {Mitigation}

## Post-Implementation

- [ ] Run full test suite
- [ ] Update documentation
- [ ] Create PR
```

Update status: `phases.plan = "completed"`, `state = "planned"`.

---

## STEP 7: FINAL CONFIRMATION

### 7.1 Display Summary

```markdown
# Workflow Termine

## Ticket
- **ID**: {ticket-id}
- **Titre**: {title}
- **Source**: {source}

## Analyse
- **Complexite**: {level}
- **Workflow**: {workflow_type}
- **Exploration**: {exploration_status}

## Workspace
- **Branche**: {branch-name}
- **Base**: {base-branch}

## Plan
- **Phases**: {N}
- **Fichier**: .claude/feature/{ticket-id}/plan.md
```

### 7.2 INTERACTIVE: Choose Next Step

**In INTERACTIVE mode**, ask:

```
AskUserQuestion:
  question: "Que souhaitez-vous faire maintenant ?"
  header: "Action"
  options:
    - label: "Voir le plan"
      description: "Afficher le plan complet pour review"
    - label: "Lancer l'implementation"
      description: "Executer solo-implement.sh automatiquement"
    - label: "Implementation + PR"
      description: "Implementer puis creer une pull request"
    - label: "Terminer"
      description: "Arreter ici, implementer plus tard"
```

If "Voir le plan": display full plan content, then ask again.
If "Lancer l'implementation": proceed to step 8, skip step 9.
If "Implementation + PR": proceed to step 8, then step 9.
If "Terminer": show manual implementation command.

**In AUTO mode**: always proceed to step 8, then step 9 (push + PR).

---

## STEP 8: IMPLEMENT (if requested)

If implementation requested:

```bash
~/.claude/scripts/solo-implement.sh --feature {ticket-id}
```

Update status: `phases.implement = "completed"`, `state = "implementing"`.

Otherwise, inform user:

```
Pour lancer l'implementation plus tard:

  solo-implement.sh --feature {ticket-id}

Options disponibles:
  --dry-run      Preview sans execution
  --phase N      Executer une seule phase
  --start N      Reprendre depuis la phase N
  --verbose      Mode debug
```

---

## STEP 9: SIMPLIFY CODE

Apply code simplification to recently modified files.

### 9.1 Check if Enabled

Skip if:
- `--skip-simplify` flag provided
- Config `simplify.enabled = false`
- No files were modified during implementation

### 9.2 Detect Simplifier Agent

**If config `simplify.agent = "auto"`**, detect project type:

```bash
# Check for Symfony
if [ -f "composer.json" ] && grep -q "symfony/framework-bundle" composer.json; then
    AGENT="symfony"
# Check for Laravel
elif [ -f "composer.json" ] && grep -q "laravel/framework" composer.json; then
    AGENT="laravel"
# Default to generic
else
    AGENT="generic"
fi
```

**Agent paths**:
- `symfony` → `~/.claude/agents/symfony-simplifier.md`
- `laravel` → `~/.claude/agents/laravel-simplifier.md` (if exists)
- `generic` → `~/.claude/agents/code-simplifier.md`

### 9.3 Identify Modified Files

```bash
# Get files modified in this feature branch
git diff --name-only {base-branch}...HEAD
```

Filter by scope (config `simplify.scope`):
- `modified`: All files changed in branch
- `phase`: Only files from last implementation phase
- `all`: Entire codebase (use with caution)

### 9.4 INTERACTIVE: Confirm Simplification

**In INTERACTIVE mode**, ask:

```
AskUserQuestion:
  question: "Lancer la simplification du code ?"
  header: "Simplify"
  options:
    - label: "Oui (Recommended)"
      description: "Analyser et simplifier les fichiers modifies avec {agent}-simplifier"
    - label: "Non, passer"
      description: "Aller directement a la creation de PR"
```

**In AUTO mode**:
- If `simplify.auto_apply = true`: apply automatically
- Otherwise: suggest changes but don't apply without confirmation

### 9.5 Run Simplification

Load the appropriate agent and run against modified files:

```markdown
Read agent from: ~/.claude/agents/{agent}-simplifier.md

Apply to files:
- {list of modified files}

Scope: {scope from config}
```

The agent will:
1. Analyze each file against best practices
2. Suggest improvements
3. Apply changes (if auto_apply or confirmed)
4. Report changes made

### 9.6 Review Changes

**In INTERACTIVE mode**, after simplification:

```
AskUserQuestion:
  question: "Des simplifications ont ete appliquees. Que faire ?"
  header: "Review"
  options:
    - label: "Accepter et continuer"
      description: "Garder les modifications et creer la PR"
    - label: "Voir les changements"
      description: "Afficher le diff des simplifications"
    - label: "Annuler"
      description: "Revert les simplifications"
```

### 9.7 Commit Simplifications

If changes were applied:

```bash
git add -A
git commit -m "refactor: simplify code ({agent}-simplifier)"
```

Update status: `phases.simplify = "completed"`.

---

## STEP 10: FINALIZE (push + PR)

Read and apply the create-pr skill from `~/.claude/skills/create-pr/SKILL.md`.

### 10.1 Pre-flight Checks

```bash
# Verify on feature branch
CURRENT_BRANCH=$(git branch --show-current)

# Check for uncommitted changes
git status --porcelain
```

### 10.2 Push Branch

```bash
git push -u origin {branch-name}
```

### 10.3 Check Existing PR

```bash
# Check if PR already exists
gh pr view {branch-name} --json number,url 2>/dev/null
```

If PR exists: display URL and skip creation.

### 10.4 INTERACTIVE: PR Options

**In INTERACTIVE mode**, ask:

```
AskUserQuestion:
  question: "Creer la pull request ?"
  header: "PR"
  options:
    - label: "Oui, en draft (Recommended)"
      description: "PR brouillon, a finaliser apres review"
    - label: "Oui, ready for review"
      description: "PR prete pour review immediate"
    - label: "Non, push seulement"
      description: "Branche poussee, pas de PR"
```

If target branch is ambiguous:

```
AskUserQuestion:
  question: "Quelle branche cible pour la PR ?"
  header: "Target"
  options:
    - label: "{base-branch} (Recommended)"
      description: "Branche utilisee pour creer la feature"
    - label: "main"
      description: "Branche principale"
    - label: "develop"
      description: "Branche de developpement"
```

**In AUTO mode**: create draft PR targeting `{base-branch}` from workspace setup.

### 10.5 Generate PR Content

**Title**: `{type}: {ticket_title} ({ticket_id})`

Example: `feat: Add CSV export for users (PROJ-123)`

**Body**:
```markdown
## Summary

{Brief description from ticket}

## Ticket

- **ID**: {ticket_id}
- **Source**: {source}
- **Link**: {ticket_url if available}

## Changes

{List of phases implemented}

## Test Plan

{Validation steps from plan}
```

### 10.6 Create PR

```bash
gh pr create \
    --title "{title}" \
    --body "{body}" \
    --base "{target-branch}" \
    --draft  # if draft mode
```

### 10.7 Update Status

```json
{
  "state": "finalized",
  "phases": {
    "finalize": "completed"
  },
  "pr": {
    "number": 123,
    "url": "https://github.com/owner/repo/pull/123",
    "draft": true,
    "target": "main"
  }
}
```

### 10.8 Display Result

```markdown
## Pull Request Creee

- **PR**: #{number}
- **URL**: {url}
- **Status**: Draft | Ready for review
- **Target**: {target-branch}

### Prochaines etapes
1. Reviewer les changements
2. Demander des reviews
3. Marquer ready si draft
4. Merger apres approbation
```

---

## ERROR HANDLING

### Ticket Not Found
```
Erreur: Impossible de recuperer le ticket {ticket-id}
- Verifiez l'ID du ticket
- Verifiez vos permissions d'acces
- YouTrack: Assurez-vous que le serveur MCP est configure
- GitHub: Lancez 'gh auth login' si necessaire
```

### Branch Creation Failed
```
Erreur: Impossible de creer la branche {branch-name}
- La branche existe peut-etre deja
- Verifiez git status pour les conflits
- Assurez-vous d'avoir les droits d'ecriture
```

### Planning Failed
```
Erreur: Impossible de generer le plan d'implementation
- Le ticket est peut-etre trop vague
- Ajoutez plus de contexte au ticket
- Essayez le workflow "Simple"
```

### Push Failed
```
Erreur: Impossible de pousser la branche {branch-name}
- Verifiez votre authentification git
- Pour HTTPS: gh auth login
- Pour SSH: ssh-add ~/.ssh/id_rsa
- Verifiez les permissions sur le repository
```

### PR Creation Failed
```
Erreur: Impossible de creer la pull request
- Verifiez vos droits sur le repository
- Tentez: gh auth refresh
- Verifiez que la branche cible existe
```

---

## MODE SUMMARY

| Aspect | Interactive (default) | Auto (--auto) |
|--------|----------------------|---------------|
| Resume | Demande confirmation | Reprend auto |
| Workflow | Choix utilisateur | Detection auto |
| Base branch | Choix utilisateur | Config/default |
| Branch name | Confirmation | Generation auto |
| Implementation | Choix utilisateur | Selon --implement |
| Simplification | Choix utilisateur | Si `simplify.auto_apply` |
| Push | Choix utilisateur | Toujours |
| PR creation | Choix utilisateur | Toujours (draft) |
| Draft mode | Choix utilisateur | Config `pr.draft_by_default` |

---

## CONFIGURATION REFERENCE

Project config in `.claude/ticket-config.json`:
```json
{
  "default_source": "auto",
  "branches": {
    "default_base": "main",
    "prefix_mapping": {"bug": "fix", "feature": "feat"}
  },
  "complexity": {
    "simple_labels": ["quick-fix"],
    "complex_labels": ["architecture"]
  },
  "pr": {
    "draft_by_default": true,
    "default_target": null,
    "include_ticket_link": true,
    "title_format": "{type}: {title} ({ticket_id})"
  },
  "simplify": {
    "enabled": true,
    "agent": "auto",
    "scope": "modified",
    "auto_apply": false
  }
}
```

---

## LANGUAGE

All user communication in French.
Technical output (git, code) in English.

---

## NOW

Begin workflow for: `$ARGUMENTS`

1. Parse ticket ID and detect mode (interactive by default, auto if --auto)
2. Load configuration
3. Execute phases with appropriate prompts based on mode
4. Guide user through decisions or make automatic choices
