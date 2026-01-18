---
description: Create implementation plan from existing ticket data
argument-hint: <ticket-id> [--skip-explore] [--skip-architect] [--simple]
allowed-tools: Read, Glob, Grep, Bash, Write, Task
---

# PLAN-TICKET - Create Implementation Plan from Ticket

Create an implementation plan for a ticket that has already been fetched.

## Input

```
$ARGUMENTS
```

Parse:
- `ticket_id`: Required - ticket identifier
- `--skip-explore`: Skip exploration phase
- `--skip-architect`: Skip architect skill
- `--simple`: Force simple plan (1-2 phases, no exploration)

---

## STEP 1: VERIFY PREREQUISITES

Check that ticket data exists:
```bash
ls .claude/feature/{ticket-id}/ticket.md
```

If not found:
```
Error: Ticket data not found.

Run first: /fetch-ticket {ticket-id}

Or use /resolve {ticket-id} for complete workflow.
```

---

## STEP 2: LOAD TICKET AND ANALYSIS

Read ticket content:
```bash
cat .claude/feature/{ticket-id}/ticket.md
```

Read analysis if exists:
```bash
cat .claude/feature/{ticket-id}/analysis.md 2>/dev/null
```

If no analysis, run analysis step or infer from ticket.

---

## STEP 3: DETERMINE COMPLEXITY

From analysis.md or from `--simple` flag:

| Level | Exploration | Architect | Phases |
|-------|-------------|-----------|--------|
| SIMPLE | Skip | No | 1-2 |
| MEDIUM | Light | Optional | 2-4 |
| COMPLEX | Full | Yes | 3+ |

---

## STEP 4: EXPLORATION (if needed)

### Skip if:
- `--skip-explore` flag
- `--simple` flag
- Complexity is SIMPLE

### Light Exploration (MEDIUM)
Launch 1 Task agent (subagent_type=Explore):
```
Find similar code patterns and identify files to modify for: {ticket summary}
```

### Full Exploration (COMPLEX)
Launch 3 Task agents in PARALLEL:

**Agent 1**: Implementation Patterns
```
Search for similar features and reusable patterns for: {ticket summary}
```

**Agent 2**: Impact Analysis
```
Trace dependencies and identify all affected components for: {ticket summary}
```

**Agent 3**: Test Coverage
```
Find related tests and testing patterns for: {ticket summary}
```

Collect all findings.

---

## STEP 5: APPLY ARCHITECT SKILL (if COMPLEX)

Unless `--skip-architect`:

Read `~/.claude/skills/architect/SKILL.md` and apply:
- Atomic phase design (max 3 files per phase)
- Risk ordering (infrastructure first)
- Phase design checklist
- Plan-level checklist

---

## STEP 6: GENERATE PLAN

Create implementation plan following the exact format for solo-implement.sh:

```markdown
---
feature: {slug}
ticket_id: {ticket-id}
created: {ISO timestamp}
status: pending
complexity: {level}
total_phases: {N}
---

# Implementation Plan: {Ticket Title}

## Summary

{2-3 sentence description of what will be implemented}

## Context

### Ticket Information
{Key details from ticket}

### Exploration Findings
{What was learned from codebase exploration}

## Phase 1: {Phase Name}

**Goal**: {Single clear objective}

**Files**:
- `path/to/file1.ext` - {What changes}
- `path/to/file2.ext` - {What changes}

**Dependencies**: {Previous phases or external deps}

**Validation**: {Concrete command: `make test`, `npm run lint`, etc.}

**Commit message**: `type(scope): description`

## Phase 2: {Phase Name}

**Goal**: ...

**Files**: ...

**Validation**: ...

**Commit message**: ...

[Continue for all phases...]

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| {What could go wrong} | {How to handle} |

## Post-Implementation

- [ ] Run full test suite
- [ ] Update documentation if needed
- [ ] Create PR for review
```

---

## STEP 7: VALIDATE PLAN

Present plan to user:

```markdown
# Plan Genere pour {ticket-id}

## Resume
- **Complexite**: {level}
- **Phases**: {N}
- **Fichiers impactes**: {count}

## Plan

{Full plan content}

---

## Validation

**Etes-vous satisfait de ce plan ?**
- **"OK"** / **"Go"** → Sauvegarder
- Sinon, indiquez vos modifications
```

---

## STEP 8: SAVE PLAN

Once validated:

1. Write to `.claude/feature/{ticket-id}/plan.md`

2. Update status if exists:
```json
{
  "state": "planned",
  "phases": {
    "plan": "completed"
  }
}
```

3. Confirm:
```markdown
# Plan Sauvegarde

**Fichier**: `.claude/feature/{ticket-id}/plan.md`

## Prochaines Etapes

**Option 1**: Revoir le plan manuellement
```bash
cat .claude/feature/{ticket-id}/plan.md
```

**Option 2**: Lancer l'implementation
```bash
solo-implement.sh --feature {ticket-id}
```

**Option 3**: Continuer dans Claude
Dites "implementer" pour commencer.
```

---

## FORMAT RULES

- **feature**: lowercase slug with hyphens
- **Phases**: atomic, 1-3 files max each
- **Validation**: runnable command
- **Commit message**: conventional format in English

---

## LANGUAGE

User communication in French.
Code, commands, commit messages in English.

---

## NOW

Create plan for: `$ARGUMENTS`
