```
   _____ _                 _         ___          _
  / ____| |               | |       / __|___   __| | ___
 | |    | | __ _ _   _  __| | ___  | |  / _ \ / _` |/ _ \
 | |____| |/ _` | | | |/ _` |/ _ \ | |_| (_) | (_| |  __/
  \_____|_|\__,_|\__,_|\__,_|\___/  \___\___/ \__,_|\___|
```

<h3 align="center">My Configuration</h3>

<p align="center">
  <em>Personal configuration for <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code CLI</a></em>
</p>

---

## Structure

| Directory     | Description                                            |
|---------------|--------------------------------------------------------|
| `agents/`     | Custom agent definitions                               |
| `commands/`   | Slash commands (resolve, commit, fix-ci...)            |
| `hooks/`      | Pre/post tool use hooks                                |
| `scripts/`    | Automation scripts (solo-implement.sh)                 |
| `skills/`     | Skill definitions (AEP, Architect, ticket-workflow...) |
| `statusline/` | Status bar configuration                               |

## Key Files

- **`CLAUDE.md`** - Global instructions applied to all sessions
- **`settings.json`** - Permissions, hooks & statusline config

---

## Ticket Resolution Workflow

Modular system for automated ticket resolution, integrating YouTrack (MCP) and GitHub (gh CLI).

### Overview

```
/resolve PROJ-123
    │
    ├─► Source detection (YouTrack/GitHub/File)
    ├─► Fetch ticket → ticket.md
    ├─► Analyze complexity (SIMPLE/MEDIUM/COMPLEX)
    │   └─► If COMPLEX: Parallel AEP exploration
    ├─► Create plan → plan.md
    ├─► /compact (clear context)
    ├─► Implementation (phase by phase)
    ├─► Code simplification (auto-detected agent)
    ├─► Code review (dual perspective: tech + product)
    └─► Push + Create PR (draft by default) [--auto only]
```

### Available Commands

| Command                       | Description                                        |
|-------------------------------|----------------------------------------------------|
| `/resolve <ticket-id>`        | Complete resolution workflow                       |
| `/fetch-ticket <ticket-id>`   | Fetch a ticket only                                |
| `/analyze-ticket <ticket-id>` | Analyze complexity                                 |
| `/plan-ticket <ticket-id>`    | Create plan from existing ticket                   |
| `/simplify`                   | Simplify code using auto-detected agent            |
| `/review-code`                | Code review with dual perspective (tech + product) |
| `/create-pr`                  | Push branch and create pull request                |

### /resolve Modes

| Mode                      | Description                                              |
|---------------------------|----------------------------------------------------------|
| **Interactive** (default) | Asks questions at each key step                          |
| **Automatic** (`--auto`)  | Uses detected/configured values, always push + create PR |

### Full Automation (100% Autonomous)

**Step 1**: Create your branch (required before running /resolve)
```bash
git checkout -b feat/PROJ-123
```

**Step 2**: Run /resolve
```bash
# Standard ticket - complete workflow
/resolve PROJ-123 --auto

# Epic / large ticket - stop after plan
/resolve PROJ-123 --auto --plan-only
# Then: solo-implement.sh --feature PROJ-123
```

**Standard `--auto`** workflow:
1. Fetch ticket → Analyze → Explore → Plan
2. `/compact` (clear context)
3. Implement all phases
4. Simplify → Review → Push → PR

**Epic `--auto --plan-only`** workflow:
1. Fetch ticket → Analyze → Explore → Plan
2. STOP and suggest `solo-implement.sh`

**Epic with refinement** (recommended for complex epics):
```bash
# Generate plan
/resolve PROJ-123 --auto --plan-only
# Review and refine interactively
/resolve PROJ-123 --refine-plan
# Then implement
solo-implement.sh --feature PROJ-123
```

**When to use `--plan-only`?** For large epics with many phases. `solo-implement.sh` runs each phase in a separate Claude session, avoiding context overflow.

**When to use `--refine-plan`?** After `--plan-only` to challenge the plan, find edge cases, and iterate with Claude before implementation.

### /resolve Options

```bash
# Initialize project config (interactive wizard)
/resolve --init

# Interactive mode (default) - asks questions
/resolve PROJ-123

# Automatic mode - no questions, implements + creates PR
/resolve PROJ-123 --auto

# Epic mode - stop after plan, suggest solo-implement.sh
/resolve PROJ-123 --auto --plan-only

# Resume after plan validation (interactive mode)
/resolve PROJ-123 --continue

# Refine existing plan interactively (challenge, find edge cases)
/resolve PROJ-123 --refine-plan

# Create PR as ready (not draft)
/resolve PROJ-123 --auto --no-draft

# Specify target branch for PR
/resolve PROJ-123 --auto --target develop

# Skip code simplification
/resolve PROJ-123 --auto --skip-simplify

# Skip code review
/resolve PROJ-123 --auto --skip-review

# Force source
/resolve PROJ-123 --source youtrack
```

### Interactive Mode Flow

1. **Resume**: If workflow exists, resume or restart?
2. **Workflow**: Simple / Standard / Full (AEP) / Custom?
3. **Plan Validation Loop**:
   - Valider et implémenter → `/compact` → implementation
   - Valider et arrêter → STOP (resume via `--continue`)
   - Modifier le plan → apply changes, loop
   - Régénérer le plan → regenerate, loop
4. **Simplify** (after implementation): Yes / No?
5. **Review** (after simplify): View details / Auto-fix / Manual fix / Ignore?

**Note**: In interactive mode, user manages their own branch/workspace. Push and PR are user's responsibility.

### Refine Mode (`--refine-plan`)

For refining an existing plan interactively after `--auto --plan-only`:

```bash
# 1. Generate plan automatically
/resolve PROJ-123 --auto --plan-only

# 2. Review the plan, think about it...

# 3. Refine interactively
/resolve PROJ-123 --refine-plan
```

**Refine Options**:
- **Poser des questions** → Claude identifies edge cases, unclear areas
- **Challenger le plan** → Discuss technical choices, propose alternatives
- **Modifier le plan** → Apply specific changes
- **Régénérer le plan** → Regenerate with new instructions
- **Valider et implémenter** → `/compact` → implementation
- **Valider et arrêter** → STOP (resume via `--continue`)

### Complexity Levels

| Level   | Score | Exploration  | Planning  |
|---------|-------|--------------|-----------|
| SIMPLE  | 0-2   | Skip         | Basic     |
| MEDIUM  | 3-5   | 1 agent      | Standard  |
| COMPLEX | 6+    | 3 AEP agents | Architect |

### Generated Files

Each ticket creates a folder in the project:

```
{PROJECT}/.claude/feature/{ticket-id}/
├── status.json   # Workflow state (for resume) + PR info
├── ticket.md     # Original ticket content
├── analysis.md   # Complexity analysis
├── plan.md       # Implementation plan
└── review.md     # Code review report (after implementation)
```

### Implementation

After plan validation, start the implementation:

```bash
# Resume after "Valider et arrêter" in interactive mode
/resolve PROJ-123 --continue

# Or manually via solo-implement.sh
solo-implement.sh --feature PROJ-123
```

### Pull Request Creation

After implementation, create a PR:

```bash
# Integrated in /resolve (auto mode always creates PR)
/resolve PROJ-123 --auto

# Or standalone command
/create-pr

# Create as ready for review (not draft)
/create-pr --no-draft

# Specify target branch
/create-pr --target develop

# Custom title
/create-pr --title "feat: custom PR title"
```

**Auto mode behavior:**

- Always pushes the branch
- Always creates PR (if not exists)
- Uses `pr.draft_by_default` config (default: true)
- Targets the base branch used for workspace setup

### Code Simplification

After implementation, code can be automatically simplified using project-specific agents:

```bash
# Standalone usage
/simplify

# Force specific agent
/simplify --agent symfony

# Simplify specific file
/simplify --file src/Service/UserService.php

# Preview without applying
/simplify --dry-run
```

**Available agents:**

| Agent     | Auto-detected when                          | Focus                          |
|-----------|---------------------------------------------|--------------------------------|
| `symfony` | `symfony/framework-bundle` in composer.json | Symfony patterns, DI, Doctrine |
| `laravel` | `laravel/framework` in composer.json        | Laravel patterns, Eloquent     |
| `generic` | Default / JS/TS projects                    | General best practices         |

**In `/resolve` workflow:**

- Auto mode: runs simplification if `simplify.auto_apply = true`
- Interactive mode: asks before running

### Code Review

After simplification, code is reviewed using a dual-perspective agent:

```bash
# Standalone usage
/review-code

# With ticket context (loads ticket.md + plan.md)
/review-code --ticket PROJ-123

# Interactively fix issues
/review-code --ticket PROJ-123 --fix

# Only report critical issues
/review-code --severity critical
```

**Dual perspective:**

| Perspective                      | Focus                                                 |
|----------------------------------|-------------------------------------------------------|
| **Technical** (Senior Engineer)  | Code quality, SOLID, YAGNI, KISS, maintainability     |
| **Functional** (Product Manager) | All requirements met, acceptance criteria, edge cases |

**Core principles:**

- **Readability > Performance**: Optimize only when measured bottlenecks exist
- **SOLID**: Single responsibility, open/closed, etc.
- **YAGNI**: No speculative code
- **KISS**: Simplest solution that works
- **Explicit naming**: Self-documenting names
- **Codebase consistency**: Follow existing patterns

**Issue severities:**

| Severity      | Description                                | Action                  |
|---------------|--------------------------------------------|-------------------------|
| **Critical**  | Bugs, security issues, broken requirements | Must fix before merge   |
| **Important** | Maintainability, readability issues        | Should fix before merge |
| **Minor**     | Style suggestions, minor improvements      | Nice to have            |

**In `/resolve` workflow:**

- Auto mode: auto-fixes if `review.auto_fix = true`, blocks on critical if `review.block_on_critical = true`
- Interactive mode: asks for each issue category

---

## Project Configuration

The system can be configured per-project via a `.claude/ticket-config.json` file.

### Quick Setup

**Option 1: Interactive wizard (recommended)**

```bash
# In your project
/resolve --init
```

The wizard asks questions and generates the config automatically.

**Option 2: Manual creation**

```bash
# In your project
mkdir -p .claude
cat > .claude/ticket-config.json << 'EOF'
{
  "default_source": "youtrack",
  "youtrack": {
    "project_prefix": "PROJ"
  },
  "branches": {
    "default_base": "main"
  }
}
EOF
```

### Full Configuration

```json
{
  "default_source": "auto",
  "youtrack": {
    "project_prefix": "PROJ"
  },
  "github": {
    "repo": "owner/repo",
    "issue_prefix": "#"
  },
  "branches": {
    "default_base": "main",
    "prefix_mapping": {
      "bug": "fix",
      "feature": "feat",
      "task": "feat",
      "refactoring": "refactor",
      "documentation": "docs"
    },
    "include_ticket_id": true,
    "slug_max_length": 50
  },
  "complexity": {
    "auto_detect": true,
    "default_level": "medium",
    "simple_labels": [
      "quick-fix",
      "typo",
      "documentation",
      "trivial"
    ],
    "complex_labels": [
      "needs-analysis",
      "architecture",
      "breaking-change",
      "migration"
    ],
    "simple_threshold": 2,
    "complex_threshold": 6
  },
  "planning": {
    "use_architect": true,
    "use_aep": true,
    "max_explore_agents": 3
  },
  "storage": {
    "feature_dir": ".claude/feature",
    "keep_completed": true
  },
  "pr": {
    "draft_by_default": true,
    "default_target": null,
    "include_ticket_link": true,
    "include_test_plan": true,
    "auto_push": true,
    "title_format": "{type}: {title} ({ticket_id})"
  },
  "simplify": {
    "enabled": true,
    "agent": "auto",
    "scope": "modified",
    "auto_apply": false
  },
  "review": {
    "enabled": true,
    "auto_fix": false,
    "severity_threshold": "important",
    "block_on_critical": true
  }
}
```

### Configuration Options

#### `default_source`

- `"auto"`: Auto-detect based on ticket ID pattern
- `"youtrack"`: Always use YouTrack
- `"github"`: Always use GitHub
- `"file"`: Always use local file

#### `youtrack.project_prefix`

Default prefix for YouTrack tickets. Allows using `/resolve 123` instead of `/resolve PROJ-123`.

#### `github.repo`

Default repository in `owner/repo` format. Allows using `/resolve #123` without specifying the repo.

#### `branches.default_base`

Base branch for creating feature branches. Typically `main`, `master`, or `develop`.

#### `branches.prefix_mapping`

Mapping between ticket types and branch prefixes:

- Bug → `fix/proj-123-...`
- Feature → `feat/proj-123-...`
- Refactoring → `refactor/proj-123-...`

#### `complexity.simple_labels` / `complex_labels`

Labels that force complexity level, regardless of calculated score.

#### `complexity.simple_threshold` / `complex_threshold`

Score thresholds for automatic classification:

- Score ≤ 2 → SIMPLE
- Score ≥ 6 → COMPLEX
- In between → MEDIUM

#### `pr.draft_by_default`

Create PRs as draft by default. Default: `true`.

#### `pr.default_target`

Default target branch for PRs. If `null`, uses `branches.default_base`.

#### `pr.include_ticket_link`

Include ticket link in PR body. Default: `true`.

#### `pr.include_test_plan`

Include validation steps from plan in PR body. Default: `true`.

#### `pr.title_format`

PR title format template. Placeholders: `{type}`, `{title}`, `{ticket_id}`.
Default: `"{type}: {title} ({ticket_id})"`.

#### `simplify.enabled`

Enable code simplification phase. Default: `true`.

#### `simplify.agent`

Which simplifier to use:

- `"auto"`: Detect based on project type (symfony, laravel, generic)
- `"symfony"`: Force Symfony simplifier
- `"laravel"`: Force Laravel simplifier
- `"generic"`: Force generic simplifier

#### `simplify.scope`

Scope of files to simplify:

- `"modified"`: Files changed in current branch (default)
- `"phase"`: Files from last implementation phase
- `"all"`: Entire codebase

#### `simplify.auto_apply`

Automatically apply simplifications without asking (auto mode only). Default: `false`.

#### `review.enabled`

Enable code review phase. Default: `true`.

#### `review.auto_fix`

Automatically apply suggested fixes (auto mode only, non-critical issues). Default: `false`.

#### `review.severity_threshold`

Minimum severity level to report:

- `"critical"`: Only critical issues
- `"important"`: Important and critical (default)
- `"minor"`: All issues

#### `review.block_on_critical`

Prevent PR creation if critical issues exist. Default: `true`.

---

## Worktree Support

Worktrees allow working on multiple tickets in parallel in separate directories.

**Important**: `/resolve` does NOT manage workspace creation. You must create your branch or worktree manually before running `/resolve`.

### Manual Worktree Setup

```bash
# Create worktree with feature branch
git worktree add ../worktrees/PROJ-123 -b feat/PROJ-123

# Copy environment files if needed
cp .env ../worktrees/PROJ-123/.env

# Move to worktree and run /resolve
cd ../worktrees/PROJ-123
claude -p "/resolve PROJ-123 --auto"
```

### Recommended: Makefile Target

Add a Makefile target for consistent worktree creation:

```makefile
WORKTREE_DIR ?= ../worktrees

worktree-new: ## Create worktree for ticket
ifndef TICKET
	$(error Usage: make worktree-new TICKET=PROJ-123)
endif
	@mkdir -p $(WORKTREE_DIR)
	git worktree add $(WORKTREE_DIR)/$(TICKET) -b feat/$(TICKET)
	@cp -n .env.example $(WORKTREE_DIR)/$(TICKET)/.env 2>/dev/null || true
	@echo "Worktree ready: cd $(WORKTREE_DIR)/$(TICKET)"

worktree-remove: ## Remove worktree
	git worktree remove $(WORKTREE_DIR)/$(TICKET) --force
```

Usage:

```bash
make worktree-new TICKET=PROJ-123
cd ../worktrees/PROJ-123
claude -p "/resolve PROJ-123 --auto"
```

---

## Available Skills

| Skill             | Description                                   |
|-------------------|-----------------------------------------------|
| `aep`             | Analyze-Explore-Plan methodology              |
| `architect`       | Architecture guidelines for quality plans     |
| `fetch-ticket`    | Multi-source ticket retrieval                 |
| `analyze-ticket`  | Complexity analysis and scoring               |
| `init-project`    | Interactive project configuration wizard      |
| `plan-validation` | Plan validation loop with modification options|
| `ticket-workflow` | State machine and coordination                |
| `code-review`     | Dual-perspective code review (tech + product) |
| `create-pr`       | Push branch and create pull request           |

---

## Agents

### Simplifier Agents

| Agent                | File                           | Use Case                  |
|----------------------|--------------------------------|---------------------------|
| `code-simplifier`    | `agents/code-simplifier.md`    | Generic (JS/TS/Python/Go) |
| `symfony-simplifier` | `agents/symfony-simplifier.md` | Symfony/PHP projects      |

Agents are auto-detected based on project type, or can be forced via `--agent` flag or config.

### Review Agent

| Agent           | File                      | Use Case                     |
|-----------------|---------------------------|------------------------------|
| `code-reviewer` | `agents/code-reviewer.md` | Dual-perspective code review |

The code-reviewer agent applies senior engineer standards with focus on:

- **SOLID principles**: Single responsibility, open/closed, etc.
- **YAGNI**: No unnecessary code
- **KISS**: Simplest working solution
- **Readability > Performance**: Maintainable code first

---

## Scripts

### Installation

Add scripts to your PATH for global access:

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.claude/scripts:$PATH"

# Reload
source ~/.bashrc  # or source ~/.zshrc
```

This makes `solo-implement.sh` and `resolve-worktree.sh` available from anywhere.

### solo-implement.sh

Automated phased implementation orchestrator.

```bash
# From ticket workflow
solo-implement.sh --feature PROJ-123

# From /create-plan
solo-implement.sh

# Options
solo-implement.sh --feature PROJ-123 --dry-run      # Preview
solo-implement.sh --feature PROJ-123 --phase 2      # Single phase only
solo-implement.sh --feature PROJ-123 --start 3      # Resume from phase 3
solo-implement.sh --feature PROJ-123 --no-commit    # Without auto commits
solo-implement.sh --feature PROJ-123 --no-validate  # Without validation
solo-implement.sh --feature PROJ-123 --verbose      # Debug mode
```

**Plan search order**:

1. Explicit `--plan FILE` or `--feature ID`
2. Most recent in `.claude/feature/*/plan.md`
3. Most recent in `.claude/implementation/*.md`

---

## Prerequisites

### YouTrack (MCP)

The YouTrack MCP server must be configured in `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "youtrack": {
      "command": "node",
      "args": [
        "/path/to/youtrack-mcp/dist/index.js"
      ],
      "env": {
        "YOUTRACK_URL": "https://your-instance.youtrack.cloud",
        "YOUTRACK_TOKEN": "your-token"
      }
    }
  }
}
```

### GitHub CLI

```bash
# Installation
sudo apt install gh  # or brew install gh

# Authentication
gh auth login
```

---

## Project Initialization

Before using `/resolve`, initialize your project configuration (once per project):

```bash
$ cd /path/to/my-project
$ claude

> /resolve --init

? What ticket source do you use?
  ● YouTrack

? YouTrack project prefix?
  > MYAPP

? Main branch?
  ● main

? Branch prefixes?
  ● Standard (feat/, fix/, ...)

✓ Configuration saved: .claude/ticket-config.json
```

---

## Complete Examples

### Example 1: Interactive Workflow

```bash
# 1. Create your branch
$ git checkout -b feat/myapp-123-add-csv-export

# 2. Run /resolve
> /resolve MYAPP-123

Ticket fetched: "Add CSV export for users"
Type: Feature | Priority: Normal
Suggested complexity: MEDIUM (score: 4)

? Which workflow to use?
  ● Standard - Light exploration + structured plan

✓ Exploration completed (similar files found)
✓ Plan generated: .claude/feature/myapp-123/plan.md

? What do you want to do now?
  ● View the plan

# Implementation Plan: Add CSV export for users

## Phase 1: Create export service
**Files**: src/Service/UserExportService.php
**Validation**: bin/phpunit tests/Service/UserExportServiceTest.php

## Phase 2: Add API endpoint
**Files**: src/Controller/Api/UserController.php
**Validation**: bin/phpunit tests/Controller/Api/UserControllerTest.php

## Phase 3: Add button to interface
**Files**: assets/js/pages/Users.vue
**Validation**: npm run test

? What do you want to do now?
  ● Valider et implementer

[/compact - clearing context]

[Implementation]
✓ Phase 1/3 completed - Committed
✓ Phase 2/3 completed - Committed
✓ Phase 3/3 completed - Committed

[Simplify + Review]
✓ Code simplified
✓ Code reviewed - no issues

## Implementation Complete

Pour finaliser:
  git push -u origin feat/myapp-123-add-csv-export
  /create-pr
```

### Example 2: Epic Workflow (large tickets)

For large tickets with many phases, use interactive mode to refine the plan, then `solo-implement.sh` for implementation:

```bash
# 1. Create your branch or worktree
$ git checkout -b feat/myapp-123
# Or with worktree:
# $ git worktree add ../worktrees/myapp-123 -b feat/myapp-123
# $ cd ../worktrees/myapp-123

# 2. Launch Claude interactively
$ claude

# 3. Generate and refine the plan
> /resolve MYAPP-123
# → Review the plan, iterate, challenge it...
# → Choose "Valider et arrêter" when satisfied

# 4. Exit Claude and run implementation (separate sessions per phase)
$ solo-implement.sh --feature myapp-123

╔═══════════════════════════════════════════════════════════╗
║     SOLO-IMPLEMENT.SH - Automated Phase Orchestrator      ║
╚═══════════════════════════════════════════════════════════╝

Using plan: .claude/feature/myapp-123/plan.md
Feature: add-csv-export-users
Total phases: 3

═══════════════════════════════════════════════════════════
  Phase 1/3: Create export service
═══════════════════════════════════════════════════════════

[Claude implements UserExportService.php...]

✓ Validation passed
✓ Committed: feat(export): add UserExportService for CSV generation

┌─────────────────────────────────────────────────────────┐
│ Phase 1 Metrics                                         │
├─────────────────────────────────────────────────────────┤
│  💰 Cost:   $0.0234                                     │
│  📝 Lines:  +87, -0                                     │
│  📊 Context: [████████░░░░░░░░░░░░] 42%                 │
└─────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════
  Phase 2/3: Add API endpoint
═══════════════════════════════════════════════════════════

[Claude implements API endpoint...]

✓ Validation passed
✓ Committed: feat(api): add CSV export endpoint for users

═══════════════════════════════════════════════════════════
  Phase 3/3: Add button to interface
═══════════════════════════════════════════════════════════

[Claude implements Vue component...]

✓ Validation passed
✓ Committed: feat(ui): add export button to users page

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

Next steps:
  - Review the changes: git log --oneline -n 3
  - Run full test suite
  - Create a PR if applicable
```

```bash
# 5. VERIFICATION AND PR
$ git log --oneline -n 4
a1b2c3d feat(ui): add export button to users page
e4f5g6h feat(api): add CSV export endpoint for users
i7j8k9l feat(export): add UserExportService for CSV generation
m0n1o2p Previous commit...

$ gh pr create --title "feat: Add CSV export for users (MYAPP-123)"
```

---

### Example 3: Plan-Only + Refine Workflow

For complex epics where you want to review and challenge the plan before implementation:

```bash
# 1. Create your branch
$ git checkout -b feat/myapp-789

# 2. Generate plan automatically (no implementation)
$ claude -p "/resolve MYAPP-789 --auto --plan-only"

✓ Ticket: "Implement user notification system"
✓ Complexity: COMPLEX (score: 8)
✓ Exploration: 3 agents completed
✓ Plan: 5 phases

## Plan d'implémentation: MYAPP-789

### Phase 1: Create notification entity and repository
**Goal**: Database layer for notifications
**Files**: src/Entity/Notification.php, src/Repository/NotificationRepository.php
**Validation**: bin/phpunit tests/Repository/NotificationRepositoryTest.php

### Phase 2: Create notification service
**Goal**: Business logic for creating/sending notifications
**Files**: src/Service/NotificationService.php
**Validation**: bin/phpunit tests/Service/NotificationServiceTest.php

### Phase 3: Add real-time delivery via WebSocket
...

### Phase 4: Create API endpoints
...

### Phase 5: Add admin interface
...

---

## Prochaines étapes

**Options**:
1. Raffiner le plan: /resolve MYAPP-789 --refine-plan
2. Implémenter: solo-implement.sh --feature myapp-789
```

```bash
# 3. Review the plan, think about edge cases...
#    Then refine interactively

$ claude

> /resolve MYAPP-789 --refine-plan

## Raffinement du plan: MYAPP-789

[Plan displayed]

? Comment souhaitez-vous raffiner ce plan ?
  > Poser des questions

## Questions sur le plan

### Edge Cases
1. Que se passe-t-il si l'utilisateur est déconnecté pendant l'envoi ?
2. Comment gérer les notifications en masse (>1000 users) ?

### Clarifications
3. Phase 3 mentionne WebSocket - avez-vous une préférence entre Mercure et Pusher ?
4. Les notifications doivent-elles être persistées après lecture ?

> On utilise Mercure (déjà en place). Pour les notifications en masse,
> on devrait ajouter un système de queue. Oui, persistées 30 jours.

[Claude updates plan with queue system in Phase 2]

? Comment souhaitez-vous raffiner ce plan ?
  > Challenger le plan

Qu'est-ce qui vous préoccupe ?

> La phase 3 (WebSocket) dépend de la phase 2 (service).
> Ne devrait-on pas faire le service de base d'abord, puis ajouter
> le real-time dans une phase séparée ?

Vous avez raison. Je propose de restructurer:
- Phase 2: NotificationService (création, stockage, queue)
- Phase 3: NotificationDeliveryService (email, in-app)
- Phase 4: Real-time via Mercure (séparé)

Voulez-vous appliquer cette modification ?

> Oui

[Plan updated]

? Que faire maintenant ?
  > Valider et arrêter

## Plan Validé

Pour lancer l'implémentation:
  solo-implement.sh --feature myapp-789
```

```bash
# 4. Implement with fresh context per phase
$ solo-implement.sh --feature myapp-789

[Each phase runs in separate Claude session]
```

---

### Example 4: Automatic Mode (quick fix)

```bash
# Step 1: Create branch
$ git checkout -b fix/myapp-456

# Step 2: Run /resolve --auto
$ claude -p "/resolve MYAPP-456 --auto"

✓ Ticket: "Fix typo in login error message"
✓ Complexity: SIMPLE (score: 1)
✓ Plan: 1 phase

[/compact - clearing context]

[Implementation]
✓ Phase 1/1 completed
✓ Committed: fix(auth): correct typo in login error message

[Simplify + Review]
✓ Code simplified
✓ Code reviewed - no issues

[Finalization]
✓ Branch pushed to origin
✓ PR created: #789 (draft)
  https://github.com/my-org/my-repo/pull/789

Done! PR ready for review.
```

```bash
# Create ready PR (not draft)
> /resolve MYAPP-456 --auto --no-draft

# Interactive mode: validates plan, user manages push/PR
> /resolve MYAPP-456
```

---

### Example 5: Resume After Interruption

```bash
# Previous session interrupted at phase 2
$ solo-implement.sh --feature myapp-123

Using plan: .claude/feature/myapp-123/plan.md
Phase 1: ✅ (already completed)

═══════════════════════════════════════════════════════════
  Phase 2/3: Add API endpoint (resuming)
═══════════════════════════════════════════════════════════

[Continue implementation...]
```

```bash
# Or resume the /resolve workflow
> /resolve MYAPP-123

? A workflow already exists (state: planned). What to do?
  ● Resume - Continue from 'implement'
  ○ Restart - Delete and start over
  ○ Cancel
```

---

### Example 6: GitHub Issues Workflow

```bash
# Configuration for GitHub project
> /resolve --init

? Ticket source?
  ● GitHub Issues

? GitHub repository?
  ● Auto-detect

✓ Detected: my-org/my-repo

# Usage
> /resolve #42

Ticket fetched: "Add dark mode support"
[... standard workflow ...]
```

---

### Example 7: Advanced solo-implement.sh Options

```bash
# Preview without execution
$ solo-implement.sh --feature myapp-123 --dry-run

# Execute single phase only
$ solo-implement.sh --feature myapp-123 --phase 2

# Resume from phase 3
$ solo-implement.sh --feature myapp-123 --start 3

# Without auto commits (for manual review)
$ solo-implement.sh --feature myapp-123 --no-commit

# Without validation (faster but risky)
$ solo-implement.sh --feature myapp-123 --no-validate

# Debug mode
$ solo-implement.sh --feature myapp-123 --verbose

# With extended thinking for complex phases
$ solo-implement.sh --feature myapp-123 --thinking-budget 10000
```

---

### Example 8: Generated Files Structure

```bash
$ tree .claude/feature/myapp-123/

.claude/feature/myapp-123/
├── status.json      # Workflow state + PR info
├── ticket.md        # Original ticket (markdown)
├── analysis.md      # Complexity analysis + exploration
├── plan.md          # Plan for solo-implement.sh
└── review.md        # Code review report

$ cat .claude/feature/myapp-123/status.json
{
  "ticket_id": "MYAPP-123",
  "source": "youtrack",
  "state": "finalized",
  "complexity": "medium",
  "phases": {
    "fetch": "completed",
    "analyze": "completed",
    "explore": "completed",
    "plan": "completed",
    "implement": "completed",
    "simplify": "completed",
    "review": "completed",
    "finalize": "completed"
  },
  "pr": {
    "number": 456,
    "url": "https://github.com/my-org/my-repo/pull/456",
    "draft": true,
    "target": "main"
  }
}
```

---

## Usage

Clone and symlink to `~/.claude`:

```bash
git clone <repo> ~/.claude-config
ln -s ~/.claude-config ~/.claude
```

---

<p align="center">
  <sub>Powered by <a href="https://claude.ai">Claude</a> from Anthropic</sub>
</p>
