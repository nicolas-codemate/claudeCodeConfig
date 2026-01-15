#!/bin/bash

#===============================================================================
# implement.sh - Automated phased implementation orchestrator for Claude Code
#
# This script reads a plan created by /plan and executes each phase
# using Claude Code with --dangerously-skip-permissions.
#
# Usage:
#   implement.sh [OPTIONS]
#
# Options:
#   -p, --plan FILE       Use specific plan file (default: latest in .claude/implementation/)
#   -s, --start N         Start from phase N (default: 1 or next pending)
#   -e, --end N           Stop after phase N (default: all phases)
#   --phase N             Execute only phase N
#   --dry-run             Show what would be executed without running
#   --no-commit           Skip automatic commits after phases
#   --no-push             Don't push after completion (default: no push)
#   -v, --verbose         Verbose output
#   -h, --help            Show this help
#
# Requirements:
#   - Claude Code CLI installed and authenticated
#   - Plan file created with /plan command
#   - Git repository initialized
#
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
PLAN_DIR=".claude/implementation"
PLAN_FILE=""
START_PHASE=""
END_PHASE=""
SINGLE_PHASE=""
DRY_RUN=false
NO_COMMIT=false
VERBOSE=false

#-------------------------------------------------------------------------------
# Logging functions
#-------------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_phase() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $*${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}

#-------------------------------------------------------------------------------
# Metrics functions
#-------------------------------------------------------------------------------

# Display metrics from statusline debug file
show_phase_metrics() {
    local phase_num=$1
    local metrics_file="/tmp/statusline-debug.json"
    
    if [[ ! -f "$metrics_file" ]]; then
        log_verbose "Metrics file not found: $metrics_file"
        return
    fi
    
    # Extract metrics from JSON
    local cost input_tokens cache_read cache_creation context_size
    cost=$(jq -r '.cost.total_cost_usd // 0' "$metrics_file" 2>/dev/null)
    input_tokens=$(jq -r '.context_window.current_usage.input_tokens // 0' "$metrics_file" 2>/dev/null)
    cache_read=$(jq -r '.context_window.current_usage.cache_read_input_tokens // 0' "$metrics_file" 2>/dev/null)
    cache_creation=$(jq -r '.context_window.current_usage.cache_creation_input_tokens // 0' "$metrics_file" 2>/dev/null)
    context_size=$(jq -r '.context_window.context_window_size // 200000' "$metrics_file" 2>/dev/null)
    
    # Calculate totals
    local total_tokens=$((input_tokens + cache_read + cache_creation))
    local context_pct=$(awk "BEGIN {printf \"%.1f\", ($total_tokens / $context_size) * 100}")
    local cost_formatted=$(printf "%.4f" "$cost")
    
    # Format tokens with K suffix if large
    local tokens_display
    if [[ $total_tokens -gt 1000 ]]; then
        tokens_display=$(awk "BEGIN {printf \"%.1fK\", $total_tokens / 1000}")
    else
        tokens_display="$total_tokens"
    fi
    
    # Color for context percentage
    local ctx_color
    if (( $(echo "$context_pct < 50" | bc -l) )); then
        ctx_color="$GREEN"
    elif (( $(echo "$context_pct < 80" | bc -l) )); then
        ctx_color="$YELLOW"
    else
        ctx_color="$RED"
    fi
    
    # Progress bar (20 chars)
    local bar_width=20
    local filled=$(awk "BEGIN {printf \"%.0f\", ($context_pct / 100) * $bar_width}")
    local bar=""
    for ((i=0; i<bar_width; i++)); do
        if (( i < filled )); then
            bar+="█"
        else
            bar+="░"
        fi
    done
    
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
    echo -e "  📊 ${BLUE}Phase $phase_num Metrics${NC}"
    echo -e "  💰 Cost: ${GREEN}\${cost_formatted}${NC}"
    echo -e "  🔤 Tokens: ${tokens_display} (input: $input_tokens, cache: $cache_read)"
    echo -e "  📦 Context: ${ctx_color}[$bar]${NC} ${context_pct}%"
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
}

