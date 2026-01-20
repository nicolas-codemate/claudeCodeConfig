# Scripts

Automation scripts for Claude Code workflows.

## Available Scripts

| Script | Description |
|--------|-------------|
| `solo-implement.sh` | Automated phased implementation orchestrator |
| `resolve-worktree.sh` | Worktree wrapper for /resolve --auto mode |

---

## solo-implement.sh

Executes implementation plans phase by phase, with automatic commits and validation.

### Usage

```bash
# From /resolve workflow (recommended)
/resolve PROJ-123 --auto          # Full automatic workflow
/resolve PROJ-123 --continue      # Resume after plan validation

# Direct execution with ticket context
solo-implement.sh --feature PROJ-123

# Direct execution with specific plan
solo-implement.sh --plan path/to/plan.md
```

### Options

```bash
solo-implement.sh --help                    # Show all options
solo-implement.sh --feature PROJ-123        # Use ticket feature directory
solo-implement.sh --plan path/to/plan.md    # Use specific plan file
solo-implement.sh --dry-run                 # Preview without executing
solo-implement.sh --phase 3                 # Execute only phase 3
solo-implement.sh --start 2                 # Resume from phase 2
solo-implement.sh --no-commit               # Skip automatic commits
solo-implement.sh --no-validate             # Skip validation commands
solo-implement.sh --verbose                 # Debug mode
solo-implement.sh --thinking-budget 10000   # Extended thinking for complex phases
```

### Plan Search Order

1. Explicit `--plan FILE` or `--feature ID`
2. Most recent in `.claude/feature/*/plan.md`
3. Most recent in `.claude/implementation/*.md` (legacy)

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  solo-implement.sh --feature PROJ-123                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Load plan from .claude/feature/PROJ-123/plan.md         │
│                                                             │
│  2. For each phase:                                         │
│     ┌─────────────────────────────────────────────────┐    │
│     │  claude --dangerously-skip-permissions          │    │
│     │  > Implement phase N according to plan          │    │
│     │  > Run validation command                       │    │
│     │  > Auto-commit with phase commit message        │    │
│     └─────────────────────────────────────────────────┘    │
│                                                             │
│  3. Update plan with progress markers                       │
│                                                             │
│  4. Report metrics (cost, tokens, lines changed)            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Plan File Format

Plans are read from `.claude/feature/{ticket-id}/plan.md`:

```markdown
---
feature: add-csv-export
ticket_id: PROJ-123
created: 2025-01-14T15:30:00+01:00
status: pending
total_phases: 3
---

# Implementation Plan: Add CSV Export

## Summary

Brief description of the implementation.

## Phase 1: Create Export Service

**Goal**: Implement the export service
**Files**:
- `src/Service/ExportService.php` - Main service

**Validation**: `bin/phpunit tests/Service/ExportServiceTest.php`

**Commit message**: `feat(export): add ExportService`

## Phase 2: Add API Endpoint

**Goal**: Create the REST endpoint
**Files**:
- `src/Controller/Api/ExportController.php`

**Validation**: `bin/phpunit tests/Controller/Api/`

**Commit message**: `feat(api): add export endpoint`

## Phase 3: Frontend Integration

...
```

### Progress Tracking

The plan file is updated as phases complete:

```markdown
## Phase 1: Create Export Service ✅ (2025-01-14T15:45:00)

## Phase 2: Add API Endpoint ✅ (2025-01-14T16:02:00)

## Phase 3: Frontend Integration ← Currently executing
```

### Output Example

```
╔═══════════════════════════════════════════════════════════╗
║     SOLO-IMPLEMENT.SH - Automated Phase Orchestrator      ║
╚═══════════════════════════════════════════════════════════╝

Using plan: .claude/feature/proj-123/plan.md
Feature: add-csv-export
Total phases: 3

═══════════════════════════════════════════════════════════
  Phase 1/3: Create Export Service
═══════════════════════════════════════════════════════════

[Claude implements...]

✓ Validation passed
✓ Committed: feat(export): add ExportService

┌─────────────────────────────────────────────────────────┐
│ Phase 1 Metrics                                         │
├─────────────────────────────────────────────────────────┤
│  💰 Cost:   $0.0234                                     │
│  📝 Lines:  +87, -0                                     │
│  📊 Context: [████████░░░░░░░░░░░░] 42%                 │
└─────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════
  Phase 2/3: Add API Endpoint
═══════════════════════════════════════════════════════════

...

╔═════════════════════════════════════════════════════════╗
║ TOTAL SUMMARY (3 phases)                                ║
╠═════════════════════════════════════════════════════════╣
║  💰 Total Cost:   $0.0891                               ║
║  📝 Total Lines:  +156, -3                              ║
║  📥 Total Input:  45.2K tokens                          ║
║  📤 Total Output: 12.1K tokens                          ║
╚═════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════
  IMPLEMENTATION COMPLETED SUCCESSFULLY!
═══════════════════════════════════════════════════════════
```

