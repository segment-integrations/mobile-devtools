---
name: pr
description: Create or update pull requests with standardized format. Default: create PR from current branch (commits uncommitted changes first). Accepts PR number/link to update existing. Flexible parameters (path, repo, branch).
argument-hint: [pr-number | pr-url | branch | path | empty]
disable-model-invocation: false
allowed-tools: Bash(gh pr *) Bash(git *) Read Grep
---

# Pull Request Management

## Overview

Create or update PRs with standardized format. See git-town skill for stacked branch management.

## Default Behavior (No Arguments)

Creates PR from current branch:

Steps:
1. Check git status for uncommitted changes
2. Commit uncommitted changes if present (ask user for message or generate from diff)
3. Push current branch to origin
4. Create draft PR with formatted description
5. Apply appropriate labels
6. Return PR URL

```bash
/pr                    # Create PR from current branch
```

## Update Existing PR

Accepts PR number or URL:

```bash
/pr 123                                    # Update PR #123
/pr https://github.com/org/repo/pull/123  # Update via URL
```

Steps:
1. Fetch PR details via gh
2. Get current diff
3. Generate/update description matching changes
4. Update PR description
5. Verify labels are correct

## Flexible Parameters

Accepts various parameter formats:

```bash
/pr                           # Current branch → new PR
/pr feature-branch            # Specific branch → new PR
/pr 123                       # Update PR #123
/pr org/repo#123              # Update PR in different repo
/pr https://...               # Update via URL
/pr ../other-project          # Create PR from path
/pr ../other-project feat     # Create PR from path + branch
```

Parameter resolution:
- Number: PR number in current repo
- URL: Parse org/repo/number from GitHub URL
- org/repo#N: Explicit repo + PR number
- Branch name: Create PR from that branch
- Path: cd to path, use current branch
- Path + branch: cd to path, use specified branch

## PR Description Format

```markdown
## Summary
[1-2 sentences]

## Changes
- Key change 1
- Key change 2
- Key change 3

## Why
[Brief explanation]

## Stack (if series)
- Part 1: [Title](#PR_NUMBER)
- **→ Part 2: [Title](#PR_NUMBER) (this PR)**
- Part 3: [Title](#PR_NUMBER)

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Size Guidelines

**Targets:**
- Ideal: 400 lines per PR
- Single PR max: 1200 lines (if focused, no scope creep)
- Series PR max: 800 lines per PR

**When to split:**
- Single PR: Keep together if <1200 lines AND single focused feature/fix
- Series: Required if >1200 lines OR scope is unfocused

## Labels

**Type (one required):**
- `feature` - New functionality (#0e8a16 green)
- `bug` - Bug fix (#d73a4a red)
- `chore` - Maintenance/tooling (#fef2c0 cream)
- `refactor` - Code refactoring (#fbca04 yellow)
- `documentation` - Docs only (#0075ca blue)

**Status:**
- `needs-review` - Ready for review (#28a745 bright green)

**Series:**
- `series-1` through `series-9` - PR stack ordering (#8B5CF6 purple)

Auto-create missing labels:
```bash
gh label create "feature" --description "New feature or functionality" --color "0e8a16" 2>/dev/null || true
gh label create "bug" --description "Bug fix" --color "d73a4a" 2>/dev/null || true
gh label create "chore" --description "Maintenance, dependencies, tooling" --color "fef2c0" 2>/dev/null || true
gh label create "refactor" --description "Code refactoring, no functional changes" --color "fbca04" 2>/dev/null || true
gh label create "documentation" --description "Documentation only changes" --color "0075ca" 2>/dev/null || true
gh label create "needs-review" --description "Ready for review" --color "28a745" 2>/dev/null || true
for i in {1..9}; do
  gh label create "series-$i" --description "Part $i of PR series" --color "8B5CF6" 2>/dev/null || true
done
```

## Creating New PR Workflow

1. Check git status:
```bash
git status
git diff --stat
```

2. Commit uncommitted changes if present:
```bash
# Ask user for commit message or generate from changes
git add <relevant-files>
git commit -m "message"
```

3. Push branch:
```bash
git push -u origin <branch>
```

4. Check PR size:
```bash
git diff --stat $(git merge-base HEAD origin/main)..HEAD | tail -1
```

5. Generate title and description:
- Title: Conventional commit format (feat:, fix:, chore:, etc.)
- Description: Analyze changes, generate Summary/Changes/Why
- Determine type label from title prefix

6. Create draft PR:
```bash
gh pr create --draft \
  --title "feat: title" \
  --body "$(cat <<'EOF'
## Summary
...
EOF
)" \
  --label "feature"
```

7. Return PR URL and next steps:
```
Created PR #123: https://github.com/org/repo/pull/123

Mark ready when satisfied:
  gh pr ready 123
  gh pr edit 123 --add-label "needs-review"
```

## Updating Existing PR Workflow

1. Fetch PR info:
```bash
gh pr view <number> --json title,body,baseRefName,headRefName,additions,deletions,files
```

2. Get current changes:
```bash
gh pr diff <number>
gh pr diff <number> --stat
```

3. Analyze changes and regenerate description:
- Keep title unless completely wrong
- Regenerate Summary based on current diff
- Update Changes list
- Verify Why section still accurate
- Preserve Stack section if exists

4. Update PR description:
```bash
gh pr edit <number> --body "$(cat <<'EOF'
...
EOF
)"
```

5. Verify/update labels:
```bash
gh pr edit <number> --add-label "feature" --remove-label "old-label"
```

6. Report changes made

## Parameter Parsing Logic

```bash
arg="$1"

