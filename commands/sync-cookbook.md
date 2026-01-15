---
description: Fetch latest Claude Code docs and Cookbook articles to update local best practices
---

# Sync Best Practices Command

Update the local Claude Code best practices documentation from official and community sources.

## Target File

`~/.claude/docs/claude-cookbook-best-practices.md`

## Sources to Fetch

### 1. Claude Code Official Documentation

Fetch and extract best practices from:

- https://code.claude.com/docs/en/hooks - Hook events, matchers, examples
- https://code.claude.com/docs/en/hooks-guide - Detailed hook patterns
- https://code.claude.com/docs/en/configuration - Settings structure

Focus on:
- New hook events or features
- Configuration options changes
- New CLI flags
- Security recommendations

### 2. Community Resources

Check for updates from:

- https://shipyard.build/blog/claude-code-cheat-sheet/ - CLI commands, tips
- https://awesomeclaude.ai/code-cheatsheet - Reference guide

Focus on:
- New commands or shortcuts
- Workflow tips
- Integration patterns

### 3. Claude Cookbook (API Patterns)

Fetch from: https://platform.claude.com/cookbook/

Filter: Articles from July 2025 onwards

Focus on patterns applicable to Claude Code:
- Context management techniques
- Extended thinking usage
- Agent patterns that translate to subagents

## Update Process

1. **Fetch each source** using WebFetch tool
2. **Compare with existing content** in the document
3. **Identify new information**:
   - New features or options
   - Changed best practices
   - New examples
4. **Update relevant sections** while preserving structure
5. **Update the "Last updated" date** in the header
6. **Add new sources** to the Sources section if discovered

## Section Mapping

| Source | Document Section |
|--------|------------------|
| Hooks docs | Section 2: Hooks |
| Configuration docs | Section 1: Configuration |
| Cheatsheets | Section 5: CLI Flags, Section 10: Quick Reference |
| Cookbook | Section 9: API Patterns |

## Output

Provide a summary in French:
- What was updated
- New features discovered
- Sources checked
- Any issues encountered

## Important

- Keep the document structure intact
- Only update with verified, official information
- Preserve existing custom examples (hook examples from user's setup)
- Note any breaking changes or deprecations prominently

