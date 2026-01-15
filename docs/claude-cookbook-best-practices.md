# Claude Code Best Practices

> Document de référence pour Claude Code CLI
> Last updated: 2026-01-15
> Use `/sync-cookbook` to refresh this document

---

## Table of Contents

1. [Configuration & Settings](#1-configuration--settings)
2. [Hooks](#2-hooks)
3. [Commands & Skills](#3-commands--skills)
4. [Agents & Subagents](#4-agents--subagents)
5. [CLI Flags & Options](#5-cli-flags--options)
6. [Context Management](#6-context-management)
7. [Workflows & Automation](#7-workflows--automation)
8. [Security & Permissions](#8-security--permissions)
9. [API Patterns (Cookbook)](#9-api-patterns-cookbook)
10. [Quick Reference](#10-quick-reference)

---

## 1. Configuration & Settings

### File Hierarchy (Priority Order)

| File | Scope | Git |
|------|-------|-----|
| `/etc/claude-code/managed-settings.json` | Enterprise | N/A |
| `.claude/settings.local.json` | Project personal | Ignored |
| `.claude/settings.json` | Team shared | Committed |
| `~/.claude/settings.json` | User global | N/A |

### CLAUDE.md Files

Context and instructions for Claude at three levels:

```
~/.claude/CLAUDE.md          # Global (all projects)
./CLAUDE.md                  # Project root
./src/components/CLAUDE.md   # Subdirectory specific
```

**Best practices:**
- Use global for coding style, preferences
- Use project for architecture, conventions
- Use subdirectory for component-specific guidance

### Settings Structure

```json
{
  "model": "claude-sonnet-4-5",
  "permissions": {
    "allow": ["Read", "Glob", "Grep"],
    "deny": ["Read(.env*)", "Bash(rm -rf *)"]
  },
  "hooks": { },
  "mcpServers": { }
}
```

---

## 2. Hooks

### Hook Events

| Event | Quand | Usage |
|-------|-------|-------|
| `PreToolUse` | Avant l'outil | Bloquer, modifier, logger |
| `PostToolUse` | Après l'outil | Formatter, valider, notifier |
| `UserPromptSubmit` | Avant envoi prompt | Enrichir contexte |
| `SessionStart` | Début session | Setup |
| `SessionEnd` | Fin session | Cleanup, rapport |
| `Stop` | Arrêt Claude | Finalisation |

### Exit Codes

| Code | Effet |
|------|-------|
| `0` | Success, continue |
| `2` | Block (PreToolUse only), message stderr envoyé à Claude |
| `autre` | Error non-bloquante, affichée à l'utilisateur |

### Matchers

```json
"matcher": "Edit"           // Un seul outil
"matcher": "Edit|Write"     // Plusieurs outils
"matcher": "*"              // Tous les outils
"matcher": "Bash"           // Commandes shell
```

**Outils disponibles:** `Read`, `Write`, `Edit`, `MultiEdit`, `Glob`, `Grep`, `Bash`, `Task`, etc.

### Exemples Pratiques

#### Auto-format après édition

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | { read f; [[ \"$f\" == *.ts ]] && npx prettier --write \"$f\"; } || true"
          }
        ]
      }
    ]
  }
}
```

#### Bloquer fichiers sensibles

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | grep -qE '\\.(env|lock)$' && exit 2 || exit 0"
          }
        ]
      }
    ]
  }
}
```

#### Logger les commandes Bash

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.command' >> ~/.claude/bash-log.txt"
          }
        ]
      }
    ]
  }
}
```

#### Notification sonore

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

### Hook Input (stdin)

Les hooks reçoivent du JSON via stdin:

```json
{
  "session_id": "abc123",
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/path/to/file.ts",
    "old_string": "...",
    "new_string": "..."
  }
}
```

**Parser avec jq:**
```bash
jq -r '.tool_input.file_path'
jq -r '.tool_name'
```

---

## 3. Commands & Skills

### Custom Slash Commands

**Location:**
- `~/.claude/commands/` - Personnel, tous projets
- `.claude/commands/` - Projet, partagé avec l'équipe

**Format:**

```markdown
---
description: Short description for /help
---

