---
description: Analyze ticket complexity and determine required workflow phases
argument-hint: <ticket-id or path to ticket.md>
allowed-tools: Read, Glob, Grep, Bash, Write
---

# ANALYZE-TICKET - Complexity Analysis

Standalone command to analyze a ticket's complexity and recommend workflow phases.

## Input

```
$ARGUMENTS
```

Parse:
- `ticket_id` or `path`: Ticket ID (will look in .claude/feature/{id}/ticket.md) or direct path to ticket file

---

## STEP 1: LOAD SKILL

Read and apply the analyze-ticket skill from `~/.claude/skills/analyze-ticket/SKILL.md`.

---

## STEP 2: LOAD TICKET

### From Ticket ID
```bash
cat .claude/feature/{ticket-id}/ticket.md
```

### From Path
```bash
cat {path}
```

If ticket not found, suggest running `/fetch-ticket` first.

---

## STEP 3: EXTRACT CONTENT

Parse the ticket markdown:
- Title (from `# ` heading)
- Description (main content)
- Labels (from metadata table)
- Comments (if present)

---

## STEP 4: CALCULATE COMPLEXITY SCORE

Apply scoring factors from the skill:

### Technical Complexity Factors
| Factor | Points | Check |
|--------|--------|-------|
| Multi-component changes | +2 | Multiple services/modules mentioned |
| Database schema changes | +2 | Keywords: migration, schema, table |
| API breaking changes | +3 | Keywords: breaking, deprecate |
| New external dependency | +2 | Keywords: integrate, new library |
| Performance requirements | +2 | Keywords: optimize, performance |
| Security implications | +2 | Keywords: auth, permission, security |

### Scope Indicators
| Factor | Points | Check |
|--------|--------|-------|
| Cross-team coordination | +2 | Other teams mentioned |
| Multiple file types | +1 | Backend + frontend |
| Test infrastructure | +1 | Keywords: test framework, CI |
| Documentation required | +1 | Doc requirements mentioned |

### Uncertainty Factors
| Factor | Points | Check |
|--------|--------|-------|
| Vague requirements | +2 | Ambiguous language |
| Research needed | +2 | Keywords: investigate, POC |
| Unknown impact | +2 | Cannot determine scope |
| No success criteria | +1 | Missing acceptance criteria |

### Negative Factors
| Factor | Points | Check |
|--------|--------|-------|
| Well-defined scope | -1 | Clear requirements |
| Single file change | -1 | Obvious single file |
| Existing pattern | -1 | Similar code exists |
| Has acceptance criteria | -1 | Clear validation |

---

## STEP 5: CHECK LABELS

Load config from `.claude/ticket-config.json`:

```json
{
  "complexity": {
    "simple_labels": ["quick-fix", "typo", "trivial"],
    "complex_labels": ["architecture", "migration", "breaking-change"]
  }
}
```

If ticket has a simple label → Force SIMPLE
If ticket has a complex label → Force COMPLEX

---

## STEP 6: DETERMINE LEVEL

```
if has_simple_label:
    level = SIMPLE
elif has_complex_label:
    level = COMPLEX
elif score <= 2:
    level = SIMPLE
elif score >= 6:
    level = COMPLEX
else:
    level = MEDIUM
```

---

## STEP 7: OUTPUT ANALYSIS

```markdown
# Analyse de Complexite - {ticket-id}

## Score de Complexite

| Facteur | Points | Raison |
|---------|--------|--------|
| {factor} | +{points} | {reason} |
| ... | ... | ... |
| **Total** | **{score}** | |

## Classification

**Niveau**: {SIMPLE|MEDIUM|COMPLEX} (score: {score})

## Labels Detectes
- Labels du ticket: {labels}
- Labels forcant la complexite: {forcing labels or "aucun"}

## Workflow Recommande

### Exploration
{Skip / Light (1 agent) / Full AEP (3 agents)}

### Planification
{Basic / Standard / Detailed with Architect}

### Phases Estimees
{1-2 / 2-4 / 3+}

## Points d'Attention

- {Key concern 1}
- {Key concern 2}

## Zones a Explorer

1. {Area to investigate}
2. {Related code to check}
3. {Test patterns to find}
```

---

## STEP 8: SAVE ANALYSIS

If `.claude/feature/{ticket-id}/` exists:
- Save to `.claude/feature/{ticket-id}/analysis.md`

Otherwise, display output only.

---

## LANGUAGE

All output in French.

---

## NOW

Analyze: `$ARGUMENTS`
