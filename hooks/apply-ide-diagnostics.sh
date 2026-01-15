#!/bin/bash
set -e

# Read hook input from stdin
input=$(cat)

# Extract tool name and file path from hook input
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')

# Exit if not an Edit/Write operation
if [[ -z "$tool_name" || ! "$tool_name" =~ ^(Edit|Write|MultiEdit)$ ]]; then
  exit 0
fi

# Exit if no file path
if [[ -z "$file_path" ]]; then
  exit 0
fi

# Validate file exists
if [[ ! -f "$file_path" ]]; then
  exit 0
fi

# Get current working directory from hook input
cwd=$(echo "$input" | jq -r '.cwd // "."')

# Apply appropriate code quality tools based on file type
case "$file_path" in
  */backend/*.php)
    # PHP files - apply php-cs-fixer via Docker
    cd "$cwd/backend"
    if docker compose ps php &>/dev/null; then
      # Get relative path from backend directory
      relative_path="${file_path#$cwd/backend/}"
      docker compose exec -T php ./vendor/bin/php-cs-fixer fix "$relative_path" --quiet 2>/dev/null || true
    fi
    ;;
  */webapp/*.ts|*/webapp/*.tsx|*/webapp/*.js|*/webapp/*.jsx|*/webapp/*.vue)
    # Frontend files - apply ESLint via Docker
    cd "$cwd/webapp"
    if docker compose ps webapp &>/dev/null; then
      # Get relative path from webapp directory
      relative_path="${file_path#$cwd/webapp/}"
      docker compose exec -T webapp yarn lint "$relative_path" --fix --quiet 2>/dev/null || true
    fi
    ;;
esac

exit 0
