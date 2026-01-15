# Plan & Implement Workflow

A structured development workflow that separates planning from implementation,
using Claude Code for intelligent analysis and automated phase execution.

## Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         WORKFLOW DIAGRAM                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. PLANNING (Interactive)                                          │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │  $ claude                                                 │      │
│  │  > /plan implement user authentication with JWT           │      │
│  │                                                           │      │
│  │  [Claude analyzes, explores, asks questions]              │      │
│  │  [User validates the plan]                                │      │
│  │  [Plan saved to .claude/implementation/]                  │      │
│  └──────────────────────────────────────────────────────────┘      │
│                            │                                        │
│                            ▼                                        │
│  2. IMPLEMENTATION (Automated)                                      │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │  $ implement                                              │      │
│  │                                                           │      │
│  │  ┌─────────┐   ┌─────────┐   ┌─────────┐                │      │
│  │  │ Phase 1 │──▶│ Phase 2 │──▶│ Phase N │                │      │
│  │  │ + commit│   │ + commit│   │ + commit│                │      │
│  │  └─────────┘   └─────────┘   └─────────┘                │      │
│  │                                                           │      │
│  │  Each phase runs with --dangerously-skip-permissions     │      │
│  │  Fresh context per phase (no /compact needed)            │      │
│  └──────────────────────────────────────────────────────────┘      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Plan your feature

```bash
claude
> /plan implement feature X with requirements Y
```

Claude will:
- Analyze your request deeply
- Explore the codebase with parallel agents
- Ask clarification questions
- Create a phased implementation plan
- Wait for your validation
- Save the plan to `.claude/implementation/`

### 2. Execute the implementation

```bash
implement
```

Or with the wrapper:
```bash
dev run
```

The script will:
- Read the latest plan
- Execute each phase with `claude --dangerously-skip-permissions`
- Commit after each phase
- Update progress in the plan file
- Stop on errors (resumable)

## Commands Reference

### Slash Commands

| Command | Description |
|---------|-------------|
| `/plan <feature>` | Full AEP workflow → validated plan file |
| `/aep <feature>` | Original AEP (no file output, simpler) |

### Shell Commands

| Command | Description |
|---------|-------------|
| `dev plan <feature>` | Opens Claude for planning |
| `dev run [options]` | Executes implementation |
| `dev status` | Shows all plans and progress |
| `dev resume` | Continues from last failed phase |
| `implement [options]` | Direct access to orchestrator |

### Implementation Options

```bash
implement --help                    # Show all options
implement --dry-run                 # Preview without executing
implement --phase 3                 # Execute only phase 3
implement --start 2 --end 4         # Execute phases 2-4
implement --plan path/to/plan.md    # Use specific plan
implement --no-commit               # Skip automatic commits
implement --verbose                 # Detailed output
```

## Plan File Format

Plans are saved in `.claude/implementation/YYYY-MM-DD_HH-MM_feature-slug.md`:

```markdown
---
feature: user-authentication
created: 2025-01-14T15:30:00+01:00
status: pending
total_phases: 3
---

# Implementation Plan: User Authentication

## Summary
Brief description of the implementation.

## Phase 1: Database Schema
**Goal**: Create user and session tables
**Files**:
- `migrations/001_users.sql` - User table
- `migrations/002_sessions.sql` - Session table
**Validation**: `php bin/console doctrine:schema:validate`
**Commit message**: `feat(auth): add user and session tables`

## Phase 2: Authentication Service
**Goal**: Implement JWT authentication logic
**Files**:
- `src/Security/JwtAuthenticator.php` - Main authenticator
- `src/Service/TokenService.php` - Token generation
**Validation**: `php bin/phpunit tests/Security/`
**Commit message**: `feat(auth): implement JWT authenticator`

## Phase 3: API Endpoints
...

## Risks & Mitigations
- Risk 1: Mitigation

## Post-Implementation
- [ ] Run full test suite
- [ ] Update API documentation
```

## Progress Tracking

The plan file is updated as phases complete:

```markdown
## Phase 1: Database Schema ✅ (2025-01-14T15:45:00+01:00)
## Phase 2: Authentication Service ✅ (2025-01-14T16:02:00+01:00)
## Phase 3: API Endpoints    ← Currently executing
```

Status values:
- `pending` - Not started
- `in-progress` - Currently executing
- `partial` - Stopped mid-execution (resumable)
- `completed` - All phases done

## Error Handling

If a phase fails:
1. Script stops immediately
2. Phase is marked with ❌ in the plan
3. Status is set to `partial`
4. Resume with: `dev resume` or `implement --start N`

## Best Practices

1. **Write clear feature descriptions** - The better the input, the better the plan
2. **Validate thoroughly** - Iterate on the plan until it's right
3. **Keep phases atomic** - Each phase should be independently committable
4. **Include validation commands** - How to verify each phase works
5. **Use conventional commits** - Pre-defined commit messages per phase

## File Locations

```
~/.claude/
├── commands/
│   ├── plan.md          # /plan command
│   └── aep.md           # /aep command (simpler version)
├── scripts/
│   ├── implement.sh     # Phase orchestrator
│   └── dev.sh           # Convenience wrapper
└── ...

.claude/implementation/  # Per-project plan storage
├── 2025-01-14_15-30_user-authentication.md
└── 2025-01-15_09-00_api-rate-limiting.md
```

## Troubleshooting

**"Claude Code CLI not found"**
- Install Claude Code: `npm install -g @anthropic-ai/claude-code`

**"Not in a git repository"**
- Initialize git: `git init`

**"No plan files found"**
- Create a plan first: `claude` then `/plan <feature>`

**Phase keeps failing**
- Check the error in the plan file
- Run manually with `--verbose` for details
- Execute the failing phase interactively in Claude
