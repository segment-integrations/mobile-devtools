---
name: rebase
description: Rebase branches and PR series onto updated base branches. Uses git-town for PR series management, standard git rebase for single branches.
argument-hint: [branch-name | pr-number | empty]
disable-model-invocation: false
allowed-tools: Bash(git *) Bash(git town *)
---

# Git Rebase

## Overview

Rebasing replays commits from one branch onto another. Use to update feature branches with latest main/master changes or to clean up commit history. For PR series, prefer git-town which handles parent-child relationships automatically.

## Default Behavior (No Arguments)

Rebases current branch onto main/master:

```bash
/rebase                    # Rebase current branch onto main
```

## Parameters

```bash
/rebase                           # Current branch onto main/master
/rebase feature-branch            # Specific branch onto its parent
/rebase feature-branch main       # Explicit target base
/rebase 123                       # PR branch onto its base
/rebase --interactive             # Interactive rebase for history cleanup
```

## When to Use Rebase vs Merge

**Use rebase when:**
- Updating feature branch with latest main
- Cleaning up commit history before PR merge
- Working on PR series (use git-town)
- Want linear history

**Use merge when:**
- Integrating completed feature into main
- Working with public/shared branches
- Want to preserve complete history

## Basic Rebase

### Update Current Branch

```bash
# Fetch latest changes
git fetch origin

# Determine base branch
base=$(git rev-parse --verify main 2>/dev/null || echo master)

# Rebase current branch
git rebase origin/$base
```

### Update Specific Branch

```bash
# Switch to branch
git checkout feature-branch

# Rebase onto main
git rebase origin/main

# Or rebase onto specific branch
git rebase origin/develop
```

### Rebase with Autosquash

Automatically squash fixup commits:

```bash
# Create fixup commit
git commit --fixup=<commit-hash>

# Rebase with autosquash
git rebase -i --autosquash origin/main
```

## PR Series with Git-Town

**IMPORTANT:** For PR series, use `git town sync` instead of manual rebase. It handles parent-child relationships automatically.

### Update Single PR in Series

```bash
# Switch to PR branch
git checkout part-2-feature

# Sync updates parent and rebases current branch
git town sync

# Push updated branch
git push --force-with-lease
```

`git town sync` does:
1. Fetches latest from origin
2. Updates parent branches
3. Rebases current branch onto parent
4. Handles conflicts if any

### Update Entire Series

```bash
# Start from any branch in series
git checkout part-1-core

# Sync entire stack
git town sync --stack

# Push all branches
git push --force-with-lease origin part-1-core part-2-feature part-3-tests
```

### After Parent PR Merges

When parent PR merges, update children:

```bash
# Example: part-1 merged, update part-2
git checkout part-2-feature

# Sync rebases onto new parent (main)
git town sync

# Update PR base on GitHub
gh pr edit <pr-number> --base main

# Push
git push --force-with-lease
```

Git-town automatically detects merged parents and updates relationships.

## Interactive Rebase

Edit, reorder, squash, or drop commits.

### Start Interactive Rebase

```bash
# Rebase last N commits
git rebase -i HEAD~3

# Rebase since branching from main
base=$(git rev-parse --verify main 2>/dev/null || echo master)
git rebase -i origin/$base

# Rebase onto specific commit
git rebase -i <commit-hash>
```

### Interactive Commands

```
pick   - Keep commit as-is
reword - Edit commit message
edit   - Edit commit contents
squash - Combine with previous commit (keep both messages)
fixup  - Combine with previous commit (discard this message)
drop   - Remove commit
```

Example:
```
pick a1b2c3d feat: add authentication
squash e4f5g6h fix: typo in auth
pick h7i8j9k feat: add user profile
reword k0l1m2n docs: update readme
```

### Squash Multiple Commits

Combine last 3 commits:

```bash
git rebase -i HEAD~3

# In editor, change to:
# pick <first>
# squash <second>
# squash <third>
```

## Conflict Resolution

### When Conflicts Occur

```bash
# Rebase starts
git rebase origin/main
# CONFLICT (content): Merge conflict in file.txt

# Check status
git status

# Edit conflicted files (remove markers)
# <<<<<<< HEAD
# =======
# >>>>>>> commit message

# Stage resolved files
git add file.txt

# Continue rebase
git rebase --continue

# Or skip this commit
git rebase --skip

# Or abort entirely
git rebase --abort
```

### Conflict Strategies

**Resolve conflicts:**
1. Open conflicted files
2. Remove conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
3. Choose correct content (ours, theirs, or combination)
4. Stage resolved files: `git add <files>`
5. Continue: `git rebase --continue`

**Accept ours (current branch):**
```bash
git checkout --ours file.txt
git add file.txt
git rebase --continue
```

**Accept theirs (target branch):**
```bash
git checkout --theirs file.txt
git add file.txt
git rebase --continue
```

## Force Push Safety

After rebase, force-push is required. Use `--force-with-lease` for safety.

```bash
# Safe - fails if remote changed
git push --force-with-lease

# Unsafe - overwrites remote unconditionally
git push --force  # AVOID
```

**WARNING:** Force-pushing rewrites history. Coordinate with team if branch is shared.

### When to Force Push

**Safe:**
- Your feature branch
- PR branches you own
- After rebase/amend/squash

**Dangerous:**
- Shared branches (develop, staging)
- Main/master (blocked by most repos)
- Other people's branches

## Common Workflows

### Update Feature Branch Before PR

