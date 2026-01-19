---
description: Perform code review on current branch changes
argument-hint: [--ticket <id>] [--base <branch>] [--fix] [--severity <level>]
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion, Task
---

# CODE REVIEW COMMAND

Perform comprehensive code review on current branch changes.

## Input

```
$ARGUMENTS
```

## Arguments

- `--ticket <id>`: Ticket ID for context (loads ticket.md/plan.md)
- `--base <branch>`: Base branch for diff (default: main)
- `--fix`: Apply suggested fixes interactively
- `--severity <level>`: Minimum severity to report (critical|important|minor, default: important)

## Process

### Step 1: Parse Arguments

Extract from arguments:
- `ticket_id`: Optional - for loading ticket context
- `base_branch`: Default "main" or from config `branches.default_base`
- `fix_mode`: Boolean, whether to apply fixes
- `severity_threshold`: critical|important|minor

### Step 2: Determine Context

**If `--ticket` provided**:
```bash
# Check for ticket context
ls -la .claude/feature/{ticket-id}/
```
- Load `.claude/feature/{ticket}/ticket.md` (ticket requirements)
- Load `.claude/feature/{ticket}/plan.md` (implementation plan)
- Load `.claude/feature/{ticket}/status.json` (get base branch from workspace.base)

**If no ticket**:
- Use current changes without ticket context
- Review will focus on code quality only (no functional validation)

### Step 3: Determine Base Branch

Priority:
1. `--base` argument if provided
2. `status.json` workspace.base if ticket context
3. Config `branches.default_base`
4. Fallback to "main"

### Step 4: Get Changes

```bash
# Files changed in this branch
git diff {base-branch}...HEAD --name-only

# Full diff for review
git diff {base-branch}...HEAD

# Stats for summary
git diff {base-branch}...HEAD --stat
```

### Step 5: Load Review Agent

Read and apply agent from `~/.claude/agents/code-reviewer.md`.

### Step 6: Execute Review

**With ticket context**:
1. Functional completeness check (all ticket requirements met?)
2. Code quality analysis (naming, SOLID, YAGNI, KISS)
3. Maintainability and extensibility assessment
4. Codebase consistency check

**Without ticket context**:
1. Code quality analysis only
2. Maintainability assessment
3. Codebase consistency check

### Step 7: Present Results

Display review summary:

```markdown
## Code Review Results

### Summary
- **Branch**: {current-branch} -> {base-branch}
- **Files reviewed**: {count}
- **Lines changed**: +{additions} -{deletions}
- **Issues found**: {count} ({critical} critical, {important} important, {minor} minor)
- **Status**: APPROVED | NEEDS_CHANGES | BLOCKED

### Issues by Severity
[Filtered by --severity threshold]
```

### Step 8: Handle Fixes (if --fix)

For each important+ issue:

```
AskUserQuestion:
  question: "Appliquer cette correction ?"
  header: "Fix"
  options:
    - label: "Oui"
      description: "Appliquer la correction suggeree"
    - label: "Non"
      description: "Garder le code actuel"
    - label: "Modifier"
      description: "Proposer une alternative"
```

If "Oui": Apply suggested fix using Edit tool.
If "Non": Skip this issue.
If "Modifier": Ask for alternative and apply.

After all fixes applied:
```bash
git diff --stat  # Show what changed
```

### Step 9: Save Report (if ticket context)

Write report to `.claude/feature/{ticket-id}/review.md`.

## Output Format

### Console Output

```markdown
# Code Review: {branch-name}

## Summary
- Status: NEEDS_CHANGES
- Files: 5 reviewed
- Issues: 2 critical, 3 important, 1 minor

## Critical Issues (2)
[Details...]

## Important Issues (3)
[Details...]

## Minor Suggestions (1)
[Details...]

---
Report saved to: .claude/feature/{ticket-id}/review.md
```

## Examples

### Review without ticket context
```bash
/review-code --base main
```
Reviews all changes on current branch vs main.

### Review with ticket context
```bash
/review-code --ticket PROJ-123
```
Reviews changes with full functional validation against ticket requirements.

### Review and fix issues
```bash
/review-code --ticket PROJ-123 --fix
```
Reviews and interactively applies suggested fixes.

### Review only critical issues
```bash
/review-code --severity critical
```
Only reports critical issues that must be fixed.

## Error Handling

### No Changes Found
```
Aucun changement trouve entre {base-branch} et HEAD.
Verifiez que vous etes sur la bonne branche.
```

### Ticket Context Not Found
```
Contexte ticket non trouve: .claude/feature/{ticket-id}/
Continuer sans contexte ticket ? [O/n]
```

### Agent Not Found
```
Erreur: Agent de review non trouve: ~/.claude/agents/code-reviewer.md
Assurez-vous que l'agent est installe.
```

## Language

All user communication in French.
Technical output (git, code) in English.

## NOW

Begin review for: `$ARGUMENTS`
