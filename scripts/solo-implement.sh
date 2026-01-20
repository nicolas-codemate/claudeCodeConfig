#!/bin/bash

#===============================================================================
# solo-implement.sh - Automated phased implementation orchestrator for Claude Code
#
# This script reads a plan created by /create-plan and executes each phase
# using Claude Code with --dangerously-skip-permissions.
#
# Features:
#   - Dynamic validation: Claude detects and runs appropriate tests/linters
#   - Intelligent retry: Failed phases are retried with error context
#   - Phase context: Each phase receives summary of completed phases
#   - Extended thinking: Optional thinking budget for complex phases
#
# Usage:
#   solo-implement.sh [OPTIONS]
#
# Options:
#   -p, --plan FILE         Use specific plan file (default: auto-detect)
#   -f, --feature ID        Use plan from .claude/feature/{ID}/plan.md
#   -s, --start N           Start from phase N (default: 1 or next pending)
#   -e, --end N             Stop after phase N (default: all phases)
#   --phase N               Execute only phase N
#   --dry-run               Show what would be executed without running
#   --no-commit             Skip automatic commits after phases
#   --no-validate           Skip dynamic validation after each phase
#   --max-retries N         Max retry attempts per phase (default: 2)
#   --retry-delay N         Seconds to wait between retries (default: 5)
#   --thinking-budget N     Enable extended thinking with N tokens budget
#   -v, --verbose           Verbose output
#   -h, --help              Show this help
#
# Plan Search Order:
#   1. Explicit --plan or --feature argument
#   2. Most recent .claude/feature/*/plan.md (from /resolve workflow)
#   3. Most recent .claude/implementation/*.md (from /create-plan)
#
# Requirements:
#   - Claude Code CLI installed and authenticated
#   - Plan file created with /create-plan command
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
FEATURE_DIR=".claude/feature"
PLAN_FILE=""
FEATURE_ID=""
START_PHASE=""
END_PHASE=""
SINGLE_PHASE=""
DRY_RUN=false
NO_COMMIT=false
NO_VALIDATE=false
VERBOSE=false

# Reliability configuration
MAX_RETRIES=2
RETRY_DELAY=5
THINKING_BUDGET=""

# Claude CLI options - use stream-json for real-time output
CLAUDE_STREAMING=true  # Enable real-time streaming output

# Runtime state
LAST_OUTPUT=""

# Temporary files tracking for cleanup
TEMP_FILES=()

# Cumulative metrics for final summary
TOTAL_COST=0
TOTAL_INPUT_TOKENS=0
TOTAL_OUTPUT_TOKENS=0
TOTAL_LINES_ADDED=0
TOTAL_LINES_DELETED=0
PHASES_COMPLETED=0

# Cleanup function for trap
cleanup() {
    for f in "${TEMP_FILES[@]}"; do
        rm -f "$f" 2>/dev/null
    done
}

trap cleanup EXIT INT TERM

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
# Claude execution with streaming
#-------------------------------------------------------------------------------

