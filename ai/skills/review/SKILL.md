---
name: review
description: Review code changes from PRs or branches, enforcing size/focus guidelines (800 lines max for code/test) and prioritizing bugs, code smells, simplifications. Accepts PR numbers, branch names, or empty for current branch.
argument-hint: [pr-number | branch-name | empty]
disable-model-invocation: false
allowed-tools: Bash(gh pr *) Bash(git diff *) Bash(git log *) Read Grep
---

# Code Review Guide

## Overview

Review code changes from pull requests or branches. Enforces size/focus guidelines, identifies bugs/smells/simplifications. See gh skill for GitHub operations, git-town skill for stacked branches.

## Default Behavior (No Arguments)

Reviews current branch against main/master:

```bash
/review                    # Review current branch vs main
```

## Parameter Formats

Accepts various inputs:

```bash
/review                           # Current branch vs main/master
/review feature-branch            # Specific branch vs main/master
/review 123                       # PR #123
/review https://github.com/.../123 # PR via URL
/review org/repo#123              # PR in different repo
/review feature..main             # Explicit range
```

Parameter resolution:
- Empty: Current branch vs main/master
- Number: PR number in current repo
- URL: Parse PR from GitHub URL
- org/repo#N: PR in specified repo
- Branch name: Branch vs main/master
- Range (branch1..branch2): Explicit diff range

## Priority Order

1. Size/Focus Guidelines - Lines, scope, test/doc separation
2. Bugs - Security, correctness, edge cases
3. Code Smells - Duplication, complexity, naming
4. Simplifications - Readability, cleaner approaches

## Size/Focus Guidelines (Check First)

### Size Limits

- Code changes: 800 lines max (additions + deletions)
- Test changes: 800 lines max
- Documentation: No limit

### Focus

- Single narrow focus
- One feature/bug/refactor, not multiple unrelated
- Red flag: "and" multiple times in description

### Test Inclusion

- Core tests with code if total <800 lines
- Separate if tests push over 800 lines

### Documentation

- Large docs (README, guides, API docs) separate
- Small inline comments/docstrings OK

### Splitting Strategy

**Series (git-town) - Use ONLY when:**
- Changes have code dependencies
- One change cannot merge until another merges
- Example: Tests verifying code from earlier change

**Independent - Use when:**
- Changes can merge in any order
- No code dependencies
- Example: Bug fix + unrelated feature

Default to independent unless dependencies clear.

## Commands

### Gather Context

PR review:
```bash
gh pr view <number> --json title,body,files,additions,deletions
gh pr diff <number>
```

Branch review:
```bash
# Determine base branch (main or master)
base=$(git rev-parse --verify main 2>/dev/null || echo master)

# Get changes
git diff $base...<branch>
git log $base..<branch> --oneline
git diff $base..<branch> --stat
```

Current branch:
```bash
base=$(git rev-parse --verify main 2>/dev/null || echo master)
branch=$(git branch --show-current)
git diff $base...$branch
```

### Check Size

PR:
```bash
gh pr view <number> --json additions,deletions,files
```

Branch:
```bash
base=$(git rev-parse --verify main 2>/dev/null || echo master)
git diff $base..<branch> --stat | tail -1
git diff $base..<branch> --shortstat
```

## Review Checklist

### Size/Focus Guidelines

Size:
- [ ] Total lines = additions + deletions
- [ ] Code/Test: ≤800 lines
- [ ] Docs: No limit

Focus:
- [ ] Single clear purpose
- [ ] No unrelated changes
- [ ] Files relate to same feature/fix

Tests:
- [ ] Core tests present
- [ ] Tests with code if <800 total
- [ ] Separate if would exceed 800

Docs:
- [ ] Large docs should be separate
- [ ] Inline comments OK

### Bugs (Critical)

Security:
- [ ] Auth/authorization checks
- [ ] Input validation (SQL injection, XSS, path traversal)
- [ ] Data exposure (secrets, PII)
- [ ] Weak crypto
- [ ] Vulnerable dependencies

Correctness:
- [ ] Logic errors (off-by-one, wrong operators)
- [ ] Null/undefined handling
- [ ] Type mismatches
- [ ] Async issues (race conditions, missing await)
- [ ] Resource leaks

Edge Cases:
- [ ] Boundary conditions (empty, zero, max/min)
- [ ] Error handling
- [ ] Concurrency issues
- [ ] State management

