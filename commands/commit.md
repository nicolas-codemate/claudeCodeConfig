---
description: Create a commit with auto-generated concise message
---

# Commit Workflow

Generate a commit with a clean, concise message following conventional commit style.

## Step 1: Analyze Changes
1. Run `git status` to see modified/staged files
2. Run `git diff` (or `git diff --cached` if staged) to understand what changed
3. Identify the type of change: feature, fix, refactor, docs, test, chore, etc.

## Step 2: Generate Commit Message

Use conventional commit format:
```
<type>: <short description>

- Detail about the change
- Another detail if needed
```

### Types:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring (no feature/fix)
- `docs`: Documentation only
- `test`: Adding or updating tests
- `chore`: Maintenance, dependencies, config
- `style`: Code style/formatting (no logic change)
- `perf`: Performance improvement

### Rules:
- First line: type + colon + space + short description (max 50 chars)
- Use imperative mood ("Add", "Fix", "Update", not "Added", "Fixed")
- Keep it concise - no fluff
- Empty line, then bullet points for details (optional, only if helpful)

### Examples:
```
feat: add user authentication endpoint

- Implement JWT-based auth
- Add login and logout routes
```

```
fix: resolve null pointer in payment processing
```

```
refactor: simplify database query logic
```

## Step 3: Stage and Commit
1. Stage relevant changes: `git add <files>`
2. Create the commit with generated message
3. Show the result

## Important
- NEVER add "Generated with Claude Code" or co-author lines
- NEVER amend existing commits
- Keep messages concise and professional
- Commit message in English