# Run Claude with real-time streaming output
# Usage: run_claude_streaming "prompt" "output_file" [extra_args...]
run_claude_streaming() {
    local prompt=$1
    local output_file=$2
    shift 2
    local extra_args=("$@")

    # Create a temp file to capture exit code (pipes lose it in subshells)
    local exit_code_file
    exit_code_file=$(mktemp)

    if [[ "$CLAUDE_STREAMING" == true ]]; then
        local last_text=""

        # Stream JSON and parse text in real-time
        # Use process substitution to preserve exit code
        {
            echo "$prompt" | claude --dangerously-skip-permissions \
                --output-format stream-json \
                --include-partial-messages \
                --verbose \
                "${extra_args[@]}" 2>&1
            echo $? > "$exit_code_file"
        } | while IFS= read -r line; do
            # Save raw JSON to output file
            echo "$line" >> "$output_file"

            # Extract and display text content incrementally
            if echo "$line" | jq -e '.message.content[0].text' >/dev/null 2>&1; then
                local current_text
                current_text=$(echo "$line" | jq -r '.message.content[0].text // empty' 2>/dev/null)
                if [[ -n "$current_text" && "$current_text" != "$last_text" ]]; then
                    # Print only the new part
                    local new_part="${current_text#$last_text}"
                    echo -n "$new_part"
                    last_text="$current_text"
                fi
            fi
        done
        echo ""  # Final newline
    else
        # Non-streaming fallback
        echo "$prompt" | claude --dangerously-skip-permissions \
            --output-format text \
            "${extra_args[@]}" 2>&1 | tee "$output_file"
        echo $? > "$exit_code_file"
    fi

    local exit_code
    exit_code=$(cat "$exit_code_file" 2>/dev/null || echo "1")
    rm -f "$exit_code_file"

    # Check for various error indicators
    if grep -q '"is_error":true' "$output_file" 2>/dev/null; then
        return 1
    fi
    if grep -q 'No messages returned' "$output_file" 2>/dev/null; then
        return 1
    fi
    if grep -q 'Error:' "$output_file" 2>/dev/null; then
        # Check if it's a real error, not just text containing "Error:"
        if grep -qE '^Error:|UnhandledPromiseRejection|ECONNREFUSED' "$output_file" 2>/dev/null; then
            return 1
        fi
    fi

    return "$exit_code"
}

#-------------------------------------------------------------------------------
# Metrics functions
#-------------------------------------------------------------------------------

# Display metrics from stream-json output
show_phase_metrics() {
    local phase_num=$1
    local json_file=$2
    local lines_added=${3:-0}
    local lines_deleted=${4:-0}

    if [[ ! -f "$json_file" ]] || [[ ! -s "$json_file" ]]; then
        log_verbose "Metrics file not found or empty: $json_file"
        return
    fi

    # Extract metrics from stream-json result line
    local result_line
    result_line=$(grep '"type":"result"' "$json_file" 2>/dev/null | tail -1)

    if [[ -z "$result_line" ]]; then
        log_verbose "No result line found in metrics file"
        return
    fi

    local cost input_tokens output_tokens cache_read cache_creation
    cost=$(echo "$result_line" | jq -r '.total_cost_usd // 0' 2>/dev/null)
    input_tokens=$(echo "$result_line" | jq -r '.usage.input_tokens // 0' 2>/dev/null)
    output_tokens=$(echo "$result_line" | jq -r '.usage.output_tokens // 0' 2>/dev/null)
    cache_read=$(echo "$result_line" | jq -r '.usage.cache_read_input_tokens // 0' 2>/dev/null)
    cache_creation=$(echo "$result_line" | jq -r '.usage.cache_creation_input_tokens // 0' 2>/dev/null)

    # Total context = input + cache (for display purposes)
    local total_input=$((input_tokens + cache_read + cache_creation))

    # Format cost: 2 decimals with comma separator (French format)
    local cost_formatted
    cost_formatted=$(LC_ALL=C printf "%.2f" "$cost" | sed 's/\./,/')

    # Format tokens with K suffix if large
    format_tokens() {
        local tokens=$1
        if [[ $tokens -gt 1000000 ]]; then
            LC_ALL=C awk "BEGIN {printf \"%.1fM\", $tokens / 1000000}"
        elif [[ $tokens -gt 1000 ]]; then
            LC_ALL=C awk "BEGIN {printf \"%.1fK\", $tokens / 1000}"
        else
            echo "$tokens"
        fi
    }

    local input_display=$(format_tokens $total_input)
    local output_display=$(format_tokens $output_tokens)

    # Accumulate metrics for final summary
    TOTAL_COST=$(echo "$TOTAL_COST + $cost" | LC_ALL=C bc -l)
    TOTAL_INPUT_TOKENS=$((TOTAL_INPUT_TOKENS + total_input))
    TOTAL_OUTPUT_TOKENS=$((TOTAL_OUTPUT_TOKENS + output_tokens))
    TOTAL_LINES_ADDED=$((TOTAL_LINES_ADDED + lines_added))
    TOTAL_LINES_DELETED=$((TOTAL_LINES_DELETED + lines_deleted))
    PHASES_COMPLETED=$((PHASES_COMPLETED + 1))

    echo ""
    echo -e "${MAGENTA}┌─── ${BOLD}Phase $phase_num Metrics${NC} ${MAGENTA}───────────────────────────────────────${NC}"
    echo -e "${MAGENTA}│${NC}  Cost:   ${GREEN}\$${cost_formatted}${NC}"
    echo -e "${MAGENTA}│${NC}  Lines:  ${GREEN}+${lines_added}${NC}, ${RED}-${lines_deleted}${NC}"
    echo -e "${MAGENTA}│${NC}  Input:  ${CYAN}${input_display}${NC} tokens"
    echo -e "${MAGENTA}│${NC}  Output: ${CYAN}${output_display}${NC} tokens"
    echo -e "${MAGENTA}└────────────────────────────────────────────────────────${NC}"
}