```bash
# Fetch latest
git fetch origin

# Check current branch
git branch --show-current  # feature-auth

# Rebase onto main
base=$(git rev-parse --verify main 2>/dev/null || echo master)
git rebase origin/$base

# Resolve conflicts if any

# Force push
git push --force-with-lease
```

### Clean Up Commits Before Merge

```bash
# Interactive rebase since branching
base=$(git rev-parse --verify main 2>/dev/null || echo master)
git rebase -i origin/$base

# Squash fixup commits, reword messages

# Force push
git push --force-with-lease
```

### Update PR Series

```bash
# Check series structure
git town config setup

# Switch to any branch in series
git checkout part-2-feature

# Sync entire stack
git town sync --stack

# Push all updated branches
git push --force-with-lease origin part-1-core part-2-feature part-3-tests
```

### Rebase After Main Updated

```bash
# Fetch
git fetch origin

# Checkout feature branch
git checkout feature-auth

# Rebase
git rebase origin/main

# Push
git push --force-with-lease
```

## Rebase vs Git-Town Sync

### Use git-town sync when:
- Working with PR series
- Branch has parent branches
- Want automatic conflict resolution for series
- Need to update entire stack

```bash
git town sync              # Current branch + parents
git town sync --stack      # Entire series
```

### Use git rebase when:
- Single branch (no series)
- Need interactive rebase (squash, reword)
- Want manual control
- Branch not managed by git-town

```bash
git rebase origin/main
git rebase -i HEAD~3
```

## Aborting Rebase

If rebase goes wrong, abort to return to pre-rebase state:

```bash
# Abort rebase
git rebase --abort

# Verify back to original state
git status
```

## Parameter Parsing

```bash
arg="$1"
target="${2:-}"

# Empty - current branch onto main
if [ -z "$arg" ]; then
  branch=$(git branch --show-current)
  base=$(git rev-parse --verify main 2>/dev/null || echo master)
  mode="rebase"
fi

# Interactive flag
if [[ "$arg" == "--interactive" ]] || [[ "$arg" == "-i" ]]; then
  mode="interactive"
  base=$(git rev-parse --verify main 2>/dev/null || echo master)
fi

# PR number
if [[ "$arg" =~ ^[0-9]+$ ]]; then
  # Get branch from PR
  branch=$(gh pr view "$arg" --json headRefName -q .headRefName)
  base=$(gh pr view "$arg" --json baseRefName -q .baseRefName)
  mode="rebase"
fi

# Branch name
if git rev-parse --verify "$arg" >/dev/null 2>&1; then
  branch="$arg"
  if [ -n "$target" ]; then
    base="$target"
  else
    base=$(git rev-parse --verify main 2>/dev/null || echo master)
  fi
  mode="rebase"
fi
```

## Git-Town Detection

Check if branch is part of series:

```bash
# Check if git-town is available
if command -v git-town >/dev/null 2>&1; then
  # Check if branch has parent
  parent=$(git town config get-parent "$branch" 2>/dev/null || true)
  
  if [ -n "$parent" ]; then
    echo "Branch is part of series (parent: $parent)"
    echo "Use 'git town sync' instead of manual rebase"
  fi
fi
```

## Workflow Decision Tree

```markdown
Is branch part of PR series?
├─ YES → Use git-town sync
│   ├─ Single branch: git town sync
│   └─ Entire series: git town sync --stack
└─ NO → Use git rebase
    ├─ Update with latest: git rebase origin/main
    ├─ Clean history: git rebase -i origin/main
    └─ Resolve conflicts: fix, stage, continue
```

## Safety Rules

**Before rebase:**
- Commit or stash uncommitted changes
- Fetch latest from origin
- Verify branch is correct

**During rebase:**
- Resolve conflicts carefully (test after)
- Use --continue after fixing conflicts
- Use --abort if rebase goes wrong

**After rebase:**
- Test changes still work
- Use --force-with-lease not --force
- Coordinate if branch is shared

**NEVER:**
- Force push to main/master
- Force push to shared branches without coordination
- Rebase public branches others depend on

## Quick Reference

| Task | Command |
|------|---------|
| Rebase onto main | `git rebase origin/main` |
| Interactive rebase | `git rebase -i HEAD~N` |
| Continue after conflict | `git rebase --continue` |
| Abort rebase | `git rebase --abort` |
| Sync PR series | `git town sync` |
| Sync entire stack | `git town sync --stack` |
| Safe force push | `git push --force-with-lease` |
| Accept ours | `git checkout --ours <file>` |
| Accept theirs | `git checkout --theirs <file>` |

## Integration with Other Skills

**git-town:** Primary tool for PR series. Use `git town sync` instead of manual rebase for stacked branches.

**gh:** Get PR branch info for rebase (`gh pr view <number> --json headRefName,baseRefName`).

**pr:** After rebase, PR is automatically updated (same branch, new commits).

**review:** Run review after rebase to ensure changes still valid.

## Error Handling

**"Cannot rebase: You have unstaged changes":**
```bash
# Commit or stash
git stash
git rebase origin/main
git stash pop
```

**"CONFLICT: Merge conflict in file.txt":**
```bash
# Resolve conflict
# Edit file.txt
git add file.txt
git rebase --continue
```

**"fatal: refusing to merge unrelated histories":**
```bash
# Use --allow-unrelated-histories (rare, usually wrong branch)
git rebase --allow-unrelated-histories origin/main
```

**Force push rejected:**
```bash
# Remote changed since your rebase
git fetch origin
git rebase origin/main  # Rebase again
git push --force-with-lease
```