# Command Title

Instructions in natural language...

Use $ARGUMENTS for user input.
```

**Invocation:** `/command-name arguments`

### Skills

**Location:** `~/.claude/skills/` ou `.claude/skills/`

**Format:**

```markdown
---
name: skill-name
description: When to use this skill (max 1024 chars)
---

# Skill Title

Detailed instructions...
```

**Différence Commands vs Skills:**

| Aspect | Commands | Skills |
|--------|----------|--------|
| Invocation | Explicite (`/command`) | Automatique par Claude |
| Trigger | User action | Context matching |
| Usage | Actions spécifiques | Expertise domaine |

---

## 4. Agents & Subagents

### Task Tool

Déléguer à des agents spécialisés:

```
subagent_type: "Explore"    # Exploration codebase
subagent_type: "Plan"       # Architecture
subagent_type: "Bash"       # Commandes shell
```

### Custom Subagents

**Location:** `.claude/agents/`

**Usage:**
- Définir des personas spécialisés
- Contexte préservé par agent
- Domain-specific tasks

### Thoroughness Levels (Explore)

```
"quick"         # Recherches basiques, < 3 fichiers
"medium"        # Exploration modérée
"very thorough" # Analyse complète, conventions variées
```

---

## 5. CLI Flags & Options

### Flags Essentiels

| Flag | Usage |
|------|-------|
| `-p "query"` | Print mode (query once, exit) |
| `-c` | Continue recent conversation |
| `-r "id"` | Resume specific session |
| `--model` | Specify model |
| `--thinking-budget N` | Extended thinking tokens |
| `--dangerously-skip-permissions` | Skip all prompts |
| `--output-format text/json` | Output format |
| `--add-dir` | Add working directories |
| `--max-turns N` | Limit conversation turns |
| `--verbose` | Detailed logging |

### Keyboard Shortcuts

| Shortcut | Function |
|----------|----------|
| `!` | Bash mode prefix |
| `@` | Mention files/folders |
| `Esc` | Interrupt Claude |
| `Esc+Esc` | Rewind menu |
| `Ctrl+R` | Full output/context |
| `Shift+Tab` | Auto-accept mode |

### File References

```bash
@./src/Button.tsx           # Single file
@./src/api/                  # Directory
@./file1.js @./file2.js     # Multiple files
@./src/**/*.test.ts         # Glob pattern
```

---

## 6. Context Management

### Extended Thinking

```bash
claude -p "complex task" --thinking-budget 10000
```

**Budget recommendations:**

| Complexity | Budget |
|------------|--------|
| Simple | 1024-2000 |
| Moderate | 2000-5000 |
| Complex planning | 5000-10000 |
| Deep research | 10000+ |

**Constraints:**
- Min: 1024 tokens
- Temperature forced to 1.0
- Incompatible avec top_p, top_k

### Context Compaction (API Pattern)

Pour les workflows multi-phases, utiliser des résumés entre phases:

```bash
# Dans scripts d'automation
prev_summary=$(get_phase_summary ...)
prompt="Previous context: $prev_summary\n\n$current_task"
```

### Session Management

```bash
claude -c                    # Continue last session
claude -r "session-id"       # Resume specific session
```

---

## 7. Workflows & Automation

### Headless Mode

```bash
# CI/CD integration
claude -p "run tests and fix failures" --dangerously-skip-permissions

# Piped input
cat error.log | claude -p "analyze and suggest fix"