### Code Smells

Duplication:
- [ ] Repeated logic
- [ ] Similar functions differing slightly
- [ ] Magic numbers
- [ ] Duplicate tests

Complexity:
- [ ] Long functions (>50 lines)
- [ ] Deep nesting (>3 levels)
- [ ] Complex conditions
- [ ] High cyclomatic complexity

Naming:
- [ ] Unclear names (data, temp, handle)
- [ ] Inconsistent naming
- [ ] Unclear abbreviations
- [ ] Missing context

Anti-Patterns:
- [ ] God objects
- [ ] Feature envy
- [ ] Primitive obsession
- [ ] Shotgun surgery

### Simplifications

Readability:
- [ ] Extract functions for complex expressions
- [ ] Early returns instead of nesting
- [ ] Inline single-use variables
- [ ] Self-explanatory code vs comments
- [ ] Comments explain WHY not WHAT
- [ ] Guides in docs/ not comments

Simpler Approaches:
- [ ] Use built-in methods
- [ ] Avoid over-engineering
- [ ] Remove dead code
- [ ] Reduce dependencies

Cleaner Abstractions:
- [ ] Better interfaces
- [ ] Proper encapsulation
- [ ] Right data structures
- [ ] Type safety

## Output Format

```markdown
# Code Review: [Title/Branch]

**Summary:** [1-2 sentences]
**Files Changed:** X files, +Y/-Z lines
**Review Focus:** [Aspects focused on]

---

## Size/Focus Guidelines

### Size: [PASS/FAIL]
- Total: X + Y = Z lines
- Type: [Code/Test/Documentation]
- Limit: [800/no limit]
- Status: [Within/Exceeds by N]

[If FAIL: Split strategy with git-town commands]

### Focus: [PASS/FAIL]
- Purpose: [Brief]
- Scope: [Narrow/Broad]

[If FAIL: List unrelated changes]

### Test Inclusion: [PASS/NEEDS ATTENTION/N/A]
- Core tests: [Yes/No]
- Coverage: [Adequate/Missing]

### Documentation: [PASS/NEEDS SEPARATION]
- Large docs: [Yes/No]
- Location: [Same/Separate]

---

## Bugs

[List bugs or "No bugs identified"]

Format per bug:
**[CRITICAL/HIGH/MEDIUM] Description**
File: `path:line`
Issue: [Explanation]
Impact: [Consequences]
Fix: ```suggestion code ```
Why: [Why fix is correct]

---

## Code Smells

[List smells or "No significant code smells"]

Format per smell:
**Category: Description**
File: `path:line`
Smell: [What's smelly]
Why it matters: [Impact]
Suggestion: ```suggestion code ```
Benefit: [What improves]

---

## Simplifications

[List improvements or "Code is clean"]

Format per simplification:
**Category: Description**
File: `path:line`
Current: [What it does now]
Simpler: ```suggestion code ```
Why better: [Explanation]

---

## What Looks Good

[2-3 specific positives]

---

## Review Stats

- Guideline Violations: X
- Critical Issues: X
- High Priority: Y
- Medium Priority: Z
- Nice-to-haves: W

---

## Next Steps

[If issues: Priority order]
[If none: Ready for merge]
```

## Split Suggestions

See git-town skill for full CLI reference.

### Dependent (Use Series)

```markdown
**Split Strategy:**

Series using git-town (see git-town skill for commands):

1. **PR 1: Core** (~X lines)
   - Files: path1, path2
   - Purpose: Core changes
   
2. **PR 2: Feature** (~Y lines)
   - Files: path3, path4
   - Purpose: Feature using core
   - Depends on: PR 1

**Git-town commands:**
```bash
git checkout master
git checkout -b feat/core
# Move files, commit
git checkout -b feat/api
# Move files, commit

git checkout feat/core && git town set-parent master
git checkout feat/api && git town set-parent feat/core

git push -u origin feat/core feat/api

gh pr create --draft --base master --title "feat: core" --label "feature,series-1"
gh pr create --draft --base feat/core --title "feat: api" --label "feature,series-2"
```
```

### Independent (No Series)

