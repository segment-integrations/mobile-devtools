---
name: gh
description: GitHub CLI for managing PRs, repos, issues, and labels from command line. Used by pr and pr-review skills for PR operations.
argument-hint: [command | pr-number | repo]
disable-model-invocation: false
allowed-tools: Bash(gh *)
---

# GitHub CLI (gh)

## Overview

GitHub CLI brings GitHub to the command line. Manage pull requests, issues, repos, and labels without leaving terminal.

## Core Commands

### pr - Pull Requests

List PRs:
```bash
gh pr list                              # List PRs in current repo
gh pr list --state open                 # Open PRs only
gh pr list --state closed               # Closed PRs
gh pr list --state merged               # Merged PRs
gh pr list --author @me                 # Your PRs
gh pr list --label bug                  # PRs with label
```

View PR:
```bash
gh pr view <number>                     # View PR details
gh pr view <number> --web               # Open in browser
gh pr view <number> --json title,body,files,additions,deletions
```

Create PR:
```bash
gh pr create --draft --title "title" --body "body"
gh pr create --draft --title "title" --body-file pr.md
gh pr create --draft --title "title" --label "feature,bug"
gh pr create --base main --head feature-branch
gh pr create --fill                     # Autofill from commits
```

FLAGS:
- --draft / -d: Create as draft
- --title / -t: PR title
- --body / -b: PR body (inline)
- --body-file / -F: Read body from file (use "-" for stdin)
- --label / -l: Add labels (comma-separated)
- --base / -B: Base branch (default: repo default branch)
- --head / -H: Head branch (default: current branch)
- --fill / -f: Autofill title/body from commits
- --web / -w: Open browser to create

Edit PR:
```bash
gh pr edit <number> --title "new title"
gh pr edit <number> --body "new body"
gh pr edit <number> --body-file new.md
gh pr edit <number> --add-label "feature"
gh pr edit <number> --remove-label "bug"
gh pr edit <number> --base main
```

FLAGS:
- --title / -t: Change title
- --body / -b: Change body
- --body-file / -F: Read body from file
- --add-label: Add labels (comma-separated)
- --remove-label: Remove labels (comma-separated)
- --base / -B: Change base branch

Mark ready:
```bash
gh pr ready <number>                    # Mark draft as ready
gh pr ready <number> --undo             # Convert back to draft
```

Diff PR:
```bash
gh pr diff <number>                     # Show diff
gh pr diff <number> --stat              # Show stat summary
gh pr diff <number> --patch             # Show patch format
```

Check PR status:
```bash
gh pr checks <number>                   # Show CI checks
gh pr status                            # Show relevant PRs
```

Merge PR:
```bash
gh pr merge <number>                    # Interactive merge
gh pr merge <number> --merge            # Create merge commit
gh pr merge <number> --squash           # Squash commits
gh pr merge <number> --rebase           # Rebase commits
gh pr merge <number> --delete-branch    # Delete after merge
```

Close/reopen PR:
```bash
gh pr close <number>
gh pr reopen <number>
```

Comment on PR:
```bash
gh pr comment <number> --body "comment text"
gh pr comment <number> --body-file comment.md
```

Checkout PR:
```bash
gh pr checkout <number>                 # Checkout PR branch locally
```

### repo - Repositories

View repo:
```bash
gh repo view                            # View current repo
gh repo view owner/repo                 # View specific repo
gh repo view --web                      # Open in browser
```

Clone repo:
```bash
gh repo clone owner/repo                # Clone repo
gh repo clone owner/repo path           # Clone to path
```

Create repo:
```bash
gh repo create name                     # Create in current account
gh repo create org/name                 # Create in org
gh repo create --private                # Private repo
gh repo create --public                 # Public repo
```

Fork repo:
```bash
gh repo fork                            # Fork current repo
gh repo fork owner/repo                 # Fork specific repo
gh repo fork --clone                    # Fork and clone
```

List repos:
```bash
gh repo list                            # List your repos
gh repo list owner                      # List owner's repos
gh repo list --limit 50                 # Limit results
```

### issue - Issues

List issues:
```bash
gh issue list                           # List issues
gh issue list --state open              # Open issues
gh issue list --state closed            # Closed issues
gh issue list --author @me              # Your issues
gh issue list --label bug               # Issues with label
```

View issue:
```bash
gh issue view <number>                  # View issue
gh issue view <number> --web            # Open in browser
```

Create issue:
```bash
gh issue create --title "title" --body "body"
gh issue create --title "title" --label "bug,enhancement"
```

Close/reopen issue:
```bash
gh issue close <number>
gh issue reopen <number>
```

Comment on issue:
```bash
gh issue comment <number> --body "comment"
```

### label - Labels

List labels:
```bash
gh label list                           # List all labels
gh label list --limit 100               # Limit results
```

Create label:
```bash
gh label create "name" --description "desc" --color "ff0000"
```

Edit label:
```bash
gh label edit "name" --name "new-name"
gh label edit "name" --description "new desc"
gh label edit "name" --color "00ff00"
```

Delete label:
```bash
gh label delete "name"
```

Clone labels:
```bash
gh label clone source-owner/source-repo
```

### api - Direct API Access

Make API request:
```bash
gh api repos/:owner/:repo/pulls/<number>
gh api repos/:owner/:repo/pulls/<number>/comments
gh api -X POST repos/:owner/:repo/issues -f title="title" -f body="body"
```

## Common Workflows

### Create PR from Current Branch

```bash
# Check branch and changes
git status
git diff --stat

# Push branch
git push -u origin $(git branch --show-current)

# Create PR
gh pr create --draft \
  --title "feat: add feature" \
  --body "$(cat <<'EOF'
## Summary
Description

## Changes
- Change 1
- Change 2
EOF
)" \
  --label "feature"

# Mark ready when done
gh pr ready <number>
gh pr edit <number> --add-label "needs-review"
```

