---
name: git-town
description: Git Town CLI for stacked branches and PR series. Manages parent-child branch relationships, syncing, and navigation for dependent changes.
argument-hint: [command or workflow name]
disable-model-invocation: false
allowed-tools: Bash(git town *)
---

# Git Town CLI

## Overview

Git Town manages stacked branches and PR series through parent-child relationships. Use for dependent PRs where changes must be reviewed/merged in sequence.

Key concepts:
- Branches have parent-child relationships forming stacks
- Child branches build on parent branches
- Commands navigate, sync, and manage stacks

## Core Concepts

### Branch Stacks

Parent-child relationships between branches:

```
main
 \
  feature-1 (parent of feature-2)
   \
    feature-2 (child of feature-1)
```

Child branches depend on parent branches. When parent merges, children rebase onto new parent.

### Branch Types

- **Main branch**: Root of all stacks (typically main/master)
- **Perennial branches**: Long-lived branches (develop, staging)
- **Feature branches**: Short-lived branches with parents

## Basic Commands

### hack

Create new feature branch off main branch.

```bash
git town hack feature-name
```

Creates feature branch as direct child of main, regardless of current branch.

FLAGS:
- --propose: Create PR after creating branch
- --prototype / -p: Create prototype branch (not synced)
- --no-sync: Skip syncing before creating branch

### append

Create new branch as child of current branch.

```bash
git town append child-branch-name
```

Current branch becomes parent of new branch. Use when building stacked PRs.

FLAGS:
- --propose: Create PR after creating branch
- --prototype / -p: Create prototype branch
- --no-sync: Skip syncing

Example stack creation:
```bash
git checkout main
git town hack feature-1           # Creates feature-1 off main
# Work on feature-1, commit
git town append feature-2         # Creates feature-2 as child of feature-1
# Work on feature-2, commit
git town append feature-3         # Creates feature-3 as child of feature-2
```

Result:
```
main
 \
  feature-1
   \
    feature-2
     \
      feature-3
```

### prepend

Create new branch as parent of current branch.

```bash
git town prepend parent-branch-name
```

Inserts new branch between current branch and its current parent. Use when extracting shared changes before feature branch.

FLAGS:
- --propose: Create PR after creating branch
- --prototype / -p: Create prototype branch
- --no-sync: Skip syncing

Example:
```bash
# Current stack:
# main -> feature-2

git checkout feature-2
git town prepend feature-1

# New stack:
# main -> feature-1 -> feature-2
```

### set-parent

Change parent of current branch.

```bash
git town set-parent              # Interactive selection
git town set-parent parent-name  # Set specific parent
git town set-parent --none       # Make perennial (no parent)
```

Use when reorganizing stacks or fixing relationships.

FLAGS:
- --none: Remove parent (make branch perennial)

Example:
```bash
# Change feature-2's parent from feature-1 to feature-A
git checkout feature-2
git town set-parent feature-A
```

## Branch Navigation

### up

Switch to child branch.

```bash
git town up
```

Moves "up" stack to child. If multiple children, shows selection dialog.

FLAGS:
- --merge / -m: Merge uncommitted changes into target branch

### down

Switch to parent branch.

```bash
git town down
```

Moves "down" stack to parent.

FLAGS:
- --merge / -m: Merge uncommitted changes into target branch

Navigation example:
```bash
# Stack: main -> feature-1 -> feature-2 -> feature-3
git checkout main
git town up      # Switch to feature-1
git town up      # Switch to feature-2
git town down    # Switch to feature-1
git town down    # Switch to main
```

## Syncing

### sync

Update current branch with all relevant changes.

```bash
git town sync                # Sync current branch
git town sync --all          # Sync all branches
git town sync --stack        # Sync entire stack
```

Behavior on feature branch:
1. Syncs all ancestor branches
2. Pulls updates for current branch
3. Merges parent into current branch
4. Pushes current branch

Behavior on main/perennial:
1. Pulls updates
2. Pushes updates
3. Pushes tags

FLAGS:
- --all / -a: Sync all local branches
- --stack / -s: Sync entire stack (current + ancestors + descendants)
- --no-push: Don't push branches
- --prune / -p: Prune empty branches

Common usage:
```bash
# After parent merges to main
git checkout feature-2
git town sync               # Rebases feature-2 onto new main

# Sync entire stack after changes
git town sync --stack       # Updates all related branches
```

WARNING: Run sync after parent branch merges to update child branches with new base.

## Shipping

### ship

Merge feature branch into parent.

