---
name: plan-validation
description: Interactive plan validation loop for /resolve. Displays plan, offers modification/regeneration options, handles validation states.
---

# Plan Validation Skill

Interactive validation loop for implementation plans. Allows users to review, modify, regenerate, or validate plans before implementation.

## Input Requirements

- `ticket_id`: The ticket identifier
- `plan_path`: Path to plan file (`.claude/feature/{ticket-id}/plan.md`)
- `status_path`: Path to status file (`.claude/feature/{ticket-id}/status.json`)
- `mode`: Either "interactive" or "auto"

## Behavior by Mode

### AUTO Mode

In AUTO mode, the plan is validated automatically without user interaction:

1. Mark plan as validated
2. Update status:
   ```json
   {
     "state": "plan_validated",
     "plan_validated_at": "{ISO timestamp}"
   }
   ```
3. Return `continue_to_implement: true`

### INTERACTIVE Mode

In INTERACTIVE mode, enter the validation loop described below.

## Validation Loop

### 1. Display Plan Summary

```markdown
# Plan d'implementation: {ticket-id}

## Ticket
- **ID**: {ticket-id}
- **Titre**: {title}
- **Source**: {source}

## Analyse
- **Complexite**: {level}
- **Workflow**: {workflow_type}
- **Exploration**: {exploration_status}

## Plan
- **Phases**: {N}
- **Fichier**: .claude/feature/{ticket-id}/plan.md
```

Display the full plan content from the plan file.

### 2. Present Options

```
AskUserQuestion:
  question: "Que souhaitez-vous faire avec ce plan ?"
  header: "Plan"
  options:
    - label: "Valider et implementer"
      description: "Confirmer le plan, executer /compact et lancer l'implementation"
    - label: "Valider et arreter"
      description: "Confirmer le plan, continuer plus tard via --continue"
    - label: "Modifier le plan"
      description: "Apporter des changements au plan"
    - label: "Regenerer le plan"
      description: "Relancer la generation avec nouvelles instructions"
```

### 3. Handle User Choice

#### Option: "Modifier le plan"

```
AskUserQuestion:
  question: "Quelles modifications souhaitez-vous apporter ?"
  header: "Modifications"
  options:
    - label: "Ajouter une phase"
      description: "Inserer une nouvelle etape dans le plan"
    - label: "Modifier une phase"
      description: "Changer le contenu d'une phase existante"
    - label: "Supprimer une phase"
      description: "Retirer une etape du plan"
    - label: "Autre modification"
      description: "Decrire librement les changements"
```

After user describes modifications:
1. Apply changes to plan file
2. Re-display the updated plan
3. Return to step 2 (loop)

#### Option: "Regenerer le plan"

```
AskUserQuestion:
  question: "Quelles instructions pour la nouvelle generation ?"
  header: "Instructions"
  options:
    - label: "Plus simple"
      description: "Reduire le nombre de phases, approche minimaliste"
    - label: "Plus detaille"
      description: "Ajouter plus de details et sous-etapes"
    - label: "Approche differente"
      description: "Utiliser une autre strategie d'implementation"
    - label: "Instructions specifiques"
      description: "Decrire precisement ce que vous voulez"
```

After receiving instructions:
1. Delete current plan
2. Return `regenerate_plan: true` with regeneration context
3. Caller should regenerate plan and call this skill again

#### Option: "Valider et arreter"

1. Update status:
   ```json
   {
     "state": "plan_validated",
     "plan_validated_at": "{ISO timestamp}"
   }
   ```

2. Display next steps:
   ```markdown
   ## Plan Valide

   Le plan a ete enregistre. Pour lancer l'implementation :

   1. Creez d'abord votre branche/worktree:
      ```bash
      git checkout -b {prefix}/{ticket-id}-{slug}
      ```

   2. Puis lancez l'implementation:
      ```bash
      /resolve {ticket-id} --continue
      ```

   Le workflow reprendra avec /compact puis implementation.
   ```

3. Return `stop: true` - Do not continue to implementation

#### Option: "Valider et implementer"

1. Update status:
   ```json
   {
     "state": "plan_validated",
     "plan_validated_at": "{ISO timestamp}"
   }
   ```

2. Remind user about branch:
   ```markdown
   ## Pre-Implementation

   Avant de continuer, assurez-vous d'avoir cree votre branche:
     git checkout -b {prefix}/{ticket-id}-{slug}
   ```

3. Confirm branch ready:
   ```
   AskUserQuestion:
     question: "Branche creee ? Pret pour l'implementation ?"
     header: "Confirm"
     options:
       - label: "Oui, lancer /compact et implementer"
         description: "Vider le contexte et demarrer l'implementation"
       - label: "Annuler"
         description: "Revenir aux options du plan"
   ```

4. If confirmed:
   - Execute `/compact` to clear context
   - Return `continue_to_implement: true`

5. If cancelled:
   - Return to step 2 (loop)

## Output

The skill returns one of:

| Output | Meaning |
|--------|---------|
| `continue_to_implement: true` | Proceed to implementation (after /compact in interactive mode) |
| `stop: true` | Stop workflow, user will resume later via --continue |
| `regenerate_plan: true` | Caller should regenerate plan with provided context |

## Status Updates

This skill updates `.claude/feature/{ticket-id}/status.json`:

```json
{
  "state": "plan_validated",
  "plan_validated_at": "2025-01-19T10:30:00+01:00"
}
```