#-------------------------------------------------------------------------------
# Stats functions
#-------------------------------------------------------------------------------

# Get Claude project path for current directory
get_claude_project_path() {
    local cwd
    cwd=$(pwd)
    local encoded
    encoded=$(echo "$cwd" | sed 's|/|-|g')
    echo "$HOME/.claude/projects/$encoded"
}

# Find the most recent JSONL session file
get_latest_session_file() {
    local project_path
    project_path=$(get_claude_project_path)
    
    if [[ -d "$project_path" ]]; then
        find "$project_path" -maxdepth 1 -name "*.jsonl" -type f 2>/dev/null | \
            xargs -r ls -t 2>/dev/null | head -1
    fi
}

# Extract session stats from JSONL file
get_session_stats() {
    local jsonl_file=$1
    
    if [[ ! -f "$jsonl_file" ]]; then
        return 1
    fi
    
    # Count tokens from assistant messages (they have usage info)
    local input_tokens=0
    local output_tokens=0
    local cost=0
    
    # Parse the last summary message or accumulate from messages
    # Look for messages with costUsd field
    while IFS= read -r line; do
        local msg_cost
        msg_cost=$(echo "$line" | jq -r '.message.costUsd // 0' 2>/dev/null)
        if [[ "$msg_cost" != "0" && "$msg_cost" != "null" ]]; then
            cost=$(echo "$cost + $msg_cost" | bc -l 2>/dev/null || echo "$cost")
        fi
        
        local msg_input
        msg_input=$(echo "$line" | jq -r '.message.usage.input_tokens // 0' 2>/dev/null)
        if [[ "$msg_input" != "0" && "$msg_input" != "null" ]]; then
            input_tokens=$((input_tokens + msg_input))
        fi
        
        local msg_output
        msg_output=$(echo "$line" | jq -r '.message.usage.output_tokens // 0' 2>/dev/null)
        if [[ "$msg_output" != "0" && "$msg_output" != "null" ]]; then
            output_tokens=$((output_tokens + msg_output))
        fi
    done < "$jsonl_file"
    
    echo "$input_tokens:$output_tokens:$cost"
}

# Display stats in a nice format
display_phase_stats() {
    local phase_num=$1
    local start_tokens=$2
    local end_tokens=$3
    
    # Try to get stats from ccusage if available
    if command -v npx &> /dev/null; then
        local stats
        stats=$(npx -y ccusage@latest session --json 2>/dev/null | jq -r '.[-1] // empty' 2>/dev/null)
        
        if [[ -n "$stats" ]]; then
            local total_input
            total_input=$(echo "$stats" | jq -r '.input_tokens // 0')
            local total_output
            total_output=$(echo "$stats" | jq -r '.output_tokens // 0')
            local total_cost
            total_cost=$(echo "$stats" | jq -r '.total_cost // 0')
            local context_pct
            context_pct=$(echo "$stats" | jq -r '.context_percentage // 0')
            
            # Format numbers
            local formatted_input
            formatted_input=$(numfmt --to=si --format="%.1f" "$total_input" 2>/dev/null || echo "$total_input")
            local formatted_output
            formatted_output=$(numfmt --to=si --format="%.1f" "$total_output" 2>/dev/null || echo "$total_output")
            local formatted_cost
            formatted_cost=$(printf "%.4f" "$total_cost" 2>/dev/null || echo "$total_cost")
            
            echo ""
            echo -e "${MAGENTA}┌─────────────────────────────────────────────────────────┐${NC}"
            echo -e "${MAGENTA}│${NC} ${BOLD}Phase $phase_num Stats${NC}                                      ${MAGENTA}│${NC}"
            echo -e "${MAGENTA}├─────────────────────────────────────────────────────────┤${NC}"
            echo -e "${MAGENTA}│${NC}  📊 Tokens: ${CYAN}${formatted_input}${NC} in / ${CYAN}${formatted_output}${NC} out               ${MAGENTA}│${NC}"
            echo -e "${MAGENTA}│${NC}  💰 Cost:   ${GREEN}\${formatted_cost}${NC}                              ${MAGENTA}│${NC}"
            echo -e "${MAGENTA}│${NC}  📈 Context: ${YELLOW}${context_pct}%${NC} used                          ${MAGENTA}│${NC}"
            echo -e "${MAGENTA}└─────────────────────────────────────────────────────────┘${NC}"
            return 0
        fi
    fi
    
    # Fallback: simple message
    log_info "Stats: Install ccusage for detailed metrics (npx ccusage)"
}