# Empty - current branch
if [ -z "$arg" ]; then
  mode="create"
  branch=$(git branch --show-current)
fi

# Number - update PR
if [[ "$arg" =~ ^[0-9]+$ ]]; then
  mode="update"
  pr_number="$arg"
fi

# URL - parse and update
if [[ "$arg" =~ ^https://github.com/ ]]; then
  mode="update"
  # Parse org/repo/number from URL
fi

# org/repo#N format
if [[ "$arg" =~ ^([^/]+)/([^#]+)#([0-9]+)$ ]]; then
  mode="update"
  org="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
  pr_number="${BASH_REMATCH[3]}"
fi

# Path (directory exists)
if [ -d "$arg" ]; then
  mode="create"
  cd "$arg"
  branch=$(git branch --show-current)
fi

# Branch name
if git rev-parse --verify "$arg" >/dev/null 2>&1; then
  mode="create"
  branch="$arg"
fi

# Path + branch
if [ -d "$1" ] && [ -n "$2" ]; then
  cd "$1"
  branch="$2"
fi
```

## Git-Town for Series

See git-town skill for full CLI reference.

Create series:
```bash
# Create branches
git checkout master
git checkout -b part-1-refactor
# Make changes, commit
git checkout -b part-2-feature
# Make changes, commit

# Set relationships
git checkout part-1-refactor && git town set-parent master
git checkout part-2-feature && git town set-parent part-1-refactor

# Push
git push -u origin part-1-refactor part-2-feature

# Create PRs with series labels
gh pr create --draft --base master --title "refactor: title" --label "refactor,series-1"
gh pr create --draft --base part-1-refactor --title "feat: title" --label "feature,series-2"
```

After merge, sync children:
```bash
git checkout part-2-feature
git town sync
gh pr edit <number> --base master
```

## Quick Reference

| Task | Command |
|------|---------|
| Create PR from current branch | `/pr` |
| Create PR from specific branch | `/pr feature-branch` |
| Create PR from path | `/pr ../other-project` |
| Update PR by number | `/pr 123` |
| Update PR by URL | `/pr https://...` |
| Update PR in other repo | `/pr org/repo#123` |
| Check size | `git diff --stat base..HEAD` |
| Mark ready | `gh pr ready <number>` |
| Add label | `gh pr edit <number> --add-label "needs-review"` |

## Integration Steps

When invoked:

1. **Parse arguments** to determine mode and target

2. **Create mode:**
   - Check git status
   - Commit uncommitted changes if present (ask or generate message)
   - Push branch
   - Check size
   - Generate title (conventional commit format)
   - Generate description (analyze changes)
   - Ensure labels exist
   - Create draft PR
   - Apply type label
   - Return URL and next steps

3. **Update mode:**
   - Fetch PR details
   - Get current diff
   - Regenerate description
   - Update PR
   - Verify labels
   - Report changes

4. **Error handling:**
   - No git repo: Error
   - No remote: Error
   - Uncommitted and can't commit: Ask user
   - PR not found: Error with helpful message
   - No changes: Warn but allow

## Style Rules

- Title: Conventional commit (feat:, fix:, chore:, refactor:, docs:)
- Single responsibility per PR
- Summary: 1-2 sentences
- Changes: 3-5 bullets
- Why: 1-2 sentences
- No test plans or checklists (user marks ready after own review)

## Example Outputs

**Creating new PR:**
```
Analyzing changes...
Committing uncommitted files...
Committed: feat: add user authentication

Pushing branch...
Pushed to origin/feat/auth

Checking PR size...
Total changes: +145/-23 = 168 lines (within 1200 line limit)

Creating PR...
Created PR #123 (draft): https://github.com/org/repo/pull/123

Title: feat: add user authentication
Labels: feature

Mark ready when satisfied:
  gh pr ready 123
  gh pr edit 123 --add-label "needs-review"
```

**Updating existing PR:**
```
Fetching PR #123...
Current changes: +187/-45 = 232 lines

Regenerating description from current diff...
Updated summary based on new changes
Updated changes list (3 items)

Updating PR #123...
Description updated
Labels verified: feature

PR #123 updated: https://github.com/org/repo/pull/123
```

## Commit Message Generation

When uncommitted changes present and no message provided:

1. Analyze `git diff` output
2. Identify file types and patterns
3. Generate conventional commit message:
   - feat: for new files or significant additions
   - fix: for changes in bug-related files
   - chore: for config, tooling, or misc changes
   - refactor: for code restructuring without behavior change
   - docs: for documentation-only changes
4. Ask user to confirm or provide alternative

Example:
```
Uncommitted changes detected:
  plugins/android/script.sh (modified)
  plugins/android/lib.sh (modified)
  +45/-12 lines

Suggested commit message:
  "refactor(android): extract helper functions to lib.sh"

Proceed with this message? [Y/n/edit]
```
