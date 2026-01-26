# Master Rules

- **NEVER** add "Generated with Claude Code" to pull requests
- **NEVER** add Claude as co-authors to commits you create
- **NEVER** work directly on main (or master) branch - always create a feature branch
- **NEVER** erase or modify previous commits - preserve the complete history, do not amend
- Act and code with senior developer standards and best practices
- Use descriptive, verbose method and variable names for clarity
- Always analyze the existing codebase patterns and follow the established conventions
- **Always** add a blank line at the end of every file
- **NEVER** use emoji in code (or comment)
- **Always** comment in english (even if I prompt in french)

## File Operations Strategy

**MCP JetBrains Priority**: For all file operations (search, read, write, create, delete):

1. **First priority**: Use MCP JetBrains - Always attempt this first
2. **Fallback**: If MCP JetBrains is unavailable or fails, use traditional filesystem tools
3. **Always inform**: Let the user know which tool was used and why if fallback was needed

## Environment Setup

**PHP Execution**: PHP is not installed locally on this machine. When you need to execute PHP commands:

1. **First priority**: Check for `compose.yaml` or `docker-compose.yaml` files
   - Look for PHP container names in the services
   - Use: `docker compose exec <containerName> php <command>`
   - Example: `docker compose exec app php bin/console cache:clear`

2. **Second priority**: Check for Makefile or makefile
   - Look for existing PHP-related commands or shortcuts
   - Use the predefined make targets when available
   - Example: `make test`, `make install`, `make cache-clear`

3. **Always verify container/service names** before executing commands

## Git & Version Control

- **Create feature branches**: Never commit directly to main/master branch
- **Preserve commit history**: If you need to revert changes, create a new commit instead of modifying existing ones.
- **Never commit**: Don't create commit, I'll manage myself.
- **NEVER push**: Do NOT run `git push` unless I explicitly ask for it via a prompt or a specific command (like `/create-pr`). This is a strict rule with no exceptions.
- **No commit analysis**: Do not analyze or comment on previous commits unless explicitly requested

## Code Modification Scope

**CRITICAL**: Only modify, correct, or improve code that is directly related to the initial request. Do not make unsolicited changes to unrelated code sections, even if you notice potential improvements, bugs, or style issues, unless explicitly asked to do so.

**Stay focused**: Limit changes to the specific functionality, feature, or issue described in the request. If you notice other issues that should be addressed, mention them in your response but do not implement fixes without explicit permission.

## Development Workflow

- Always read and understand the project structure before making changes
- **File formatting**: Ensure every file ends with exactly one blank line

## Coding Standards

- Follow project-specific coding standards and conventions found in the codebase
- Maintain consistency with existing code patterns and architecture
- Use type hints and documentation where appropriate
- Prioritize readability and maintainability over clever solutions

## Code Formatting (Linters)

After completing ALL modifications on a file, run the appropriate linter once:

- **PHP**: `docker compose exec -T php ./vendor/bin/php-cs-fixer fix <file> --quiet`
- **JS/TS/Vue**: `docker compose exec -T webapp yarn lint <file> --fix --quiet`

**Important**: Run the linter only ONCE per file, after all edits are done. Do not run it after each individual edit to avoid race conditions with unused imports.

## Quality Assurance - Always Works

**CRITICAL**: "Should work" is NOT "does work". Pattern matching and logical reasoning are not enough. Every change MUST be verified.

### Mandatory Testing After Each Modification

After ANY code change, you MUST:

1. **Run/build the code** - Compile, lint, or execute to catch syntax errors
2. **Trigger the exact feature changed** - Don't assume, verify
3. **Observe the expected result** - Check output, logs, UI, database
4. **Check for error messages** - Silent failures are still failures

### Test Requirements by Change Type

- **UI Changes**: Actually interact with the element (click, submit, navigate)
- **API Changes**: Make the actual API call and verify response
- **Database Changes**: Query and confirm the data
- **Logic Changes**: Run the specific scenario with real inputs
- **Config Changes**: Restart/reload and verify it applies

### Phrases to NEVER Use

- "This should work now"
- "I've fixed the issue" (without testing)
- "Try it now" (without trying it yourself first)
- "The logic is correct so..."

### The Reality Check

Before declaring something fixed, ask yourself:
- Did I actually run/test this?
- Did I see the expected result with my own observation?
- Would I bet money this works?

**Time saved skipping tests: 30 seconds. Time wasted when it fails: 30 minutes. User trust lost: immeasurable.**

## Prompt Formatting Guidelines (Claude 4.x Best Practices)

### Use XML Tags for Structure

XML tags help Claude understand prompt sections clearly. Use them consistently.

| Tag | Usage |
|-----|-------|
| `<context>` | Background, situation, why this exists |
| `<instructions>` | Steps to follow (numbered) |
| `<constraints>` | Limits, rules, interdictions |
| `<output>` | Expected output format |
| `<example>` | Concrete examples |
| `<auto_behavior>` | Behavior in AUTO mode |
| `<interactive_behavior>` | Behavior in INTERACTIVE mode |

### Be Explicit and Provide Context

Bad: "Create a dashboard"
Good: "Create an analytics dashboard with interactive charts for user engagement metrics"

Bad: "NEVER use ellipses"
Good: "The text will be read by TTS, avoid ellipses as they cannot be pronounced"

### Nest Tags for Hierarchy

Tags can be nested to organize complex information:

```xml
<instructions>
  <step name="fetch">
    1. Retrieve ticket from source
    2. Parse content
  </step>
  <step name="analyze">
    1. Calculate complexity score
    2. Determine workflow
  </step>
</instructions>
```

### Standard Tags for Skills/Steps

For modular skills and workflow steps, use these standard tags:

- `<context>` : Why this phase exists
- `<instructions>` : What to do (numbered steps)
- `<output>` : Files/status to produce
- `<constraints>` : Rules and limits
- `<interactive_behavior>` : How to behave when user interaction is available
- `<auto_behavior>` : How to behave in automatic mode

### Frontmatter for Step Metadata

Use YAML frontmatter for step configuration:

```yaml
---
name: step-name
description: Brief description
order: 0

skip_if:
  - flag: "--some-flag"
  - condition: "some_condition == true"

next:
  default: next-step
  conditions:
    - if: "mode == 'INIT'"
      then: STOP

tools:
  - Read
  - Write
  - Bash
---
```

### Prompt Quality Checklist

- [ ] Context explains WHY, not just WHAT
- [ ] Instructions are numbered and actionable
- [ ] Constraints are explicit and justified
- [ ] Examples show concrete expected behavior
- [ ] Auto/Interactive behaviors are differentiated
- [ ] Output format is clearly specified