# Display total metrics summary
show_total_metrics() {
    if [[ "$PHASES_COMPLETED" -eq 0 ]]; then
        return
    fi

    # Format cost: 2 decimals with comma separator (French format)
    local cost_formatted
    cost_formatted=$(LC_ALL=C printf "%.2f" "$TOTAL_COST" | sed 's/\./,/')

    # Format tokens
    format_tokens() {
        local tokens=$1
        if [[ $tokens -gt 1000000 ]]; then
            LC_ALL=C awk "BEGIN {printf \"%.1fM\", $tokens / 1000000}"
        elif [[ $tokens -gt 1000 ]]; then
            LC_ALL=C awk "BEGIN {printf \"%.1fK\", $tokens / 1000}"
        else
            echo "$tokens"
        fi
    }

    local input_display=$(format_tokens $TOTAL_INPUT_TOKENS)
    local output_display=$(format_tokens $TOTAL_OUTPUT_TOKENS)

    echo ""
    echo -e "${CYAN}╔═══ ${BOLD}TOTAL SUMMARY${NC} ${CYAN}($PHASES_COMPLETED phases) ═══════════════════════════════${NC}"
    echo -e "${CYAN}║${NC}  Cost:   ${GREEN}\$${cost_formatted}${NC}"
    echo -e "${CYAN}║${NC}  Lines:  ${GREEN}+${TOTAL_LINES_ADDED}${NC}, ${RED}-${TOTAL_LINES_DELETED}${NC}"
    echo -e "${CYAN}║${NC}  Input:  ${CYAN}${input_display}${NC} tokens"
    echo -e "${CYAN}║${NC}  Output: ${CYAN}${output_display}${NC} tokens"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════${NC}"
}

#-------------------------------------------------------------------------------
# Helper functions
#-------------------------------------------------------------------------------

show_help() {
    head -37 "$0" | tail -34 | sed 's/^# //' | sed 's/^#//'
    exit 0
}