#-------------------------------------------------------------------------------
# Helper functions
#-------------------------------------------------------------------------------

show_help() {
    head -35 "$0" | tail -32 | sed 's/^# //' | sed 's/^#//'
    exit 0
}

find_latest_plan() {
    local latest
    latest=$(find "$PLAN_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort -r | head -1)
    
    if [[ -z "$latest" ]]; then
        log_error "No plan files found in $PLAN_DIR"
        log_info "Create a plan first with: claude then /plan <your feature>"
        exit 1
    fi
    
    echo "$latest"
}

# Extract frontmatter value
get_frontmatter() {
    local file=$1
    local key=$2
    sed -n '/^---$/,/^---$/p' "$file" | grep "^${key}:" | sed "s/^${key}: *//" | tr -d '"'
}

# Update frontmatter value
update_frontmatter() {
    local file=$1
    local key=$2
    local value=$3
    
    if grep -q "^${key}:" "$file"; then
        sed -i "s/^${key}:.*/${key}: ${value}/" "$file"
    else
        # Add after first ---
        sed -i "/^---$/a ${key}: ${value}" "$file"
    fi
}

# Count total phases in plan
count_phases() {
    local file=$1
    grep -c "^## Phase [0-9]" "$file" || echo "0"
}

# Extract phase content
get_phase_content() {
    local file=$1
    local phase_num=$2
    
    # Extract content between "## Phase N" and next "## Phase" or "## Risks"
    awk "/^## Phase ${phase_num}:/,/^## (Phase|Risks|Post)/" "$file" | head -n -1
}

# Extract commit message for a phase
get_phase_commit_message() {
    local file=$1
    local phase_num=$2
    
    get_phase_content "$file" "$phase_num" | grep "^\*\*Commit message\*\*:" | sed 's/.*`\(.*\)`.*/\1/'
}

# Check if phase is already completed
is_phase_completed() {
    local file=$1
    local phase_num=$2
    
    grep -q "^## Phase ${phase_num}:.*✅" "$file" && return 0
    return 1
}

# Mark phase as completed in plan file
mark_phase_completed() {
    local file=$1
    local phase_num=$2
    local timestamp
    timestamp=$(date -Iseconds)
    
    # Add ✅ and timestamp to phase header
    sed -i "s/^## Phase ${phase_num}: \(.*\)$/## Phase ${phase_num}: \1 ✅ (${timestamp})/" "$file"
}

# Mark phase as failed in plan file
mark_phase_failed() {
    local file=$1
    local phase_num=$2
    local error_msg=$3
    local timestamp
    timestamp=$(date -Iseconds)
    
    sed -i "s/^## Phase ${phase_num}: \(.*\)$/## Phase ${phase_num}: \1 ❌ (${timestamp})\n\n**Error**: ${error_msg}/" "$file"
}

# Cache for commit command (discovered once per run)
COMMIT_CMD_CACHE=""

# Discover commit command using Claude
discover_commit_command() {
    local project_commands=""
    local user_commands=""
    
    # List project commands
    if [[ -d ".claude/commands" ]]; then
        project_commands=$(ls -1 .claude/commands/*.md 2>/dev/null | xargs -I {} basename {} .md | tr '\n' ', ' || true)
    fi
    
    # List user commands
    if [[ -d "$HOME/.claude/commands" ]]; then
        user_commands=$(ls -1 "$HOME/.claude/commands"/*.md 2>/dev/null | xargs -I {} basename {} .md | tr '\n' ', ' || true)
    fi
    
    if [[ -z "$project_commands" && -z "$user_commands" ]]; then
        echo "git"
        return
    fi
    
    log_verbose "Project commands: $project_commands"
    log_verbose "User commands: $user_commands"
    
    # Ask Claude to find the commit command
    local prompt="Find the commit command from these available slash commands.

Project commands (use as /project:name): $project_commands
User commands (use as /name): $user_commands

Rules:
1. Look for commands related to 'commit', 'git commit', or similar
2. Project commands take priority over user commands
3. Return ONLY the command name in format '/project:name' or '/name'
4. If no commit command found, return exactly: git
5. Return ONLY the command, nothing else - no explanation

Examples of valid responses:
/project:commit-yt
/project:commit
/commit
git"

    local result
    result=$(claude -p "$prompt" --output-format text 2>/dev/null | tail -1 | tr -d '\n\r ')
    
    # Validate result format
    if [[ "$result" =~ ^/project:[a-zA-Z0-9_-]+$ ]] || [[ "$result" =~ ^/[a-zA-Z0-9_-]+$ ]] || [[ "$result" == "git" ]]; then
        echo "$result"
    else
        log_verbose "Invalid commit command result: $result, falling back to git"
        echo "git"
    fi
}

# Get commit command (with caching)
get_commit_command() {
    if [[ -n "$COMMIT_CMD_CACHE" ]]; then
        echo "$COMMIT_CMD_CACHE"
        return
    fi
    
    log_info "Discovering commit command..."
    COMMIT_CMD_CACHE=$(discover_commit_command)
    log_info "Using commit command: $COMMIT_CMD_CACHE"
    
    echo "$COMMIT_CMD_CACHE"
}

# Execute git commit
do_commit() {
    local message=$1
    local commit_cmd
    commit_cmd=$(get_commit_command)
    
    if [[ "$NO_COMMIT" == true ]]; then
        log_info "Skipping commit (--no-commit flag)"
        return 0
    fi
    
    log_info "Committing changes..."
    
    if [[ "$commit_cmd" == "git" ]]; then
        git add -A
        git commit -m "$message" || {
            log_warn "Nothing to commit or commit failed"
            return 0
        }
    else
        # Use Claude to commit with the custom command
        claude -p "Run $commit_cmd with message: $message" --dangerously-skip-permissions --output-format text 2>/dev/null || {
            log_warn "Commit via Claude failed, falling back to git"
            git add -A
            git commit -m "$message" || true
        }
    fi
    
    log_success "Committed: $message"
}

#-------------------------------------------------------------------------------
# Main execution
#-------------------------------------------------------------------------------

execute_phase() {
    local plan_file=$1
    local phase_num=$2
    local total_phases=$3
    
    log_phase "Phase $phase_num/$total_phases"
    
    # Check if already completed
    if is_phase_completed "$plan_file" "$phase_num"; then
        log_warn "Phase $phase_num already completed, skipping..."
        return 0
    fi
    
    # Get phase details
    local phase_content
    phase_content=$(get_phase_content "$plan_file" "$phase_num")
    local commit_msg
    commit_msg=$(get_phase_commit_message "$plan_file" "$phase_num")
    
    if [[ -z "$commit_msg" ]]; then
        commit_msg="feat: implement phase $phase_num"
    fi
    
    log_verbose "Phase content:\n$phase_content"
    log_info "Commit message: $commit_msg"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would execute phase $phase_num"
        log_info "[DRY-RUN] Would commit with: $commit_msg"
        return 0
    fi
    
    # Build the prompt for Claude
    local prompt="You are executing Phase $phase_num of an implementation plan.

Read the plan file at: $plan_file

Execute ONLY Phase $phase_num. Here are the details:

$phase_content

IMPORTANT RULES:
1. Execute ONLY the changes for Phase $phase_num
2. Do NOT modify other phases or jump ahead
3. After making changes, run the validation command if specified
4. Do NOT commit - the orchestrator script handles commits
5. If you encounter an error, stop and explain clearly
6. ALL OUTPUT MUST BE IN FRENCH

Begin implementation of Phase $phase_num now."

    # Execute with Claude
    log_info "Executing phase $phase_num with Claude..."
    echo ""
    
    local exit_code=0
    # Run Claude with visible output (no --output-format to see streaming)
    claude -p "$prompt" --dangerously-skip-permissions || exit_code=$?
    
    echo ""
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Phase $phase_num failed with exit code $exit_code"
        mark_phase_failed "$plan_file" "$phase_num" "Claude execution failed with code $exit_code"
        return 1
    fi
    
    # Mark as completed
    mark_phase_completed "$plan_file" "$phase_num"
    log_success "Phase $phase_num completed"
    
    # Show metrics
    show_phase_metrics "$phase_num"
    
    # Commit
    do_commit "$commit_msg"
    
    return 0
}

run_implementation() {
    local plan_file=$1
    
    # Validate plan file
    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file not found: $plan_file"
        exit 1
    fi
    
    log_info "Using plan: $plan_file"
    
    # Get plan metadata
    local feature
    feature=$(get_frontmatter "$plan_file" "feature")
    local status
    status=$(get_frontmatter "$plan_file" "status")
    local total_phases
    total_phases=$(count_phases "$plan_file")
    
    log_info "Feature: $feature"
    log_info "Status: $status"
    log_info "Total phases: $total_phases"
    
    if [[ "$total_phases" -eq 0 ]]; then
        log_error "No phases found in plan file"
        exit 1
    fi
    
    # Determine phase range
    local start=${START_PHASE:-1}
    local end=${END_PHASE:-$total_phases}
    
    if [[ -n "$SINGLE_PHASE" ]]; then
        start=$SINGLE_PHASE
        end=$SINGLE_PHASE
    fi
    
    # Update status to in-progress
    if [[ "$DRY_RUN" == false ]]; then
        update_frontmatter "$plan_file" "status" "in-progress"
    fi
    
    log_info "Executing phases $start to $end"
    
    # Execute phases
    local failed=false
    for ((phase=start; phase<=end; phase++)); do
        if ! execute_phase "$plan_file" "$phase" "$total_phases"; then
            failed=true
            log_error "Implementation stopped at phase $phase"
            break
        fi
        
        # Small pause between phases
        if [[ $phase -lt $end ]]; then
            log_info "Waiting 2 seconds before next phase..."
            sleep 2
        fi
    done
    
    # Final status update
    if [[ "$DRY_RUN" == false ]]; then
        if [[ "$failed" == false && "$end" == "$total_phases" ]]; then
            update_frontmatter "$plan_file" "status" "completed"
            update_frontmatter "$plan_file" "completed" "$(date -Iseconds)"
            do_commit "docs: mark implementation plan as completed"
            
            echo ""
            log_success "═══════════════════════════════════════════════════════════"
            log_success "  IMPLEMENTATION COMPLETED SUCCESSFULLY!"
            log_success "═══════════════════════════════════════════════════════════"
            echo ""
            log_info "Next steps:"
            log_info "  - Review the changes: git log --oneline -n $total_phases"
            log_info "  - Run full test suite"
            log_info "  - Create a PR if applicable"
        else
            update_frontmatter "$plan_file" "status" "partial"
            log_warn "Implementation partially completed (phases 1-$((phase-1)) of $total_phases)"
            log_info "Resume with: $0 --plan $plan_file --start $phase"
        fi
    fi
}

#-------------------------------------------------------------------------------
# Argument parsing
#-------------------------------------------------------------------------------

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--plan)
                PLAN_FILE="$2"
                shift 2
                ;;
            -s|--start)
                START_PHASE="$2"
                shift 2
                ;;
            -e|--end)
                END_PHASE="$2"
                shift 2
                ;;
            --phase)
                SINGLE_PHASE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-commit)
                NO_COMMIT=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    parse_args "$@"
    
    # Check prerequisites
    if ! command -v claude &> /dev/null; then
        log_error "Claude Code CLI not found. Install it first."
        exit 1
    fi
    
    if ! git rev-parse --git-dir &> /dev/null; then
        log_error "Not in a git repository"
        exit 1
    fi
    
    # Find or validate plan file
    if [[ -z "$PLAN_FILE" ]]; then
        PLAN_FILE=$(find_latest_plan)
    fi
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       IMPLEMENT.SH - Automated Phase Orchestrator         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    run_implementation "$PLAN_FILE"
}

main "$@"
