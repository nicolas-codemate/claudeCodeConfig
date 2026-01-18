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

| Dossier | Description |
|---------|-------------|
| `agents/` | Custom agent definitions |
| `commands/` | Slash commands (resolve, commit, fix-ci...) |
| `hooks/` | Pre/post tool use hooks |
| `scripts/` | Automation scripts (solo-implement.sh) |
| `skills/` | Skill definitions (AEP, Architect, ticket-workflow...) |
| `statusline/` | Status bar configuration |

## Key Files

- **`CLAUDE.md`** - Global instructions applied to all sessions
- **`settings.json`** - Permissions, hooks & statusline config

---

## Ticket Resolution Workflow

Systeme modulaire pour la resolution automatisee de tickets, integrant YouTrack (MCP) et GitHub (gh CLI).

### Vue d'ensemble

```
/resolve PROJ-123
    │
    ├─► Detection source (YouTrack/GitHub/Fichier)
    ├─► Fetch ticket → ticket.md
    ├─► Analyse complexite (SIMPLE/MEDIUM/COMPLEX)
    │   └─► Si COMPLEX: Exploration AEP parallele
    ├─► Setup workspace (branche)
    ├─► Creation plan → plan.md
    └─► Implementation (optionnelle) via solo-implement.sh
```

### Commandes disponibles

| Commande | Description |
|----------|-------------|
| `/resolve <ticket-id>` | Workflow complet de resolution |
| `/fetch-ticket <ticket-id>` | Recuperer un ticket uniquement |
| `/analyze-ticket <ticket-id>` | Analyser la complexite |
| `/plan-ticket <ticket-id>` | Creer un plan depuis un ticket existant |

### Modes de /resolve

| Mode | Description |
|------|-------------|
| **Interactif** (defaut) | Pose des questions a chaque etape cle |
| **Automatique** (`--auto`) | Utilise les valeurs detectees/configurees |

### Options de /resolve

```bash
# Initialiser la config du projet (wizard interactif)
/resolve --init

# Mode interactif (defaut) - pose des questions
/resolve PROJ-123

# Mode automatique - aucune question
/resolve PROJ-123 --auto

# Mode auto avec implementation immediate
/resolve PROJ-123 --auto --implement

# Forcer la source
/resolve PROJ-123 --source youtrack
```

### Questions en mode interactif

1. **Resume** : Si un workflow existe deja, reprendre ou recommencer ?
2. **Workflow** : Simple / Standard / Complet (AEP) / Custom ?
3. **Branche de base** : main / develop / branche courante ?
4. **Nom de branche** : Genere automatiquement / court / personnalise ?
5. **Action finale** : Voir le plan / Lancer l'implementation / Terminer ?

### Niveaux de complexite

| Niveau | Score | Exploration | Planning |
|--------|-------|-------------|----------|
| SIMPLE | 0-2 | Skip | Basique |
| MEDIUM | 3-5 | 1 agent | Standard |
| COMPLEX | 6+ | 3 agents AEP | Architect |

### Fichiers generes

Chaque ticket cree un dossier dans le projet :

```
{PROJET}/.claude/feature/{ticket-id}/
├── status.json   # Etat du workflow (pour reprise)
├── ticket.md     # Contenu du ticket original
├── analysis.md   # Analyse de complexite
└── plan.md       # Plan d'implementation
```

### Implementation

Apres la planification, lancer l'implementation :

```bash
# Via le flag --implement
/resolve PROJ-123 --implement

# Ou manuellement
solo-implement.sh --feature PROJ-123

# Ou depuis .claude/implementation (ancien workflow)
solo-implement.sh
```

---

## Configuration Projet

Le systeme peut etre configure par projet via un fichier `.claude/ticket-config.json`.

### Setup rapide

**Option 1 : Wizard interactif (recommande)**

```bash
# Dans votre projet
/resolve --init
```

Le wizard pose des questions et genere la config automatiquement.

**Option 2 : Creation manuelle**

```bash
# Dans votre projet
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

### Configuration complete

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

  "workspace": {
    "prefer_worktree": false,
    "worktree_parent": "../worktrees",
    "auto_stash": true
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
    "simple_labels": ["quick-fix", "typo", "documentation", "trivial"],
    "complex_labels": ["needs-analysis", "architecture", "breaking-change", "migration"],
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
  }
}
```

### Options de configuration

#### `default_source`
- `"auto"` : Detection automatique selon le pattern du ticket ID
- `"youtrack"` : Toujours utiliser YouTrack
- `"github"` : Toujours utiliser GitHub
- `"file"` : Toujours utiliser un fichier local