find_latest_plan() {
    local latest=""
    local feature_plan=""
    local implementation_plan=""

    # Search in .claude/feature/*/plan.md (from /resolve workflow)
    if [[ -d "$FEATURE_DIR" ]]; then
        feature_plan=$(find "$FEATURE_DIR" -name "plan.md" -type f 2>/dev/null | while read -r f; do
            echo "$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null) $f"
        done | sort -rn | head -1 | cut -d' ' -f2-)
    fi

    # Search in .claude/implementation/*.md (from /create-plan)
    if [[ -d "$PLAN_DIR" ]]; then
        implementation_plan=$(find "$PLAN_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort -r | head -1)
    fi

    # Prefer feature plan if more recent, otherwise implementation plan
    if [[ -n "$feature_plan" && -n "$implementation_plan" ]]; then
        local feature_time implementation_time
        feature_time=$(stat -c %Y "$feature_plan" 2>/dev/null || stat -f %m "$feature_plan" 2>/dev/null)
        implementation_time=$(stat -c %Y "$implementation_plan" 2>/dev/null || stat -f %m "$implementation_plan" 2>/dev/null)
        if [[ "$feature_time" -ge "$implementation_time" ]]; then
            latest="$feature_plan"
        else
            latest="$implementation_plan"
        fi
    elif [[ -n "$feature_plan" ]]; then
        latest="$feature_plan"
    elif [[ -n "$implementation_plan" ]]; then
        latest="$implementation_plan"
    fi

    if [[ -z "$latest" ]]; then
        log_error "No plan files found"
        log_info "Searched in:"
        log_info "  - $FEATURE_DIR/*/plan.md (from /resolve workflow)"
        log_info "  - $PLAN_DIR/*.md (from /create-plan)"
        log_info ""
        log_info "Create a plan first with:"
        log_info "  /resolve <ticket-id>  - Full ticket workflow"
        log_info "  /create-plan <feature> - Direct plan creation"
        exit 1
    fi

    echo "$latest"
}

# Find plan for a specific feature/ticket ID
find_feature_plan() {
    local feature_id=$1
    local plan_path="$FEATURE_DIR/$feature_id/plan.md"

    if [[ ! -f "$plan_path" ]]; then
        log_error "Plan not found for feature: $feature_id"
        log_info "Expected path: $plan_path"
        log_info ""
        log_info "Create the plan first with: /resolve $feature_id"
        exit 1
    fi

    echo "$plan_path"
}

# Ensure we're not on main/master branch
ensure_feature_branch() {
    local feature_name=$1
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)

    if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
        log_warn "Currently on '$current_branch' branch - creating feature branch..."

        # Generate branch name from feature name
        local branch_name
        if [[ -n "$feature_name" ]]; then
            # Sanitize feature name for branch: lowercase, replace spaces with dashes
            branch_name="feat/$(echo "$feature_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-50)"
        else
            branch_name="feat/implement-$(date +%Y%m%d-%H%M%S)"
        fi

        git checkout -b "$branch_name" || {
            log_error "Failed to create branch '$branch_name'"
            exit 1
        }

        log_success "Created and switched to branch: $branch_name"
    else
        log_info "On branch: $current_branch"
    fi
}

# Extract frontmatter value (returns empty string if not found)
get_frontmatter() {
    local file=$1
    local key=$2
    local result
    # Use || true to prevent pipefail from causing exit
    result=$(sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null | grep "^${key}:" 2>/dev/null | sed "s/^${key}: *//" | tr -d '"' || true)
    echo "$result"
}

