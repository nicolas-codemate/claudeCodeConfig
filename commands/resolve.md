---
description: Main orchestrator for ticket resolution workflow - fetch, analyze, plan, implement, simplify, review, PR
argument-hint: [ticket-id] [--auto] [--continue] [--refine-plan] [--plan-only] [--init] [--source youtrack|github] [--skip-simplify] [--skip-review] [--pr] [--draft]
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Task, AskUserQuestion, mcp__youtrack__get_issue, mcp__youtrack__get_issue_comments, mcp__youtrack__get_issue_attachments, mcp__figma-screenshot__figma_screenshot
---

# /resolve - Ticket Resolution Workflow

<context>
This command orchestrates the complete ticket resolution workflow by loading
modular step files. Each step is loaded only when needed to minimize context usage.
</context>

## Arguments

```
$ARGUMENTS
```

## Quick Reference

| Flag | Mode | Description |
|------|------|-------------|
| `--init` | INIT | Configure project only |
| `--continue` | CONTINUE | Resume from validated plan |
| `--refine-plan` | REFINE | Refine existing plan interactively |
| `--auto` | AUTO | Complete workflow automatically |
| `--auto --plan-only` | PLAN-ONLY | Stop after plan creation |
| (default) | INTERACTIVE | User validates each step |

## Additional Options

- `--source youtrack|github` : Force ticket source
- `--target <branch>` : Target branch for PR
- `--skip-simplify` : Skip code simplification
- `--skip-review` : Skip code review
- `--skip-visual-verify` : Skip visual verification
- `--pr` : Create PR (INTERACTIVE mode)
- `--draft` / `--no-draft` : PR draft status

## Prerequisite

User must create their branch/worktree BEFORE running /resolve.

## Workflow

Apply skill: `~/.claude/skills/resolve-workflow/SKILL.md`

The skill will:
1. Parse arguments and determine mode
2. Load appropriate step from `~/.claude/skills/resolve-workflow/steps/`
3. Execute step instructions
4. Follow `next` directive to continue or STOP

## Step Reference

| Step | File | When Loaded |
|------|------|-------------|
| 00 | initialization | Start of workflow |
| 01 | fetch-ticket | After init |
| 02 | analyze-complexity | After fetch |
| 03 | exploration | Based on complexity |
| 04 | create-plan | After exploration |
| 05 | plan-validation | After plan, or --refine-plan |
| 06 | implement | After validation, or --continue |
| 07 | simplify | After implement |
| 08 | review | After simplify |
| 09 | finalize | After review (AUTO) |

## Mode Details

See `~/.claude/skills/resolve-workflow/references/modes.md` for detailed mode behaviors.

## Language

All user communication in French.
Technical output (git, code, files) in English.

## NOW

Begin workflow for: `$ARGUMENTS`
