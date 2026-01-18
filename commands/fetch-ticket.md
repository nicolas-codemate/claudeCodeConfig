---
description: Fetch PR comments and update code based on unresolved feedback
argument-hint: <ticket-id> [--source youtrack|github]
allowed-tools: Read, Glob, Bash, Write, mcp__youtrack__get_issue, mcp__youtrack__get_issue_comments, mcp__youtrack__get_issue_attachments
---

# FETCH-TICKET - Retrieve Ticket Information

Standalone command to fetch and save a ticket from YouTrack or GitHub.

## Input

```
$ARGUMENTS
```

Parse:
- `ticket_id`: Required - the ticket identifier
- `--source`: Optional - force source (youtrack, github)

---

## STEP 1: LOAD SKILL

Read and apply the fetch-ticket skill from `~/.claude/skills/fetch-ticket/SKILL.md`.

---

## STEP 2: DETECT SOURCE

If `--source` provided, use it.

Otherwise detect from pattern:
- `^[A-Z]+-\d+$` → YouTrack (e.g., PROJ-123)
- `^#?\d+$` → GitHub (e.g., #456 or 456)
- `^[\w-]+/[\w-]+#\d+$` → GitHub with repo (e.g., owner/repo#123)

---

## STEP 3: FETCH TICKET

### YouTrack

```
mcp__youtrack__get_issue(issueId: {ticket-id})
mcp__youtrack__get_issue_comments(issueId: {ticket-id})
```

Extract:
- summary → Title
- description → Description
- state.name → Status
- priority.name → Priority
- type.name → Type
- assignee.fullName → Assignee
- tags[].name → Labels

### GitHub

```bash
gh issue view {number} --json title,body,state,labels,assignees,comments,url
```

If fails (not an issue), try PR:
```bash
gh pr view {number} --json title,body,state,labels,assignees,comments,url
```

---

## STEP 4: FORMAT OUTPUT

Create normalized markdown:

```markdown
---
source: {youtrack|github}
ticket_id: {ticket-id}
fetched_at: {ISO timestamp}
url: {ticket URL}
---

# {Ticket Title}

## Metadata

| Field | Value |
|-------|-------|
| Status | {status} |
| Type | {type} |
| Priority | {priority} |
| Assignee | {assignee} |
| Labels | {labels} |

## Description

{Original ticket description}

## Comments

### Comment by {author} ({date})

{Comment content}

---
```

---

## STEP 5: SAVE AND OUTPUT

### Option A: Part of /resolve workflow
Save to `.claude/feature/{ticket-id}/ticket.md`

### Option B: Standalone use
Display the formatted ticket content directly to user.

If `.claude/feature/{ticket-id}/` exists, also save there.

---

## ERROR HANDLING

### YouTrack MCP Unavailable
```
Error: YouTrack MCP server not available.

Ensure the YouTrack MCP server is configured in your Claude settings.
Check: ~/.claude/settings.json for MCP configuration.
```

### GitHub CLI Not Authenticated
```
Error: GitHub CLI not authenticated.

Run: gh auth login
```

### Ticket Not Found
```
Error: Ticket {ticket-id} not found.

- Verify the ticket ID is correct
- Check you have access to this ticket
- For YouTrack: Ensure project prefix is correct
- For GitHub: Ensure repository is accessible
```

---

## LANGUAGE

User messages in French.
Ticket content preserved in original language.

---

## NOW

Fetch ticket: `$ARGUMENTS`