#### `youtrack.project_prefix`
Prefixe par defaut pour les tickets YouTrack. Permet d'utiliser `/resolve 123` au lieu de `/resolve PROJ-123`.

#### `github.repo`
Repository par defaut au format `owner/repo`. Permet d'utiliser `/resolve #123` sans specifier le repo.

#### `branches.default_base`
Branche de base pour creer les feature branches. Typiquement `main`, `master`, ou `develop`.

#### `branches.prefix_mapping`
Mapping entre les types de tickets et les prefixes de branches :
- Bug → `fix/proj-123-...`
- Feature → `feat/proj-123-...`
- Refactoring → `refactor/proj-123-...`

#### `complexity.simple_labels` / `complex_labels`
Labels qui forcent le niveau de complexite, independamment du score calcule.

#### `complexity.simple_threshold` / `complex_threshold`
Seuils de score pour la classification automatique :
- Score ≤ 2 → SIMPLE
- Score ≥ 6 → COMPLEX
- Entre les deux → MEDIUM

---

## Skills disponibles

| Skill | Description |
|-------|-------------|
| `aep` | Methodologie Analyse-Explore-Plan |
| `architect` | Guidelines architecture pour plans de qualite |
| `fetch-ticket` | Recuperation multi-source de tickets |
| `analyze-ticket` | Analyse de complexite et scoring |
| `setup-workspace` | Creation de branches/worktrees |
| `ticket-workflow` | Machine a etats et coordination |

---

## Scripts

### solo-implement.sh

Orchestrateur d'implementation automatisee par phases.

```bash
# Depuis le workflow ticket
solo-implement.sh --feature PROJ-123

# Depuis /create-plan
solo-implement.sh

# Options
solo-implement.sh --feature PROJ-123 --dry-run      # Preview
solo-implement.sh --feature PROJ-123 --phase 2      # Une seule phase
solo-implement.sh --feature PROJ-123 --start 3      # Reprendre depuis phase 3
solo-implement.sh --feature PROJ-123 --no-commit    # Sans commits auto
solo-implement.sh --feature PROJ-123 --no-validate  # Sans validation
solo-implement.sh --feature PROJ-123 --verbose      # Mode debug
```

**Ordre de recherche des plans** :
1. `--plan FILE` ou `--feature ID` explicite
2. Plus recent dans `.claude/feature/*/plan.md`
3. Plus recent dans `.claude/implementation/*.md`

---

## Prerequis

### YouTrack (MCP)

Le serveur MCP YouTrack doit etre configure dans `~/.claude/settings.json` :

```json
{
  "mcpServers": {
    "youtrack": {
      "command": "node",
      "args": ["/path/to/youtrack-mcp/dist/index.js"],
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
sudo apt install gh  # ou brew install gh

# Authentification
gh auth login
```

---

## Exemples complets

### Exemple 1 : Workflow interactif complet (YouTrack)

```bash
# 1. INITIALISATION DU PROJET (une seule fois)
$ cd /path/to/my-project
$ claude

> /resolve --init

? Quelle source de tickets utilisez-vous ?
  ● YouTrack

? Prefixe du projet YouTrack ?
  > MYAPP

? Branche principale ?
  ● main

? Prefixes de branches ?
  ● Standard (feat/, fix/, ...)

✓ Configuration sauvegardee: .claude/ticket-config.json
```

```bash
# 2. RESOLUTION D'UN TICKET
> /resolve MYAPP-123

Ticket recupere: "Ajouter l'export CSV des utilisateurs"
Type: Feature | Priorite: Normal
Complexite suggeree: MEDIUM (score: 4)

? Quel workflow utiliser ?
  ● Standard - Exploration legere + plan structure

? Branche de base ?
  ● main

? Nom de la branche ?
  ● feat/myapp-123-ajouter-export-csv-utilisateurs

✓ Branche creee
✓ Exploration terminee (fichiers similaires trouves)
✓ Plan genere: .claude/feature/myapp-123/plan.md

? Que faire maintenant ?
  ● Voir le plan

# Implementation Plan: Ajouter l'export CSV des utilisateurs

## Phase 1: Creer le service d'export
**Files**: src/Service/UserExportService.php
**Validation**: bin/phpunit tests/Service/UserExportServiceTest.php

## Phase 2: Ajouter l'endpoint API
**Files**: src/Controller/Api/UserController.php
**Validation**: bin/phpunit tests/Controller/Api/UserControllerTest.php

## Phase 3: Ajouter le bouton dans l'interface
**Files**: assets/js/pages/Users.vue
**Validation**: npm run test

? Que faire maintenant ?
  ● Terminer

Pour implementer plus tard:
  solo-implement.sh --feature myapp-123
```