# Update frontmatter value (creates frontmatter if not exists)
update_frontmatter() {
    local file=$1
    local key=$2
    local value=$3

    # Check if frontmatter exists
    if head -1 "$file" | grep -q "^---$"; then
        # Frontmatter exists
        if grep -q "^${key}:" "$file"; then
            sed -i "s/^${key}:.*/${key}: ${value}/" "$file"
        else
            # Add after first ---
            sed -i "/^---$/a ${key}: ${value}" "$file"
        fi
    else
        # No frontmatter, create it at the top
        local temp_file
        temp_file=$(mktemp)
        echo "---" > "$temp_file"
        echo "${key}: ${value}" >> "$temp_file"
        echo "---" >> "$temp_file"
        echo "" >> "$temp_file"
        cat "$file" >> "$temp_file"
        mv "$temp_file" "$file"
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

# Get summary of completed phases for context
get_completed_phases_summary() {
    local file=$1
    local current_phase=$2
    local summary=""

    for ((i=1; i<current_phase; i++)); do
        if is_phase_completed "$file" "$i"; then
            local phase_title
            phase_title=$(grep "^## Phase $i:" "$file" | sed 's/## Phase [0-9]*: //' | sed 's/ ✅.*//')
            summary+="- Phase $i ($phase_title): COMPLETED\n"
        fi
    done

    echo -e "$summary"
}

# Run dynamic validation using Claude to detect and execute appropriate tools
run_dynamic_validation() {
    local phase_num=$1
    local plan_file=$2

    if [[ "$NO_VALIDATE" == true ]]; then
        log_info "Skipping validation (--no-validate flag)"
        return 0
    fi

    log_info "Running dynamic validation..."

    local validation_prompt="Phase $phase_num implementation is complete. Now validate the changes.

VALIDATION TASK:
1. Detect available testing/validation tools in this project:
   - Look for: composer.json (phpunit, phpstan), package.json (jest, vitest, eslint), Makefile, etc.
   - Check for existing test commands in README or scripts/

2. Run appropriate validation for the changes made:
   - If PHP: phpstan analyze, phpunit (relevant tests only if identifiable)
   - If JS/TS: eslint, type check, relevant tests
   - If Python: pytest, mypy, ruff
   - If other: appropriate linter/tests

3. Focus on validating the files that were just modified, not the entire codebase.

4. Report validation result clearly at the END of your response:
   - SUCCESS: Output exactly 'VALIDATION_PASSED' on its own line
   - FAILURE: Output exactly 'VALIDATION_FAILED: [brief error description]' on its own line
   - NO TOOLS: Output exactly 'VALIDATION_SKIPPED: no validation tools detected' on its own line

Execute validation now."

    local validation_output
    validation_output=$(mktemp)
    TEMP_FILES+=("$validation_output")

    if ! run_claude_streaming "$validation_prompt" "$validation_output"; then
        log_warn "Validation Claude call failed, skipping validation"
        rm -f "$validation_output"
        return 0  # Don't block on validation failures
    fi

    # Extract text result from JSON output (last result line contains final text)
    local result
    result=$(grep '"type":"result"' "$validation_output" 2>/dev/null | tail -1 | jq -r '.result // empty' 2>/dev/null)
    # Fallback: search in raw output if JSON parsing fails
    if [[ -z "$result" ]]; then
        result=$(tail -20 "$validation_output")
    fi

    if echo "$result" | grep -q "VALIDATION_FAILED"; then
        local error_detail
        error_detail=$(echo "$result" | grep "VALIDATION_FAILED" | head -1)
        log_error "Validation failed: $error_detail"
        rm -f "$validation_output"
        return 1
    elif echo "$result" | grep -q "VALIDATION_PASSED"; then
        log_success "Validation passed"
        rm -f "$validation_output"
        return 0
    elif echo "$result" | grep -q "VALIDATION_SKIPPED"; then
        log_warn "Validation skipped: no tools detected"
        rm -f "$validation_output"
        return 0
    else
        log_warn "Validation result unclear, proceeding anyway"
        rm -f "$validation_output"
        return 0
    fi
}

# Execute git commit (direct git, no custom commands for speed and reliability)
do_commit() {
    local message=$1

    if [[ "$NO_COMMIT" == true ]]; then
        log_info "Skipping commit (--no-commit flag)"
        return 0
    fi

    log_info "Committing changes..."

    git add -A
    git commit -n -m "$message" || {
        log_warn "Nothing to commit or commit failed"
        return 0
    }

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

    # Build context from completed phases
    local context_prefix=""
    if [[ $phase_num -gt 1 ]]; then
        local completed_summary
        completed_summary=$(get_completed_phases_summary "$plan_file" "$phase_num")
        if [[ -n "$completed_summary" ]]; then
            context_prefix="CONTEXT - Previous phases completed:
$completed_summary
"
        fi
    fi

    # Build the base prompt for Claude
    local base_prompt="${context_prefix}You are executing Phase $phase_num of an implementation plan.

Read the plan file at: $plan_file

Execute ONLY Phase $phase_num. Here are the details:

$phase_content

IMPORTANT RULES:
1. Execute ONLY the changes for Phase $phase_num
2. Do NOT modify other phases or jump ahead
3. After making changes, run the validation command if specified
4. Do NOT commit - the orchestrator script handles commits
5. If you encounter an error, stop and explain clearly

Begin implementation of Phase $phase_num now."

    # Build thinking budget option if specified
    local thinking_opt=""
    if [[ -n "$THINKING_BUDGET" ]]; then
        thinking_opt="--thinking-budget $THINKING_BUDGET"
        log_info "Using thinking budget: $THINKING_BUDGET tokens"
    fi

    # Retry loop
    local retry_count=0
    local prompt="$base_prompt"
    local phase_success=false

    while [[ $retry_count -le $MAX_RETRIES ]]; do
        # Execute with Claude
        if [[ $retry_count -eq 0 ]]; then
            log_info "Executing phase $phase_num with Claude..."
        else
            log_warn "Retry attempt $retry_count/$MAX_RETRIES for phase $phase_num..."
        fi
        echo ""

        local exit_code=0
        local output_file
        output_file=$(mktemp)
        TEMP_FILES+=("$output_file")

        # Generate a unique session ID for this phase attempt
        local session_id
        session_id=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "phase-$phase_num-attempt-$retry_count-$(date +%s)")

        # Build extra args
        local -a claude_args=("--session-id" "$session_id")
        if [[ -n "$THINKING_BUDGET" ]]; then
            claude_args+=("--thinking-budget" "$THINKING_BUDGET")
        fi

        # Run Claude with streaming output
        run_claude_streaming "$prompt" "$output_file" "${claude_args[@]}"
        exit_code=$?
        LAST_OUTPUT="$output_file"

        echo ""

        if [[ $exit_code -ne 0 ]]; then
            log_error "Phase $phase_num execution failed with exit code $exit_code"

            retry_count=$((retry_count + 1))
            if [[ $retry_count -le $MAX_RETRIES ]]; then
                log_warn "Waiting ${RETRY_DELAY}s before retry..."
                sleep "$RETRY_DELAY"

                # Build retry prompt with error context
                local error_context
                error_context=$(tail -100 "$output_file" 2>/dev/null || echo "No output captured")
                prompt="RETRY ATTEMPT $retry_count for Phase $phase_num

PREVIOUS ERROR:
The previous attempt failed. Here is the relevant output:
$error_context

INSTRUCTIONS:
1. Analyze what went wrong in the previous attempt
2. Fix the issue
3. Complete the phase requirements
4. Ensure the implementation is correct

Original phase requirements:
$phase_content"
            else
                log_error "Phase $phase_num failed after $MAX_RETRIES retries"
                mark_phase_failed "$plan_file" "$phase_num" "Failed after $MAX_RETRIES retries"
                rm -f "$output_file"
                return 1
            fi
        else
            # Execution succeeded, now run validation
            if ! run_dynamic_validation "$phase_num" "$plan_file"; then
                log_error "Phase $phase_num validation failed"

                retry_count=$((retry_count + 1))
                if [[ $retry_count -le $MAX_RETRIES ]]; then
                    log_warn "Waiting ${RETRY_DELAY}s before retry..."
                    sleep "$RETRY_DELAY"

                    # Build retry prompt with validation failure context
                    prompt="RETRY ATTEMPT $retry_count for Phase $phase_num

PREVIOUS ISSUE:
The implementation was completed but validation FAILED.
Please review and fix the code to pass validation.

INSTRUCTIONS:
1. Review the changes you made
2. Fix any issues that would cause tests/linting to fail
3. Ensure the implementation meets the requirements
4. Make sure the code compiles/passes static analysis

Original phase requirements:
$phase_content"
                else
                    log_error "Phase $phase_num failed validation after $MAX_RETRIES retries"
                    mark_phase_failed "$plan_file" "$phase_num" "Validation failed after $MAX_RETRIES retries"
                    rm -f "$output_file"
                    return 1
                fi
            else
                # Both execution and validation succeeded
                phase_success=true

                # Mark as completed
                mark_phase_completed "$plan_file" "$phase_num"
                log_success "Phase $phase_num completed successfully"

                # Get git diff stats (lines added/deleted)
                # Use HEAD to capture both staged and unstaged changes
                local lines_added=0
                local lines_deleted=0
                local git_stats
                git_stats=$(git diff --shortstat HEAD 2>/dev/null)
                # Fallback to diff without HEAD for new repos or if HEAD fails
                if [[ -z "$git_stats" ]]; then
                    git_stats=$(git diff --shortstat --cached 2>/dev/null)
                fi
                if [[ -z "$git_stats" ]]; then
                    git_stats=$(git diff --shortstat 2>/dev/null)
                fi
                if [[ -n "$git_stats" ]]; then
                    lines_added=$(echo "$git_stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
                    lines_deleted=$(echo "$git_stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
                fi

                # Show metrics from JSON output
                show_phase_metrics "$phase_num" "$output_file" "$lines_added" "$lines_deleted"

                # Cleanup
                rm -f "$output_file"

                # Commit
                do_commit "$commit_msg"

                break
            fi
        fi
    done

    if [[ "$phase_success" == true ]]; then
        return 0
    else
        return 1
    fi
}

run_implementation() {
    local plan_file=$1

    # Validate plan file
    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file not found: $plan_file"
        exit 1
    fi

    log_info "Using plan: $plan_file"

    # Get plan metadata (with fallbacks for missing frontmatter)
    local feature
    feature=$(get_frontmatter "$plan_file" "feature")
    if [[ -z "$feature" ]]; then
        # Try to extract from path: .claude/feature/{ID}/plan.md
        feature=$(echo "$plan_file" | sed -n 's|.*feature/\([^/]*\)/.*|\1|p' || true)
        # Or from FEATURE_ID if provided
        if [[ -z "$feature" && -n "$FEATURE_ID" ]]; then
            feature="$FEATURE_ID"
        fi
        # Final fallback: extract from first H1 heading
        if [[ -z "$feature" ]]; then
            feature=$(grep -m1 "^# " "$plan_file" | sed 's/^# //' | cut -c1-50 || true)
        fi
        log_verbose "Feature extracted from context: $feature"
    fi

    local status
    status=$(get_frontmatter "$plan_file" "status")
    if [[ -z "$status" ]]; then
        status="pending"
        log_verbose "Status defaulting to: $status"
    fi

    local total_phases
    total_phases=$(count_phases "$plan_file")

    # Ensure we're on a feature branch (not main/master)
    ensure_feature_branch "$feature"

    log_info "Feature: ${feature:-unknown}"
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

            # Show total metrics summary
            show_total_metrics

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
            show_total_metrics
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
            -f|--feature)
                FEATURE_ID="$2"
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
            --no-validate)
                NO_VALIDATE=true
                shift
                ;;
            --max-retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            --retry-delay)
                RETRY_DELAY="$2"
                shift 2
                ;;
            --thinking-budget)
                THINKING_BUDGET="$2"
                shift 2
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

    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Install it with: sudo apt install jq"
        exit 1
    fi

    if ! command -v bc &> /dev/null; then
        log_error "bc not found. Install it with: sudo apt install bc"
        exit 1
    fi


    if ! git rev-parse --git-dir &> /dev/null; then
        log_error "Not in a git repository"
        exit 1
    fi
    
    # Find or validate plan file
    if [[ -n "$FEATURE_ID" ]]; then
        # Use --feature flag: look in .claude/feature/{id}/plan.md
        PLAN_FILE=$(find_feature_plan "$FEATURE_ID")
    elif [[ -z "$PLAN_FILE" ]]; then
        # Auto-detect: search both directories
        PLAN_FILE=$(find_latest_plan)
    fi
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     SOLO-IMPLEMENT.SH - Automated Phase Orchestrator      ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    run_implementation "$PLAN_FILE"
}

main "$@"