### Update PR Description

```bash
# Get current PR info
gh pr view <number> --json title,body

# Update description
gh pr edit <number> --body "$(cat <<'EOF'
## Summary
Updated description
EOF
)"
```

### Check PR Before Merge

```bash
# View PR details
gh pr view <number>

# Check CI status
gh pr checks <number>

# View diff
gh pr diff <number> --stat

# Merge if all good
gh pr merge <number> --squash --delete-branch
```

### Create Labels for New Repo

```bash
# Create type labels
gh label create "feature" --description "New functionality" --color "0e8a16"
gh label create "bug" --description "Bug fix" --color "d73a4a"
gh label create "chore" --description "Maintenance" --color "fef2c0"

# Create status labels
gh label create "needs-review" --description "Ready for review" --color "28a745"

# Create series labels
for i in {1..9}; do
  gh label create "series-$i" --description "Part $i of series" --color "8B5CF6"
done
```

### Clone Repo and Create PR

```bash
# Clone repo
gh repo clone owner/repo
cd repo

# Create branch and make changes
git checkout -b feature-branch
# ... make changes ...
git commit -m "feat: add feature"

# Push and create PR
git push -u origin feature-branch
gh pr create --fill
```

## Output Formats

### JSON Output

Many commands support `--json` flag:

```bash
gh pr view <number> --json title,body,state,number,url
gh pr list --json number,title,author,state
gh repo view --json name,owner,description
```

Parse with jq:
```bash
gh pr view <number> --json additions,deletions -q '.additions + .deletions'
gh pr list --json number,title -q '.[] | "\(.number): \(.title)"'
```

### Template Output

Use `--template` for custom formatting:

```bash
gh pr list --template '{{range .}}{{.number}}: {{.title}}{{"\n"}}{{end}}'
```

## Configuration

View config:
```bash
gh config list
gh config get git_protocol
```

Set config:
```bash
gh config set git_protocol ssh
gh config set editor vim
gh config set pager less
```

## Authentication

Login:
```bash
gh auth login                           # Interactive login
gh auth login --with-token < token.txt  # Login with token
```

Check auth status:
```bash
gh auth status
```

Refresh auth:
```bash
gh auth refresh                         # Refresh token
gh auth refresh -s project              # Add project scope
```

## Repository Context

All commands use current repo by default. Override with `--repo` flag:

```bash
gh pr list --repo owner/repo
gh issue create --repo owner/repo --title "title"
```

## Argument Formats

PR/Issue numbers:
- By number: `123`
- By URL: `https://github.com/owner/repo/pull/123`
- By branch: `feature-branch`

Repo format:
- `owner/repo`
- `https://github.com/owner/repo`

## Environment Variables

- `GH_TOKEN`: GitHub token for authentication
- `GH_REPO`: Default repo (format: owner/repo)
- `GH_EDITOR`: Editor for interactive prompts
- `GH_PAGER`: Pager for command output
- `GH_BROWSER`: Browser for `--web` flag

## Quick Reference

| Task | Command |
|------|---------|
| List PRs | `gh pr list` |
| View PR | `gh pr view <number>` |
| Create PR | `gh pr create --draft --title "..." --body "..."` |
| Edit PR | `gh pr edit <number> --title "..."` |
| Mark ready | `gh pr ready <number>` |
| PR diff | `gh pr diff <number>` |
| Merge PR | `gh pr merge <number>` |
| List issues | `gh issue list` |
| Create issue | `gh issue create --title "..." --body "..."` |
| List labels | `gh label list` |
| Create label | `gh label create "name" --color "hex"` |
| Clone repo | `gh repo clone owner/repo` |
| View repo | `gh repo view` |
| API request | `gh api <endpoint>` |
| Auth status | `gh auth status` |

## Integration with Other Skills

**pr skill:** Uses gh CLI for creating and updating PRs. Primary commands: `gh pr create`, `gh pr edit`, `gh pr ready`, `gh label create`.

**pr-review skill:** Uses gh CLI for fetching PR details and diffs. Primary commands: `gh pr view`, `gh pr diff`, `gh pr checks`.

**git-town skill:** Works with git branches. gh CLI handles GitHub operations (PR creation, labels, merging).

## Common Patterns

### Inline vs File Body

Inline (short):
```bash
gh pr create --draft --title "title" --body "Short description"
```

File (long):
```bash
gh pr create --draft --title "title" --body-file description.md
```

Heredoc (medium):
```bash
gh pr create --draft --title "title" --body "$(cat <<'EOF'
Multi-line
description
EOF
)"
```

### Conditional PR Operations

Check before creating:
```bash
# Check if PR exists for current branch
if gh pr view --json number >/dev/null 2>&1; then
  echo "PR already exists"
  gh pr view --web
else
  gh pr create --draft
fi
```

### Batch Operations

Label multiple PRs:
```bash
for pr in 123 124 125; do
  gh pr edit "$pr" --add-label "needs-review"
done
```

## Error Handling

Common errors and fixes:

**Not logged in:**
```bash
gh auth login
```

**No permission:**
```bash
gh auth refresh -s repo  # Request repo scope
```

**PR not found:**
- Verify PR number
- Check if using correct repo (--repo flag)

**Rate limit:**
- Wait for reset
- Use authenticated requests (faster rate limit)

## Tips

1. Use `--json` for scripting and parsing
2. Use `--web` to quickly open in browser
3. Use `@me` to reference yourself
4. Use `--draft` by default, mark ready later
5. Use heredoc for multi-line bodies
6. Store token in `GH_TOKEN` for CI/CD
7. Use `--repo` to work across repos
8. Check `gh pr status` for overview