```markdown
**Split Strategy:**

Independent changes (NOT series):

1. **PR 1: Bug fix**
   - Files: path1, test1
   - Base: master

2. **PR 2: Feature**
   - Files: path2, test2
   - Base: master

**Why independent:** No code dependencies. Can review/merge in parallel.

**Commands:**
```bash
git checkout master

git checkout -b fix/bug
# Move files, commit
git push -u origin fix/bug

git checkout master
git checkout -b feat/feature
# Move files, commit
git push -u origin feat/feature

gh pr create --draft --base master --title "fix: bug" --label "bug"
gh pr create --draft --base master --title "feat: feature" --label "feature"
```

Note: Do NOT use git-town or series labels for independent changes.
```

## Parameter Parsing Logic

```bash
arg="$1"

# Empty - current branch
if [ -z "$arg" ]; then
  mode="branch"
  base=$(git rev-parse --verify main 2>/dev/null || echo master)
  branch=$(git branch --show-current)
fi

# Number - PR
if [[ "$arg" =~ ^[0-9]+$ ]]; then
  mode="pr"
  pr_number="$arg"
fi

# URL - parse PR
if [[ "$arg" =~ ^https://github.com/ ]]; then
  mode="pr"
  # Parse org/repo/number from URL
fi

# org/repo#N format
if [[ "$arg" =~ ^([^/]+)/([^#]+)#([0-9]+)$ ]]; then
  mode="pr"
  org="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
  pr_number="${BASH_REMATCH[3]}"
fi

# Range (branch1..branch2)
if [[ "$arg" =~ \.\. ]]; then
  mode="range"
  range="$arg"
fi

# Branch name
if git rev-parse --verify "$arg" >/dev/null 2>&1; then
  mode="branch"
  base=$(git rev-parse --verify main 2>/dev/null || echo master)
  branch="$arg"
fi
```

## Integration Steps

When invoked:

1. **Parse arguments** to determine mode (PR, branch, range)

2. **PR mode:**
   - Fetch PR details via `gh pr view`
   - Get diff via `gh pr diff`
   - Extract line counts
   - Proceed with review

3. **Branch mode:**
   - Determine base branch (main or master)
   - Get diff via `git diff base...branch`
   - Calculate line counts
   - Proceed with review

4. **Range mode:**
   - Use explicit range for diff
   - Calculate line counts
   - Proceed with review

5. **Perform review:**
   - Check size/focus guidelines first
   - If violations, suggest split strategy
   - Review for bugs (first pass)
   - Review for code smells (second pass)
   - Review for simplifications (third pass)
   - Format structured output
   - Call out positives

6. **Error handling:**
   - No git repo: Error
   - Branch not found: Error with helpful message
   - PR not found: Error with helpful message
   - Base branch ambiguous: Default to main, note assumption

## Review Principles

- Be specific with file:line references
- Show code suggestions, not just text
- Explain WHY suggestions matter
- Security > Correctness > Smells > Style
- Focus on actual problems
- Respect author - assume competence
- Frame as considerations not mistakes

## Comments Philosophy

Prefer self-explanatory code over comments.

Comments appropriate for:
- Why-comments (decisions, constraints)
- Context-comments (history, workarounds)
- Warning-comments (gotchas)

Comments NOT appropriate for:
- What-comments (explaining what code does)
- Long explanations (belongs in docs/)

## What NOT to Review

Skip unless causing problems:
- Style preferences (unless inconsistent)
- Micro-optimizations without measurement
- Over-abstraction for hypothetical needs
- Test implementation details (if effective)
- Minor naming nitpicks
- Formatting (let linters handle)

## Quick Reference

| Task | Command |
|------|---------|
| Review current branch | `/review` |
| Review specific branch | `/review feature-branch` |
| Review PR | `/review 123` |
| Review PR via URL | `/review https://...` |
| Review explicit range | `/review feat..main` |
| Get PR diff | `gh pr diff <number>` |
| Get branch diff | `git diff base..branch` |
| Check line count | `git diff --shortstat` |

## Integration with Other Skills

**gh skill:** Uses for PR operations (`gh pr view`, `gh pr diff`, `gh pr checks`).

**git-town skill:** References for split strategies and stacked branch management.

**pr skill:** Creates/updates PRs. Review skill provides feedback on changes.

When suggesting splits, analyze dependencies:
- Dependent changes → Use git-town series
- Independent changes → Use separate PRs from master
- Default to independent unless dependencies clear
