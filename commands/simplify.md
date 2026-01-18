---
description: Simplify and refine code using the appropriate simplifier agent (auto-detected or specified)
argument-hint: [--agent generic|symfony|laravel] [--scope modified|all] [--file <path>]
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion
---

# SIMPLIFY - Code Simplification Command

This command applies code simplification using the appropriate simplifier agent.

## Input

```
$ARGUMENTS
```

## Parse Arguments

Extract from arguments:
- `--agent`: Optional - force specific agent (generic, symfony, laravel)
- `--scope`: Optional - scope of simplification (modified, all, default: modified)
- `--file`: Optional - simplify specific file(s) only
- `--dry-run`: Optional - show suggestions without applying

---

## STEP 1: DETECT PROJECT TYPE

If `--agent` not provided, auto-detect:

```bash
# Check for Symfony
if [ -f "composer.json" ] && grep -q "symfony/framework-bundle" composer.json; then
    AGENT="symfony"
# Check for Laravel
elif [ -f "composer.json" ] && grep -q "laravel/framework" composer.json; then
    AGENT="laravel"
# Check for Node/TypeScript
elif [ -f "package.json" ]; then
    AGENT="generic"
# Default
else
    AGENT="generic"
fi
```

Display detected agent:
```
Agent detecte: {agent}-simplifier
```

---

## STEP 2: IDENTIFY FILES TO SIMPLIFY

### If `--file` provided:
Use specified file(s).

### If `--scope modified`:
```bash
# Files modified but not committed
git diff --name-only

# If no uncommitted changes, use files modified in current branch
git diff --name-only $(git merge-base HEAD main)...HEAD
```

### If `--scope all`:
```
AskUserQuestion:
  question: "Simplifier tout le codebase peut prendre du temps. Continuer ?"
  header: "Scope"
  options:
    - label: "Oui, tout simplifier"
      description: "Analyser tous les fichiers du projet"
    - label: "Non, seulement les modifies"
      description: "Limiter aux fichiers modifies"
```

Filter files by extension based on agent:
- `symfony/laravel`: `*.php`
- `generic`: `*.js`, `*.ts`, `*.jsx`, `*.tsx`, `*.py`, `*.go`, etc.

---

## STEP 3: LOAD AGENT

Agent paths:
- `symfony` → `~/.claude/agents/symfony-simplifier.md`
- `laravel` → `~/.claude/agents/laravel-simplifier.md`
- `generic` → `~/.claude/agents/code-simplifier.md`

```bash
cat ~/.claude/agents/{agent}-simplifier.md
```

Read and apply the agent's instructions.

---

## STEP 4: ANALYZE FILES

For each file:

1. Read file content
2. Apply agent's analysis rules
3. Identify improvement opportunities:
   - Code clarity
   - Naming conventions
   - Pattern compliance
   - Redundancy removal
   - Early returns
   - Type annotations

---

## STEP 5: PRESENT SUGGESTIONS

### If `--dry-run`:

```markdown
## Suggestions pour {filename}

### 1. {Category}
**Ligne {line}**: {description}

Avant:
```{lang}
{old_code}
```

Apres:
```{lang}
{new_code}
```

### 2. ...
```

### If not dry-run:

```
AskUserQuestion:
  question: "Appliquer les {N} simplifications trouvees ?"
  header: "Apply"
  options:
    - label: "Oui, tout appliquer"
      description: "Appliquer toutes les modifications"
    - label: "Revoir une par une"
      description: "Valider chaque modification individuellement"
    - label: "Annuler"
      description: "Ne rien modifier"
```

---

## STEP 6: APPLY CHANGES

### If "Tout appliquer":
Apply all modifications to files.

### If "Revoir une par une":
For each suggestion:

```
AskUserQuestion:
  question: "{description}"
  header: "Change"
  options:
    - label: "Appliquer"
      description: "Modifier le code"
    - label: "Ignorer"
      description: "Garder le code actuel"
```

---

## STEP 7: SUMMARY

```markdown
## Simplification terminee

### Fichiers modifies
- `{file1}` - {N} changements
- `{file2}` - {N} changements

### Types de modifications
- Clarity: {N}
- Naming: {N}
- Patterns: {N}
- Redundancy: {N}

### Prochaine etape
```bash
git diff  # Voir les modifications
git add -A && git commit -m "refactor: simplify code"
```
```

---

## EXAMPLES

```bash
# Auto-detect agent, simplify modified files
/simplify

# Force Symfony agent
/simplify --agent symfony

# Simplify specific file
/simplify --file src/Service/UserService.php

# Preview without applying
/simplify --dry-run

# Simplify entire codebase
/simplify --scope all
```

---

## LANGUAGE

User-facing messages in French.
Code examples and technical output in English.

---

## NOW

Begin simplification with: `$ARGUMENTS`

1. Detect or use specified agent
2. Identify files to simplify
3. Load agent instructions
4. Analyze and suggest improvements
5. Apply changes (with confirmation)
