---
description: Analyse-Explore-Plan workflow with advanced reasoning before development
argument-hint: <problem description or feature to implement>
allowed-tools: Read, Glob, Grep, Task, Explore
---

# AEP - Analyse, Explore, Plan

Apply the AEP methodology from `~/.claude/skills/aep/SKILL.md` for: `$ARGUMENTS`

## Instructions

1. **Read the skill file** at `~/.claude/skills/aep/SKILL.md` to understand the methodology
2. **Execute all 4 phases** in order:
   - Phase 1: ANALYSE
   - Phase 2: EXPLORE (with parallel agents)
   - Phase 3: CLARIFY (ask questions if needed)
   - Phase 4: PLAN
3. **Output the plan** directly in the conversation

This is the simple version - plan stays in the chat.
For automated execution with saved plan files, use `/plan` instead.

## Now

Enter plan mode, read the AEP skill, and begin the workflow for: `$ARGUMENTS`
