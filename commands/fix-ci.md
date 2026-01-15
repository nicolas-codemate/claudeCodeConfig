---
description: Automatically fix CI failures on current branch by running failing tests locally
argument-hint: [branch-name (optional, defaults to current branch)]
---

# Fix CI Failures Workflow

You are tasked with automating the CI failure resolution workflow. Follow these steps:

## Step 1: Find and Analyze PR
1. First, get the current branch name using: `git branch --show-current`
2. Use GitHub MCP to find the PR for the specified branch (default: current branch) or with `gh` CLI.
2. Get the PR details including CI status and checks
3. Identify which CI jobs have failed

## Step 2: Extract Failed Tests from CI Logs  
For each failed CI job:
1. Fetch the CI logs using GitHub API: use `gh run view xxx --log`. The log could be very long grep for `FAILURES`, `ERRORS`, `Exception`, `Fatal`, `Failed`, etc.
2. Focus on the **end of the logs** where error summaries are typically located
3. Look for failed PHPUnit tests (pattern: `FAILURES!` or `Tests: X, Assertions: Y, Failures: Z`)
4. Look for failed Behat scenarios (pattern: `--- Failed scenarios:` or similar)
5. Extract the exact test class/method names and Behat scenario paths

## Step 3: Run Tests Locally
1. Check for `compose.yaml` or `docker-compose.yaml` for PHP container
2. Check `Makefile` for existing test commands
3. Run the specific failing tests using:
   - Docker: `docker compose exec php php bin/phpunit --filter TestClassName::testMethod`
   - Makefile: Use existing test targets if available
   - For Behat: `docker compose exec php php bin/behat path/to/feature.feature:line`

## Step 4: Analyze and Fix
1. Analyze the local test output to understand the root cause
2. Identify the files that need to be modified
3. Make the necessary fixes following the existing code patterns
4. Re-run the tests locally to verify the fix

## Step 5: Commit
1. Create a single commit with all fixes
2. Use descriptive commit message: "fix: resolve CI failures for [test names]"
3. DO NOT modify unrelated code
4. Follow the established coding standards

## Important Notes
- Focus ONLY on the failing tests identified from CI logs
- Don't fix unrelated issues unless explicitly asked
- Use Docker commands since PHP is not installed locally
- Always verify fixes work locally before committing
- Keep the commit scope minimal and focused

Begin by getting the current branch name if no branch is provided, then execute this workflow step by step.