```bash
# 3. IMPLEMENTATION AUTOMATISEE (hors de Claude)
$ solo-implement.sh --feature myapp-123

╔═══════════════════════════════════════════════════════════╗
║     SOLO-IMPLEMENT.SH - Automated Phase Orchestrator      ║
╚═══════════════════════════════════════════════════════════╝

Using plan: .claude/feature/myapp-123/plan.md
Feature: ajouter-export-csv-utilisateurs
Total phases: 3

═══════════════════════════════════════════════════════════
  Phase 1/3: Creer le service d'export
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
  Phase 2/3: Ajouter l'endpoint API
═══════════════════════════════════════════════════════════

[Claude implements API endpoint...]

✓ Validation passed
✓ Committed: feat(api): add CSV export endpoint for users

═══════════════════════════════════════════════════════════
  Phase 3/3: Ajouter le bouton dans l'interface
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
# 4. VERIFICATION ET PR
$ git log --oneline -n 4
a1b2c3d feat(ui): add export button to users page
e4f5g6h feat(api): add CSV export endpoint for users
i7j8k9l feat(export): add UserExportService for CSV generation
m0n1o2p Previous commit...

$ gh pr create --title "feat: Add CSV export for users (MYAPP-123)"
```

---

### Exemple 2 : Mode automatique (quick fix)

```bash
# Tout en une commande, sans interaction
$ claude -p "/resolve MYAPP-456 --auto --implement"

# Ou en mode interactif puis auto-implement
> /resolve MYAPP-456 --auto --implement

✓ Ticket: "Fix typo in login error message"
✓ Complexite: SIMPLE (score: 1)
✓ Branche: fix/myapp-456-fix-typo-login-error
✓ Plan: 1 phase
✓ Implementation lancee...

[solo-implement.sh s'execute automatiquement]

✓ Phase 1/1 completed
✓ Committed: fix(auth): correct typo in login error message

Done! Review with: git show HEAD
```

---

### Exemple 3 : Reprise apres interruption

```bash
# Session precedente interrompue a la phase 2
$ solo-implement.sh --feature myapp-123

Using plan: .claude/feature/myapp-123/plan.md
Phase 1: ✅ (already completed)

═══════════════════════════════════════════════════════════
  Phase 2/3: Ajouter l'endpoint API (resuming)
═══════════════════════════════════════════════════════════

[Continue implementation...]
```

```bash
# Ou reprendre le workflow /resolve
> /resolve MYAPP-123

? Un workflow existe deja (etat: workspace_ready). Que faire ?
  ● Reprendre - Continuer depuis 'plan'
  ○ Recommencer - Supprimer et repartir de zero
  ○ Annuler
```

---

### Exemple 4 : Workflow GitHub Issues

```bash
# Configuration pour projet GitHub
> /resolve --init

? Source de tickets ?
  ● GitHub Issues

? Repository GitHub ?
  ● Detecter automatiquement

✓ Detecte: my-org/my-repo

# Utilisation
> /resolve #42

Ticket recupere: "Add dark mode support"
[... workflow standard ...]
```

---

### Exemple 5 : Options avancees de solo-implement.sh

```bash
# Preview sans execution
$ solo-implement.sh --feature myapp-123 --dry-run

# Executer une seule phase
$ solo-implement.sh --feature myapp-123 --phase 2

# Reprendre depuis la phase 3
$ solo-implement.sh --feature myapp-123 --start 3

# Sans commits automatiques (pour review manuel)
$ solo-implement.sh --feature myapp-123 --no-commit

# Sans validation (plus rapide mais risque)
$ solo-implement.sh --feature myapp-123 --no-validate

# Mode debug
$ solo-implement.sh --feature myapp-123 --verbose

# Avec extended thinking pour phases complexes
$ solo-implement.sh --feature myapp-123 --thinking-budget 10000
```

---

### Exemple 6 : Structure des fichiers generes

```bash
$ tree .claude/feature/myapp-123/

.claude/feature/myapp-123/
├── status.json      # Etat du workflow
├── ticket.md        # Ticket original (markdown)
├── analysis.md      # Analyse de complexite + exploration
└── plan.md          # Plan pour solo-implement.sh

$ cat .claude/feature/myapp-123/status.json
{
  "ticket_id": "MYAPP-123",
  "source": "youtrack",
  "state": "completed",
  "complexity": "medium",
  "workspace": {
    "type": "branch",
    "name": "feat/myapp-123-ajouter-export-csv",
    "base": "main"
  },
  "phases": {
    "fetch": "completed",
    "analyze": "completed",
    "explore": "completed",
    "workspace": "completed",
    "plan": "completed",
    "implement": "completed"
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
