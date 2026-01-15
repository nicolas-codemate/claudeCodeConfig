/# Master Rules

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

## Quality Assurance

- Test your changes thoroughly before submitting
- Consider edge cases and error scenarios
- Ensure proper error handling for new code
- Validate that new code integrates well with existing systems
- Check for potential security vulnerabilities in new implementations