# With output capture
result=$(claude -p "query" --output-format text)
```

### Git Worktrees

Paralléliser le développement:

```bash
git worktree add ../feature-branch feature-branch
cd ../feature-branch
claude  # Session séparée, contexte préservé
```

### MCP Server Integration

```bash
claude mcp add github-mcp npx @anthropic-ai/github-mcp
claude mcp add filesystem npx @anthropic-ai/filesystem-mcp
```

---

## 8. Security & Permissions

### Permission Patterns

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Read(.env*)",
      "Read(**/secrets/**)",
      "Bash(rm -rf *)",
      "Bash(curl:*)",
      "Write(package-lock.json)"
    ]
  }
}
```

### Best Practices

1. **Fichiers sensibles** - Deny `.env*`, credentials, secrets
2. **Commandes dangereuses** - Deny `rm -rf`, `curl` avec pipes
3. **Lock files** - Deny write sur `*.lock`, `package-lock.json`
4. **Settings locaux** - Utiliser `.local.json` pour configs sensibles
5. **Review** - Toujours review les changements avant accept

---

## 9. API Patterns (Cookbook)

> Patterns du Claude Cookbook applicables aux workflows Claude Code

### Context Compaction

**Quand:** Workflows séquentiels (tickets, phases, documents)

**Principe:** Résumer le contexte précédent pour libérer des tokens

```python
compaction_control={
    "enabled": True,
    "context_token_threshold": 5000,  # 5k-20k séquentiel
    "model": "claude-haiku-4-5"       # Modèle moins cher
}
```

**Résultat:** 58% réduction tokens

### Programmatic Tool Calling (PTC)

**Quand:** Large datasets, dépendances séquentielles

**Principe:** Filtrer/agréger dans le code, envoyer résumés

**Résultat:** 85% réduction tokens

### Tool Search avec Embeddings

**Quand:** Plus de 20 tools disponibles

**Principe:** Embeddings + similarité cosinus pour sélection

**Résultat:** 90%+ réduction contexte

### Skills API (Progressive Disclosure)

**Principe:**
1. Metadata (64+1024 chars): Toujours chargée
2. Full instructions (<5k tokens): Si pertinent
3. Linked files: Si nécessaire

**Résultat:** 98% économie contexte initial

---

## 10. Quick Reference

### Commands Cheatsheet

```bash
# Basic
claude                       # Interactive REPL
claude "query"              # With initial prompt
claude -p "query"           # Print mode (non-interactive)
claude -c                   # Continue last session
claude update               # Update CLI

# Advanced
claude -p "task" --thinking-budget 5000
claude -p "task" --dangerously-skip-permissions
claude -p "task" --output-format json
cat file | claude -p "analyze"
```

### Settings Quick Setup

```json
{
  "permissions": {
    "deny": ["Read(.env*)", "Bash(rm -rf *)"]
  },
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{"type": "command", "command": "echo 'File modified'"}]
    }]
  }
}
```

### Model Selection

| Model | Use Case | Speed | Cost |
|-------|----------|-------|------|
| `claude-opus-4-5` | Complex reasoning | Slow | $$$ |
| `claude-sonnet-4-5` | General purpose | Medium | $$ |
| `claude-haiku-4-5` | Fast tasks | Fast | $ |

---

## Sources

### Claude Code Official
- [Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [Configuration Documentation](https://code.claude.com/docs/en/configuration)

### Community Resources
- [Claude Code Cheatsheet - Shipyard](https://shipyard.build/blog/claude-code-cheat-sheet/)
- [Claude Code Reference - AwesomeClaude](https://awesomeclaude.ai/code-cheatsheet)
- [Hook Examples - Steve Kinney](https://stevekinney.com/courses/ai-development/claude-code-hook-examples)
- [GitButler Hooks Integration](https://docs.gitbutler.com/features/ai-integration/claude-code-hooks)

### Claude API (Cookbook)
- [Claude Cookbook](https://platform.claude.com/cookbook/)
- [Context Compaction](https://platform.claude.com/cookbook/tool-use-automatic-context-compaction)
- [Extended Thinking](https://platform.claude.com/cookbook/extended-thinking-extended-thinking)

