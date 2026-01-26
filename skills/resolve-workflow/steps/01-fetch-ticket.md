---
name: fetch-ticket
description: Retrieve ticket from source, extract Figma URLs, collect user context
order: 1

skip_if:
  - flag: "--continue"
  - flag: "--refine-plan"

next:
  default: analyze-complexity

tools:
  - Read
  - Write
  - Bash
  - Task
  - AskUserQuestion
  - mcp__youtrack__get_issue
  - mcp__youtrack__get_issue_comments
  - mcp__youtrack__get_issue_attachments
  - mcp__figma-screenshot__figma_screenshot
---

# Step: Fetch Ticket

<context>
This step retrieves the ticket from the configured source (YouTrack, GitHub, or file),
extracts Figma URLs for visual verification, and optionally collects additional user context.
</context>

## Instructions

<instructions>

### 0. Check Completion Status

**IMPORTANT**: Read `.claude/feature/{ticket-id}/status.json` and check:
- If `phases.fetch == "completed"`: Skip to next step (analyze-complexity)
- Otherwise: Continue with instructions below

### 1. Fetch Ticket Content

Apply skill: `~/.claude/skills/fetch-ticket/SKILL.md`

- Detect source from ticket ID pattern
- Retrieve ticket via MCP (YouTrack) or gh CLI (GitHub)
- Save to `.claude/feature/{ticket-id}/ticket.md`

### 1.5. Update Base Branch from Ticket (CRITICAL)

**IMPORTANT**: After fetching the ticket, extract the target branch and UPDATE `status.json`:

1. **Parse ticket.md** for Target Branch in metadata table:
   ```markdown
   | Target Branch | 2025-12 |
   ```

2. **If Target Branch found AND different from current base_branch**:
   ```bash
   # Read current status
   STATUS=$(cat .claude/feature/{ticket-id}/status.json)

   # Update base_branch with value from ticket
   jq '.options.base_branch = "{target-branch-from-ticket}"' <<< "$STATUS" > .claude/feature/{ticket-id}/status.json
   ```

3. **Log the change** (if updated):
   ```
   Base branch mise a jour: main -> 2025-12 (depuis milestone du ticket)
   ```

This ensures git diff operations throughout the workflow use the correct branch from the ticket's milestone, not the default from initialization.

### 2. Extract Figma URLs

Parse ticket content (description + comments) for Figma URLs:

**Pattern**: `https://www.figma.com/(file|design|proto|board)/[A-Za-z0-9]+/.*node-id=[\d-]+`

If URLs found, store in `status.json`:
```json
{
  "figma_urls": ["url1", "url2"]
}
```

### 3. Handle Figma URLs (INTERACTIVE only)

**IMPORTANT**: In INTERACTIVE mode, ALWAYS ask about Figma URLs, even if some were found in the ticket.

#### 3.1 If URLs found in ticket:

```yaml
AskUserQuestion:
  question: "{N} lien(s) Figma trouve(s) dans le ticket. Voulez-vous en ajouter d'autres ?"
  header: "Figma"
  options:
    - label: "Non, c'est complet"
      description: "Utiliser uniquement les liens du ticket"
    - label: "Oui, j'en ajoute"
      description: "Fournir des URLs Figma supplementaires"
    - label: "Non, pas de verification visuelle"
      description: "Desactiver la verification Figma pour ce ticket"
```

#### 3.2 If NO URLs found in ticket:

```yaml
AskUserQuestion:
  question: "Aucun lien Figma trouve dans le ticket. Y a-t-il des ecrans Figma a verifier ?"
  header: "Figma"
  options:
    - label: "Oui, je fournis les liens"
      description: "Saisir les URLs Figma pour verification visuelle"
    - label: "Non, pas de verification"
      description: "Continuer sans verification visuelle"
```

If user provides URLs, add them to `status.json`.

### 3.5 Pre-fetch Figma Screenshots (if URLs available)

**IMPORTANT**: Download and save Figma screenshots NOW for later comparison.

```bash
mkdir -p .claude/feature/{ticket-id}/figma
```

For each Figma URL:

```yaml
mcp__figma-screenshot__figma_screenshot:
  url: "{figma_url}"
  scale: 1
```

**Save screenshot** to `.claude/feature/{ticket-id}/figma/design-{N}.png`

Update `status.json`:
```json
{
  "figma_urls": ["url1", "url2"],
  "figma_screenshots": [
    { "url": "url1", "path": ".claude/feature/{ticket-id}/figma/design-1.png" },
    { "url": "url2", "path": ".claude/feature/{ticket-id}/figma/design-2.png" }
  ]
}
```

This ensures designs are captured BEFORE implementation and can be reused without re-fetching.

### 4. Add User Context (INTERACTIVE only)

Offer opportunity to provide additional context:

```yaml
AskUserQuestion:
  question: "Voulez-vous ajouter du contexte supplementaire pour ce ticket ?"
  header: "Context"
  options:
    - label: "Oui, j'ai des precisions"
      description: "Ajouter des commentaires, contraintes ou clarifications"
    - label: "Non, continuer"
      description: "Le ticket est suffisamment clair"
```

If user adds context:
1. Store in `status.json` as `user_context`
2. Append to `ticket.md`:
   ```markdown
   ---

   ## Additional Context (User Provided)

   {user_context}
   ```

</instructions>

## Output

<output>
- File: `.claude/feature/{ticket-id}/ticket.md`
- Directory: `.claude/feature/{ticket-id}/figma/` (if Figma URLs available)
- Files: `.claude/feature/{ticket-id}/figma/design-{N}.png` (pre-saved screenshots)
- Status: `phases.fetch = "completed"`
- Status fields: `figma_urls[]`, `figma_screenshots[]`, `user_context`
</output>

## Auto Behavior

<auto_behavior>
- Skip Figma URL prompt (use URLs found in ticket, if any)
- Skip user context prompt
- Still pre-fetch Figma screenshots if URLs are available
</auto_behavior>

## Interactive Behavior

<interactive_behavior>
- ALWAYS prompt about Figma URLs (even if some found in ticket)
- Allow user to add additional Figma URLs
- Prompt for additional user context
- Pre-fetch and save Figma screenshots before continuing
</interactive_behavior>

## Context Types

<example>
Types of context the user might provide:
- Technical constraints not mentioned in the ticket
- Preferred implementation approach
- Related code areas to check
- Edge cases to consider
- Business rules clarifications
- Dependencies or blockers
- Links to documentation or examples
</example>
