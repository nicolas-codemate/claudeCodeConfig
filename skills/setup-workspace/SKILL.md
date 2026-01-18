---
name: setup-workspace
description: Skill for creating feature branches or git worktrees for ticket implementation. Handles branch naming, base branch selection, and workspace isolation.
---

# Setup Workspace Skill

This skill prepares the git workspace for ticket implementation by creating appropriately named branches or worktrees.

## Workspace Types

### 1. Branch (Default)
Standard git branch created from base branch.
- **Pros**: Simple, familiar, no extra disk space
- **Cons**: Must switch context, can conflict with current work

### 2. Worktree (Optional)
Separate working directory with its own checkout.
- **Pros**: Parallel work, no context switching, isolated
- **Cons**: Extra disk space, more complex setup

## Branch Naming Convention

```
{prefix}/{ticket-id}-{slug}
```

### Components

1. **Prefix**: Derived from ticket type
   ```
   bug → fix
   feature → feat
   task → feat
   improvement → feat
   refactoring → refactor
   documentation → docs
   ```
   Configurable via `branches.prefix_mapping`

2. **Ticket ID**: Lowercase version of ticket identifier
   ```
   PROJ-123 → proj-123
   #456 → 456
   ```

3. **Slug**: Sanitized ticket title
   - Lowercase
   - Spaces → hyphens
   - Remove special characters
   - Truncate to `slug_max_length` (default: 50)

### Examples
```
feat/proj-123-add-user-authentication
fix/proj-456-null-pointer-in-login
refactor/proj-789-extract-validation-service
```

## Setup Process

### Step 1: Determine Base Branch

Priority order:
1. Explicit argument (`--base-branch`)
2. Ticket metadata (if branch specified)
3. Project config (`branches.default_base`)
4. Fallback: `main`

### Step 2: Pre-flight Checks

```bash
# Check for uncommitted changes
git status --porcelain

# If changes exist and auto_stash enabled:
git stash push -m "auto-stash for {ticket-id}"
```

### Step 3: Update Base Branch

```bash
# Fetch latest from remote
git fetch origin

# If on base branch, pull
git pull origin {base-branch}
```

### Step 4: Create Workspace

#### Branch Mode
```bash
# Ensure we're on base branch
git checkout {base-branch}

# Create and switch to feature branch
git checkout -b {branch-name}
```

#### Worktree Mode
```bash
# Create worktree directory
mkdir -p {worktree_parent}

# Create worktree with new branch
git worktree add {worktree_parent}/{ticket-id} -b {branch-name} {base-branch}

# Output path for user
echo "Worktree created at: {worktree_parent}/{ticket-id}"
```

### Step 5: Verify Setup

```bash
# Confirm branch creation
git branch --show-current

# Should output: {branch-name}
```

## Error Handling

### Branch Already Exists
```
Branch '{branch-name}' already exists.

Options:
1. Switch to existing branch: git checkout {branch-name}
2. Delete and recreate: git branch -D {branch-name}
3. Use different name: {branch-name}-2

Recommended: Option 1 if resuming work on same ticket
```

### Uncommitted Changes
```
Uncommitted changes detected.

Options:
1. Stash changes (auto_stash enabled): Proceeding...
2. Commit changes first
3. Discard changes: git checkout .

Proceeding with auto-stash...
```

### Base Branch Not Found
```
Base branch '{base-branch}' not found locally.

Attempting to fetch from remote...
git fetch origin {base-branch}:{base-branch}
```

### Worktree Path Exists
```
Worktree path '{path}' already exists.

Options:
1. Remove existing: git worktree remove {path}
2. Use different path
3. Switch to branch mode
```

## Output Format

```markdown
## Workspace Setup

### Configuration
- **Mode**: Branch
- **Base Branch**: main (from config)
- **Feature Branch**: feat/proj-123-add-user-authentication

### Actions Taken
1. [x] Fetched latest from origin
2. [x] Checked out base branch: main
3. [x] Created feature branch: feat/proj-123-add-user-authentication
4. [x] Switched to feature branch

### Current State
```
On branch feat/proj-123-add-user-authentication
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

### Next Steps
- Ready for implementation
- Feature files will be stored in: .claude/feature/proj-123/
```

## Configuration

From `.claude/ticket-config.json`:

```json
{
  "workspace": {
    "prefer_worktree": false,
    "worktree_parent": "../worktrees",
    "auto_stash": true
  },
  "branches": {
    "default_base": "main",
    "prefix_mapping": {
      "bug": "fix",
      "feature": "feat"
    },
    "include_ticket_id": true,
    "slug_max_length": 50
  }
}
```

## Integration with Workflow

This skill is invoked by:
1. `/resolve` command - after analysis, before planning
2. Other workflows needing workspace setup

## Safety Rules

1. **Never work on main/master directly**
   - Always create feature branch
   - Refuse to proceed if target is protected branch

2. **Preserve uncommitted work**
   - Auto-stash if enabled
   - Warn user and ask if not

3. **Don't force-push or rewrite history**
   - Create new commits only
   - Preserve existing branch history

4. **Verify before destructive operations**
   - Confirm before deleting branches
   - Confirm before removing worktrees

## Branch Name Sanitization

```python
def sanitize_slug(title):
    # Lowercase
    slug = title.lower()
    # Replace spaces and underscores with hyphens
    slug = re.sub(r'[\s_]+', '-', slug)
    # Remove non-alphanumeric (except hyphens)
    slug = re.sub(r'[^a-z0-9-]', '', slug)
    # Collapse multiple hyphens
    slug = re.sub(r'-+', '-', slug)
    # Remove leading/trailing hyphens
    slug = slug.strip('-')
    # Truncate
    slug = slug[:max_length]
    # Remove trailing hyphen after truncation
    slug = slug.rstrip('-')
    return slug
```

## Language

User-facing messages in French.
Git commands and branch names in English.