### Error Handling

If a phase fails:

1. Script stops immediately
2. Phase is marked with ❌ in the plan
3. Status is set to `partial`
4. Resume with: `solo-implement.sh --feature PROJ-123 --start N`

### Integration with /resolve

The `/resolve` workflow automatically calls `solo-implement.sh`:

```bash
# Interactive mode - asks before implementing
/resolve PROJ-123

# Auto mode - implements automatically
/resolve PROJ-123 --auto
```

After implementation, `/resolve` continues with:
- Code simplification (`/simplify`)
- Code review (`/review-code`)
- Push and PR creation (`/create-pr`)

---

## resolve-worktree.sh

Wrapper script for running `/resolve --auto` with git worktree support. This script handles the worktree creation and directory change that `/resolve` cannot do on its own.

### When to Use

Use this script when you want:
- Full automatic mode (`--auto`) with worktree isolation
- Each ticket in its own worktree directory
- Complete workflow without manual intervention

### Usage

```bash
# Basic usage
resolve-worktree.sh PROJ-123

# With additional options
resolve-worktree.sh PROJ-123 --skip-simplify
resolve-worktree.sh #456 --draft
```

### What It Does

```
┌─────────────────────────────────────────────────────────────┐
│  resolve-worktree.sh PROJ-123                               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Read config from .claude/ticket-config.json             │
│                                                             │
│  2. Create worktree:                                        │
│     - Use Makefile worktree target if available             │
│     - Or create manually: git worktree add                  │
│                                                             │
│  3. Copy essential files to worktree:                       │
│     - .env, .env.local                                      │
│     - .claude/ directory                                    │
│                                                             │
│  4. Change to worktree directory                            │
│                                                             │
│  5. Launch: claude -p "/resolve PROJ-123 --auto"                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Configuration

The script reads `branches.default_base` from `.claude/ticket-config.json` if available:

```json
{
  "branches": {
    "default_base": "main"
  }
}
```

**Defaults**:
- `worktree_parent`: `../worktrees` (relative to repo root)
- `base_branch`: `main` (or from config)

### Worktree Creation Order

The script tries these methods in order:

1. **Makefile target**: If `worktree` or `worktree-new` target exists
2. **Manual fallback**: `git worktree add` with automatic branch creation

### Example Output

```
╔═══════════════════════════════════════════════════════════╗
║     RESOLVE-WORKTREE - Automated Worktree Setup           ║
╚═══════════════════════════════════════════════════════════╝

Ticket: PROJ-123

▶ Loading config from .claude/ticket-config.json
▶ Configuration:
  Base branch: main
  Branch name: feat/proj-123
  Worktree path: ../worktrees/proj-123

▶ Creating worktree...
▶ Fetching from origin...
▶ Creating git worktree...
▶ Worktree ready at: ../worktrees/proj-123
▶ Copying essential files...
  Copied: .env
  Copied: .claude/

▶ Changing to worktree directory...
  Working directory: /home/user/worktrees/proj-123

▶ Launching Claude Code...

═══════════════════════════════════════════════════════════

Running: claude -p "/resolve PROJ-123 --auto"
```

### Comparison: /resolve --auto vs resolve-worktree.sh

| Feature | `/resolve --auto` | `resolve-worktree.sh` |
|---------|-------------------|----------------------|
| Requires branch first | Yes (manual) | No (creates worktree) |
| Creates worktree | No | Yes |
| Changes directory | No | Yes |
| Isolation | Same directory | Separate directory |
| Best for | Quick fixes | Large features, parallel work |

---

## Troubleshooting

**"Claude Code CLI not found"**
- Install Claude Code: `npm install -g @anthropic-ai/claude-code`

**"Not in a git repository"**
- Initialize git: `git init`

**"No plan files found"**
- Create a plan with `/resolve <ticket-id>` first

**Phase keeps failing**
- Check the error in the plan file
- Run manually with `--verbose` for details
- Execute the failing phase interactively in Claude