```bash
git town ship                    # Ship current branch
git town ship feature-name       # Ship specific branch
```

Default: Ships only direct children of main. To ship child branches, ship ancestors first or use --to-parent.

FLAGS:
- --to-parent / -p: Allow shipping into non-main parent
- --message / -m: Commit message for squash
- --strategy / -s: Override ship-strategy (merge, squash, rebase)

Example shipping stack:
```bash
# Stack: main -> feature-1 -> feature-2 -> feature-3

# Ship in order
git checkout feature-1
git town ship               # Merges to main

git checkout feature-2
git town ship --to-parent   # Merges to feature-1 (now in main)

git checkout feature-3
git town ship --to-parent   # Merges to feature-2
```

## Branch Information

### branch

Display branch hierarchy and types.

```bash
git town branch
```

Shows all branches with parent-child relationships and branch types.

## Common Workflows

### Creating Stacked PRs

Purpose: Split large change into reviewable series.

Steps:
1. Create branches in dependency order
2. Set up parent-child relationships
3. Create PRs for each
4. Ship in order after approval

```bash
# Start from main
git checkout main

# Create and work on part 1
git town hack feature-1
# ... make changes, commit ...
git push -u origin feature-1

# Create and work on part 2 (child of part 1)
git town append feature-2
# ... make changes, commit ...
git push -u origin feature-2

# Create and work on part 3 (child of part 2)
git town append feature-3
# ... make changes, commit ...
git push -u origin feature-3

# Create PRs
gh pr create --base main --title "Part 1" --label "series-1"
git town up
gh pr create --base feature-1 --title "Part 2" --label "series-2"
git town up
gh pr create --base feature-2 --title "Part 3" --label "series-3"

# After PR 1 merges
git checkout feature-2
git town sync               # Rebases onto new main
gh pr edit <pr-2> --base main

# After PR 2 merges
git checkout feature-3
git town sync
gh pr edit <pr-3> --base main
```

### Reorganizing Stacks

Purpose: Change branch relationships.

```bash
# Move branch to different parent
git checkout feature-2
git town set-parent new-parent

# Insert branch before existing branch
git checkout feature-2
git town prepend feature-1.5

# Make branch independent
git checkout feature-2
git town set-parent main
```

### Syncing After Upstream Changes

Purpose: Update stack when main or parent changes.

```bash
# Sync single branch
git checkout feature-2
git town sync

# Sync entire stack
git checkout feature-1
git town sync --stack        # Updates feature-1, feature-2, feature-3...

# Sync all branches
git town sync --all
```

## Error Recovery

### continue

Resume after resolving conflicts.

```bash
git town continue
```

Use after manually resolving merge conflicts during sync/ship.

### skip

Skip current branch and continue.

```bash
git town skip
```

Use when branch cannot be synced and should be skipped.

### undo

Undo last git-town command.

```bash
git town undo
```

Reverts most recent git-town operation.

### status

Display current suspended command.

```bash
git town status
```

Shows what git-town command is waiting for conflict resolution.

## Configuration

### init

Initialize git-town in repository.

```bash
git town init
```

Prompts for main branch and perennial branches.

### config

Display configuration.

```bash
git town config
```

Shows all git-town configuration settings.

## Quick Reference

| Task | Command |
|------|---------|
| New branch off main | `git town hack <name>` |
| New child branch | `git town append <name>` |
| New parent branch | `git town prepend <name>` |
| Change parent | `git town set-parent [parent]` |
| Switch to child | `git town up` |
| Switch to parent | `git town down` |
| Sync current branch | `git town sync` |
| Sync entire stack | `git town sync --stack` |
| Sync all branches | `git town sync --all` |
| Ship to parent | `git town ship` |
| Ship to non-main | `git town ship --to-parent` |
| Show hierarchy | `git town branch` |
| Resume after conflict | `git town continue` |
| Undo last command | `git town undo` |

## Key Differences from Standard Git

git-town manages relationships git doesn't track:
- Parent-child branch relationships
- Automatic rebasing when parents merge
- Stack-aware syncing
- Navigation within stacks

Standard git workflow:
```bash
git checkout -b feature-2
git rebase main              # Manual rebase
```

git-town workflow:
```bash
git town append feature-2
git town sync                # Automatic rebase on parent
```

## When to Use git-town

Use git-town for:
- Stacked PRs with dependencies
- Large features split into series
- Changes requiring sequential review

Don't use git-town for:
- Independent PRs (no dependencies)
- Single PR changes
- Simple feature branches

See pr-review skill for deciding between stacked vs independent PRs.
