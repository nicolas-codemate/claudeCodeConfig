---
description: "Read PR comments and update code based on unresolved feedback"
allowed-tools: Bash(gh:*), Bash(git:*)
argument-hint: "[pr-number]"
---

# Analyze Pull Request Comments and Update Code

Read all comments from the current PR (or specified PR number), identify unresolved feedback, and implement the requested changes in a single commit.

## Context Commands
- Current branch: !`git branch --show-current`
- Current git status: !`git status --porcelain`
- PR information: !`gh pr view $ARGUMENTS --json number,title,url,headRefName`

## Instructions

### Step 1: Fetch PR Information
1. If no PR number is provided in $ARGUMENTS, determine the current PR number for this branch using:
   ```bash
   gh pr list --head $(git branch --show-current) --json number --jq '.[0].number'
   ```
2. If a PR number is provided in $ARGUMENTS, use that number

### Step 2: Analyze PR Comments
1. Fetch all review comments and discussions:
   ```bash
   gh pr view [PR_NUMBER] --json reviews,comments
   ```
2. Get the detailed review comments:
   ```bash
   gh api repos/:owner/:repo/pulls/[PR_NUMBER]/reviews --paginate
   gh api repos/:owner/:repo/pulls/[PR_NUMBER]/comments --paginate
   ```

3.Identify comments that:
- Request code changes
- Point out bugs or issues
- Suggest improvements
- Are not marked as resolved
- Don't have "LGTM" or approval indicators in subsequent responses
   
### Step 3: Categorize Feedback
Organize the unresolved comments by:
- **Critical Issues**: Bugs, security concerns, breaking changes
- **Code Quality**: Refactoring suggestions, best practices
- **Style/Convention**: Formatting, naming, documentation
- **Performance**: Optimization suggestions
- **Feature Requests**: Additional functionality suggestions

### Step 4: Implement Changes
For each unresolved comment:
1. **Read the relevant file(s)** mentioned in the comment
2. **Understand the context** around the commented code
3. **Implement the requested change** or fix the identified issue
4. **Verify the change** makes sense in the broader codebase context
5. **Add any necessary tests** if the change affects functionality

### Step 5: Summary Report
Provide a summary including:
- Number of comments analyzed
- Number of comments addressed
- List of files modified
- Any comments that couldn't be addressed (with reasons)
- Recommendations for follow-up actions
