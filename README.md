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
| `commands/` | Slash commands (aep, commit, fix-ci...) |
| `hooks/` | Pre/post tool use hooks |
| `scripts/` | Automation scripts |
| `skills/` | Skill definitions |
| `statusline/` | Status bar configuration |

## Key Files

- **`CLAUDE.md`** - Global instructions applied to all sessions
- **`settings.json`** - Permissions, hooks & statusline config

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
