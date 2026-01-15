---
description: Full planning workflow - AEP + validation + save for automated execution
argument-hint: <feature or problem to implement>
allowed-tools: Read, Glob, Grep, Task, Explore, Bash(mkdir:*), Write
---

# PLAN - Full Planning Workflow

This command applies AEP methodology and saves a validated plan for automated execution.

## User Request

`$ARGUMENTS`

---

# STEP 1: APPLY AEP METHODOLOGY

Read and apply the AEP skill from `~/.claude/skills/aep/SKILL.md`:

1. **ANALYSE** - Deep understanding of the request
2. **EXPLORE** - Parallel investigation of the codebase
3. **CLARIFY** - Ask questions if needed (don't proceed with unresolved questions)
4. **PLAN** - Create implementation strategy

---

# STEP 2: FORMAT PLAN FOR AUTOMATION

Once AEP is complete, structure the plan with this **exact format** (required for `implement.sh` parsing):

```markdown
---
feature: [feature-name-slug]
created: [ISO timestamp]
status: pending
total_phases: [N]
---

# Implementation Plan: [Feature Title]

## Summary

[Brief description - 2-3 sentences max]

## Phase 1: [Phase Name]

**Goal**: [What this phase achieves]

**Files**:
- `path/to/file.ext` - [Description of changes]

**Validation**: [Command or check to validate]

**Commit message**: `type: short description`

## Phase 2: [Phase Name]

**Goal**: ...

**Files**: ...

**Validation**: ...

**Commit message**: ...

[Continue for all phases...]

## Risks & Mitigations

- [Risk]: [Mitigation]

## Post-Implementation

- [ ] Run full test suite
- [ ] Update documentation if needed
- [ ] Create PR
```

### Format Rules

- **feature**: lowercase slug with hyphens (e.g., `jwt-authentication`)
- **Phases**: atomic, independently committable, 1-3 files max each
- **Validation**: runnable command or manual check description
- **Commit message**: conventional format in English (`feat:`, `fix:`, `refactor:`, etc.)

---

# STEP 3: VALIDATION LOOP

Present the formatted plan and ask:

> **📋 Le plan est prêt. Voici ce que je propose :**
>
> ```markdown
> [Complete plan here]
> ```
>
> ---
>
> **Êtes-vous satisfait de ce plan ?**
> - **"OK"** / **"Go"** / **"Valide"** → Sauvegarder et passer à l'implémentation
> - Sinon, indiquez vos modifications

### Validation Rules

- User requests changes → Update and present again
- User has questions → Answer and ask for validation again
- **Only proceed when user explicitly validates**

Trigger words: "OK", "Go", "Valide", "C'est bon", "Let's go", "Parfait", "On y va"

---

# STEP 4: SAVE PLAN

Once validated:

1. **Create directory**:
   ```bash
   mkdir -p .claude/implementation
   ```

2. **Generate filename**: `YYYY-MM-DD_HH-MM_[feature-slug].md`

3. **Write plan file** to `.claude/implementation/`

4. **Confirm with instructions**:

> **✅ Plan sauvegardé !**
>
> 📄 `.claude/implementation/[filename].md`
>
> ---
>
> **Pour lancer l'implémentation, quittez Claude et exécutez :**
>
> ```bash
> implement
> ```
>
> Options: `--dry-run`, `--phase N`, `--start N`, `--verbose`

---

# CRITICAL RULES

1. **Read the AEP skill first** - Don't skip the methodology
2. **All output in French** - User communication in French
3. **Plan format is strict** - `implement.sh` parses it
4. **Never skip validation** - User must explicitly approve
5. **Commit messages in English** - Conventional commits

---

# NOW

Enter plan mode, read `~/.claude/skills/aep/SKILL.md`, and begin for: `$ARGUMENTS`
