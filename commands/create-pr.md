---
description: Skill for pushing branch and creating pull requests with proper target branch detection and draft support.
argument-hint: [--draft|--no-draft] [--target <branch>] [--title <title>]
allowed-tools: Read, Bash, AskUserQuestion, Write
---

# CREATE-PR - Push Branch and Create Pull Request

This command pushes the current branch and creates a pull request.

## Input

```
$ARGUMENTS
```

## Parse Arguments

Extract from arguments:
- `--draft`: Create PR as draft (default: from config or true)
- `--no-draft`: Create PR as ready for review
- `--target`: Target branch for PR (default: auto-detect)
- `--title`: Custom PR title (default: auto-generated)

---

## STEP 1: GATHER CONTEXT

### 1.1 Check Current State

```bash
# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

# Verify not on protected branch
if [[ "$CURRENT_BRANCH" =~ ^(main|master|develop)$ ]]; then
    echo "Erreur: Impossible de creer une PR depuis une branche protegee"
    exit 1
fi

# Check for uncommitted changes
git status --porcelain
```

### 1.2 Detect Ticket Context

Try to find ticket information:

1. From branch name pattern: `{prefix}/{ticket-id}-{slug}`
2. From feature directory: `.claude/feature/*/status.json`
3. From recent commits

```bash
# Extract ticket ID from branch name
TICKET_ID=$(echo "$CURRENT_BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1)

# Check for feature context
if [[ -n "$TICKET_ID" ]] && [[ -f ".claude/feature/$TICKET_ID/status.json" ]]; then
    # Read context from status file
    STATUS_FILE=".claude/feature/$TICKET_ID/status.json"
fi
```

### 1.3 Load Configuration

```bash
# Load project config
cat .claude/ticket-config.json 2>/dev/null || echo "{}"
```

Merge with defaults from `~/.claude/skills/ticket-workflow/references/default-config.json`.

---

## STEP 2: PUSH BRANCH

### 2.1 Check Remote

```bash
# Verify remote exists
git remote get-url origin

# Check if branch is already pushed
git ls-remote --heads origin "$CURRENT_BRANCH"
```

### 2.2 Push with Tracking

```bash
git push -u origin "$CURRENT_BRANCH"
```

If push fails, show appropriate error message.

---

## STEP 3: CHECK EXISTING PR

```bash
# Check if PR already exists for this branch
EXISTING_PR=$(gh pr view "$CURRENT_BRANCH" --json number,url,state 2>/dev/null)
```

If PR exists:
```markdown
## PR Already Exists

- **PR**: #{number}
- **URL**: {url}
- **Status**: {state}

La PR existe deja. Aucune action necessaire.
```

**STOP HERE** if PR exists.

---

## STEP 4: DETERMINE TARGET BRANCH

Priority order:
1. Explicit `--target` argument
2. From status.json `workspace.base`
3. From config `pr.default_target`
4. From config `branches.default_base`
5. Git default branch
6. Fallback: `main`

```bash
# Get git default branch
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
```

If target branch doesn't exist:
```
AskUserQuestion:
  question: "La branche cible '{target}' n'existe pas. Quelle branche utiliser ?"
  header: "Target"
  options:
    - label: "main"
      description: "Branche principale"
    - label: "master"
      description: "Branche principale (legacy)"
    - label: "develop"
      description: "Branche de developpement"
```

---

## STEP 5: GENERATE PR CONTENT

### 5.1 Determine PR Title

If ticket context available:
- Format: `{type}: {ticket_title} ({ticket_id})`

Otherwise:
- From branch name: capitalize and format slug

```bash
# Extract type from branch prefix
TYPE=$(echo "$CURRENT_BRANCH" | cut -d'/' -f1)

# Generate title from slug
SLUG=$(echo "$CURRENT_BRANCH" | cut -d'/' -f2- | sed 's/-/ /g' | sed 's/\b\w/\u&/')
```

### 5.2 Generate PR Body

If feature context available (`.claude/feature/{ticket-id}/`):
- Read ticket.md for summary
- Read plan.md for changes and validation

Otherwise, generate minimal body:

```markdown
## Summary

{Description based on branch name or commits}

## Changes

{List of commits on this branch}

## Test Plan

- [ ] Tests pass
- [ ] Manual verification
```

---

## STEP 6: CREATE PR

### 6.1 Determine Draft Mode

Priority:
1. Explicit `--draft` or `--no-draft` argument
2. From config `pr.draft_by_default`
3. Default: true (draft)

### 6.2 Create PR

```bash
# Build command
DRAFT_FLAG=""
if [[ "$DRAFT" == "true" ]]; then
    DRAFT_FLAG="--draft"
fi

gh pr create \
    --title "$TITLE" \
    --body "$BODY" \
    --base "$TARGET" \
    $DRAFT_FLAG
```

### 6.3 Capture Result

```bash
# Get PR details
PR_URL=$(gh pr view --json url -q '.url')
PR_NUMBER=$(gh pr view --json number -q '.number')
```

---

## STEP 7: UPDATE STATUS

If feature context exists, update `.claude/feature/{ticket-id}/status.json`:

```json
{
  "state": "finalized",
  "phases": {
    "finalize": "completed"
  },
  "pr": {
    "number": {number},
    "url": "{url}",
    "draft": true|false,
    "target": "{target}",
    "created_at": "{ISO timestamp}"
  }
}
```

---

## STEP 8: DISPLAY RESULT

```markdown
## Pull Request Creee

- **PR**: #{number}
- **URL**: {url}
- **Status**: Draft | Ready for review
- **Target**: {target-branch}
- **Branche**: {current-branch}

### Prochaines etapes
1. Reviewer les changements
2. Demander des reviews
3. Marquer ready si draft
4. Merger apres approbation
```

---

## ERROR HANDLING

### Not on Feature Branch
```
Erreur: Vous etes sur une branche protegee ({branch})

Impossible de creer une PR depuis main, master ou develop.
Creez d'abord une branche de feature.
```

### Uncommitted Changes
```
Attention: Modifications non commitees detectees

Voulez-vous:
1. Commiter les changements avant de creer la PR
2. Stash les changements
3. Continuer sans commiter
```

### Push Failed
```
Erreur: Impossible de pousser la branche

- Verifiez votre authentification: gh auth login
- Verifiez les permissions du repository
- Verifiez les regles de protection de branche
```

### PR Creation Failed
```
Erreur: Impossible de creer la pull request

- Verifiez vos droits: gh auth refresh
- Verifiez que la branche cible existe
- Verifiez qu'une PR n'existe pas deja
```

---

## EXAMPLES

```bash
# Simple usage - auto-detect everything
/create-pr

# Create as ready for review
/create-pr --no-draft

# Specify target branch
/create-pr --target develop

# Custom title
/create-pr --title "feat: custom title"

# Full options
/create-pr --no-draft --target main --title "fix: important bugfix"
```

---

## LANGUAGE

User-facing messages in French.
Git commands and PR content in English.

