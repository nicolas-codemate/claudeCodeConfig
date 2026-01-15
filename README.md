<p align="center">
  <img src="https://cdn.jsdelivr.net/gh/anthropics/anthropic-cookbook@main/misc/anthropic_logo.svg" alt="Claude Code" width="80" />
</p>

<h1 align="center">Claude Code Configuration</h1>

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
