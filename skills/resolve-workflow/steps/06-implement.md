---
name: implement
description: Execute implementation plan phase by phase with visual verification
order: 6

next:
  default: simplify
  conditions:
    - if: "flag == '--skip-simplify'"
      then: review

tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
  - AskUserQuestion
  - mcp__figma-screenshot__figma_screenshot
---

# Step: Implement

<context>
This step executes the implementation plan phase by phase. Each phase includes
code changes, validation, and optional visual verification against Figma designs.
</context>

## Instructions

<instructions>

### 0. Check Completion Status

**IMPORTANT**: Read `.claude/feature/{ticket-id}/status.json` and check:
- If `phases.implement == "completed"` or `state == "implemented"`: Skip to next step (simplify)
- Otherwise: Continue with instructions below

### 1. Execute /compact (if not already done)

Clear context before implementation to maximize available context for code changes.

### 2. Load Plan

**CRITICAL**: Read the plan from the project's feature directory:
```
.claude/feature/{ticket-id}/plan.md
```
Do NOT use `docs/plan.md` or any other location.

Parse frontmatter for:
- `total_phases`
- `ticket_id`

If the file doesn't exist, ERROR with:
"Plan not found at .claude/feature/{ticket-id}/plan.md. Run /resolve {ticket-id} first to create the plan."

### 3. Implement Each Phase

For each phase in the plan:

#### 3.1 Read Phase Details

- Goal
- Files to modify/create
- Implementation details
- Validation command
- Commit message

#### 3.2 Implement Changes

Execute the implementation as described in the phase.

#### 3.3 Run Validation

Execute the validation command if specified:
```bash
{validation command from plan}
```

#### 3.4 Visual Verification (AUTOMATIC when applicable)

<visual_verification_rule>
**CRITICAL**: Visual verification MUST run automatically when ALL conditions are met:
1. `--skip-visual-verify` flag is NOT set
2. `figma_urls` OR `figma_screenshots` exist in status.json
3. Frontend files were modified in current implementation

**DO NOT** wait for user to request it - trigger it automatically.
</visual_verification_rule>

**Step 3.4.1 - Check for frontend changes**:
```bash
# Use base branch from status.json - NEVER use HEAD~1 or hardcoded branch names
BASE_BRANCH=$(cat .claude/feature/{ticket-id}/status.json | jq -r '.options.base_branch')
FRONTEND_CHANGES=$(git diff --name-only ${BASE_BRANCH}...HEAD | grep -E '\.(vue|tsx|jsx|css|scss|less|html)$' | wc -l)
```

**Step 3.4.2 - Check for Figma designs**:
```bash
FIGMA_COUNT=$(cat .claude/feature/{ticket-id}/status.json | jq -r '.figma_urls | length // 0')
```

**Step 3.4.3 - Trigger visual verification if applicable**:

```
if FRONTEND_CHANGES > 0 AND FIGMA_COUNT > 0:
    → MUST run visual verification
    → Log: "Verification visuelle: {FRONTEND_CHANGES} fichiers front modifies, {FIGMA_COUNT} designs Figma disponibles"
else:
    → Skip visual verification
    → Log reason: "Skip visual verify: {reason}"
```

**If verification is triggered**, use pre-saved screenshots when available:

```yaml
Task:
  subagent_type: visual-verify
  prompt: |
    Compare Figma designs with browser render.

    ## Pre-saved Figma Screenshots
    Check for existing screenshots in: .claude/feature/{ticket-id}/figma/
    If screenshots exist, use them as reference (avoid re-fetching).
    If not, fetch from URLs.

    ## Figma URLs (for reference/re-fetch if needed)
    {figma_urls from status.json}

    ## Configuration
    Base URL: {config.visual_verify.base_url or "http://localhost:5173"}

    ## Context
    Phase: {N} - {phase description}
    Ticket: {ticket-id}
    Frontend files modified: {list of files}

    ## Instructions
    1. Load pre-saved Figma screenshots from .claude/feature/{ticket-id}/figma/
    2. Navigate browser to matching screens
    3. Compare and score each screen
    4. Save report to .claude/feature/{ticket-id}/visual-report.md
```

**Handle results**:

| Status | AUTO Mode | INTERACTIVE Mode |
|--------|-----------|------------------|
| pass | Continue | Continue |
| needs_attention | Log warning, continue | Ask user |
| fail | Log warning in PR | Ask user to fix |
| skipped | Continue | Continue |

**INTERACTIVE - on needs_attention or fail**:

```yaml
AskUserQuestion:
  question: "Des ecarts visuels detectes (score: {score}/5). Que faire ?"
  header: "Visual"
  options:
    - label: "Voir le rapport"
      description: "Afficher le rapport detaille"
    - label: "Corriger maintenant"
      description: "Appliquer les corrections"
    - label: "Ignorer et continuer"
      description: "Sera note dans la PR"
```

#### 3.5 Commit Changes (if configured)

Using the commit message from the plan (unless user manages commits manually).

#### 3.6 Store Visual Warnings

If visual issues found, store in status.json for PR body:
```json
{
  "visual_warnings": [
    { "screen": "...", "score": 3, "report": "path/to/report" }
  ]
}
```

### 4. Update Status

After all phases complete:
- `phases.implement = "completed"`
- `state = "implemented"`

</instructions>

## Output

<output>
- Code changes implemented according to plan
- Commits created (if configured)
- Status: `phases.implement = "completed"`, `state = "implemented"`
- Optional: `visual_warnings[]` in status.json
</output>

## Auto Behavior

<auto_behavior>
- Implement all phases without user interaction
- Log visual warnings for PR body
- Continue on non-critical issues
</auto_behavior>

## Interactive Behavior

<interactive_behavior>
- Show progress for each phase
- Prompt on visual verification issues
- Allow user to decide on corrections
</interactive_behavior>

## Large Epic Note

<constraints>
For very large epics with many phases, use `--plan-only` flag and run
`solo-implement.sh` separately. This launches each phase in its own
Claude session with fresh context.
</constraints>
