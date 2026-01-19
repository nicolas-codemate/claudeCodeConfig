#!/bin/bash
# resolve-worktree.sh - Wrapper for /resolve with worktree support
#
# This script handles the worktree creation for /resolve --auto mode.
# It creates the worktree, changes to the new directory, and relaunches
# claude with --auto --skip-workspace to continue the workflow.
#
# Usage:
#   resolve-worktree.sh <ticket-id> [options]
#
# Examples:
#   resolve-worktree.sh PROJ-123
#   resolve-worktree.sh PROJ-123 --skip-simplify
#   resolve-worktree.sh #456 --draft
#
# The script will:
# 1. Read config from .claude/ticket-config.json
# 2. Create worktree using configured command or fallback
# 3. Copy essential files (.env, etc.)
# 4. Change to worktree directory
# 5. Launch claude with /resolve --auto --skip-workspace

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     RESOLVE-WORKTREE - Automated Worktree Setup           ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}▶${NC} $1"
}

print_error() {
    echo -e "${RED}✗ Error:${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check arguments
TICKET_ID="$1"
shift 2>/dev/null || true  # Remaining args passed to /resolve

if [ -z "$TICKET_ID" ]; then
    echo "Usage: resolve-worktree.sh <ticket-id> [options]"
    echo ""
    echo "Examples:"
    echo "  resolve-worktree.sh PROJ-123"
    echo "  resolve-worktree.sh PROJ-123 --skip-simplify"
    echo ""
    echo "Options are passed to /resolve --auto --skip-workspace"
    exit 1
fi

print_header
echo "Ticket: $TICKET_ID"
echo ""

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_error "Not in a git repository"
    exit 1
fi

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Default values
WORKTREE_PARENT="../worktrees"
WORKTREE_CMD=""
BASE_BRANCH="main"

# Load config if exists
CONFIG_FILE=".claude/ticket-config.json"
if [ -f "$CONFIG_FILE" ]; then
    print_step "Loading config from $CONFIG_FILE"

    if command -v jq &> /dev/null; then
        WORKTREE_CMD=$(jq -r '.workspace.worktree_command // empty' "$CONFIG_FILE" 2>/dev/null || echo "")
        WORKTREE_PARENT=$(jq -r '.workspace.worktree_parent // "../worktrees"' "$CONFIG_FILE" 2>/dev/null || echo "../worktrees")
        BASE_BRANCH=$(jq -r '.branches.default_base // "main"' "$CONFIG_FILE" 2>/dev/null || echo "main")
    else
        print_warning "jq not found, using default config"
    fi
fi

# Generate branch name
# Normalize ticket ID for branch name (lowercase, replace special chars)
TICKET_SLUG=$(echo "$TICKET_ID" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
BRANCH_NAME="feat/$TICKET_SLUG"
WORKTREE_PATH="$WORKTREE_PARENT/$TICKET_SLUG"

print_step "Configuration:"
echo "  Base branch: $BASE_BRANCH"
echo "  Branch name: $BRANCH_NAME"
echo "  Worktree path: $WORKTREE_PATH"
echo ""

# Check if worktree already exists
if [ -d "$WORKTREE_PATH" ]; then
    print_warning "Worktree already exists at $WORKTREE_PATH"
    echo ""

    # Ask if user wants to use existing or recreate
    read -p "Use existing worktree? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        print_step "Using existing worktree"
    else
        print_step "Removing existing worktree"
        git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || rm -rf "$WORKTREE_PATH"
        git branch -D "$BRANCH_NAME" 2>/dev/null || true
    fi
fi

# Create worktree if it doesn't exist
if [ ! -d "$WORKTREE_PATH" ]; then
    print_step "Creating worktree..."

    if [ -n "$WORKTREE_CMD" ]; then
        # Use configured command
        print_step "Using configured worktree command"
        CMD="${WORKTREE_CMD//\{\{ticket_id\}\}/$TICKET_ID}"
        CMD="${CMD//\{\{branch_name\}\}/$BRANCH_NAME}"
        echo "  Command: $CMD"
        eval "$CMD"
    elif [ -f "Makefile" ] && grep -q "worktree" Makefile 2>/dev/null; then
        # Try make target
        print_step "Using Makefile worktree target"
        if grep -q "worktree-new" Makefile; then
            make worktree-new TICKET="$TICKET_ID"
        else
            make worktree TICKET="$TICKET_ID"
        fi
    else
        # Fallback: manual worktree creation
        print_step "Creating worktree manually"

        # Ensure parent directory exists
        mkdir -p "$WORKTREE_PARENT"

        # Fetch latest from origin
        print_step "Fetching from origin..."
        git fetch origin "$BASE_BRANCH" 2>/dev/null || git fetch origin

        # Create worktree with new branch
        print_step "Creating git worktree..."
        git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" "origin/$BASE_BRANCH"
    fi
fi

# Verify worktree was created
if [ ! -d "$WORKTREE_PATH" ]; then
    print_error "Worktree was not created at $WORKTREE_PATH"
    exit 1
fi

print_step "Worktree ready at: $WORKTREE_PATH"

# Copy essential files
print_step "Copying essential files..."
FILES_TO_COPY=(".env" ".env.local")
for file in "${FILES_TO_COPY[@]}"; do
    if [ -f "$file" ] && [ ! -f "$WORKTREE_PATH/$file" ]; then
        cp "$file" "$WORKTREE_PATH/$file"
        echo "  Copied: $file"
    fi
done

# Copy .claude directory if it exists and not already there
if [ -d ".claude" ] && [ ! -d "$WORKTREE_PATH/.claude" ]; then
    cp -r ".claude" "$WORKTREE_PATH/.claude"
    echo "  Copied: .claude/"
fi

echo ""
print_step "Changing to worktree directory..."
cd "$WORKTREE_PATH"
echo "  Working directory: $(pwd)"
echo ""

# Launch claude with /resolve
print_step "Launching Claude Code..."
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# Build the command
CLAUDE_CMD="/resolve $TICKET_ID --auto --skip-workspace"
if [ -n "$*" ]; then
    CLAUDE_CMD="$CLAUDE_CMD $*"
fi

echo "Running: claude -p \"$CLAUDE_CMD\""
echo ""

# Execute claude
exec claude -p "$CLAUDE_CMD"
