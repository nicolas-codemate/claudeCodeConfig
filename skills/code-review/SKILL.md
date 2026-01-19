---
description: Skill for performing comprehensive code review on implementation
---

# Code Review Skill

Orchestrates code review using the code-reviewer agent.

## Purpose

Provides comprehensive code review with dual perspective:
- **Technical**: Code quality, maintainability, SOLID principles
- **Functional**: Ticket requirements, acceptance criteria, edge cases

## Inputs

Required context:
- Ticket content (ticket.md or inline)
- Implementation plan (plan.md or inline)
- Git diff of changes

## Process

### Step 1: Gather Context

1. Read ticket from `.claude/feature/{ticket-id}/ticket.md`
2. Read plan from `.claude/feature/{ticket-id}/plan.md`
3. Get git diff:
   ```bash
   git diff {base-branch}...HEAD
   ```

### Step 2: Load Agent

Load `~/.claude/agents/code-reviewer.md` and apply its instructions.

### Step 3: Perform Review

Execute the agent's review process:
1. Functional completeness check
2. Code quality analysis
3. Maintainability assessment
4. Codebase consistency check

### Step 4: Generate Report

Create review report in `.claude/feature/{ticket-id}/review.md`

### Step 5: Present Results

Display summary:
- Total issues found
- Breakdown by severity
- Recommended action (APPROVED/NEEDS_CHANGES/BLOCKED)

## Configuration

From `.claude/ticket-config.json`:
```json
{
  "review": {
    "enabled": true,
    "auto_fix": false,
    "severity_threshold": "important",
    "model": null,
    "block_on_critical": true
  }
}
```

- `enabled`: Run review phase
- `auto_fix`: Automatically apply suggested fixes
- `severity_threshold`: Minimum severity to report (critical|important|minor)
- `model`: Override model for different analysis perspective
- `block_on_critical`: Prevent PR creation if critical issues exist

## Status Values

- `pending`: Review not yet started
- `in_progress`: Review in progress
- `completed`: Review finished successfully
- `skipped`: Review skipped (disabled or no implementation)
- `failed`: Review encountered an error

## Integration

Invoked by:
- `/resolve` workflow (STEP 10)
- `/review-code` standalone command
