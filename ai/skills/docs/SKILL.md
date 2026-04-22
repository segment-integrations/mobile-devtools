---
name: docs
description: Review existing docs for accuracy/organization/focus, or create new docs following project standards. Default (no args) reviews current repo docs. With args, creates new doc from description.
argument-hint: [description | empty]
disable-model-invocation: false
allowed-tools: Read Grep Glob Write Edit
---

# Documentation Management

## Overview

Reviews existing documentation or creates new docs following project standards. Reviews check accuracy against code, target audience clarity, organization, singular focus, and overlap with existing docs.

## Default Behavior (No Arguments)

Reviews all documentation in current repo:

```bash
/docs                      # Review all docs in repo
```

## Creating New Documentation

Provide description of doc to create:

```bash
/docs "guide for setting up android emulators"
/docs "reference for environment variables"
/docs "troubleshooting common iOS issues"
```

## Documentation Types

Projects typically have three doc types:

**1. Guides** - Task-oriented, help users accomplish goals
- Location: `wiki/guides/` or `docs/guides/`
- Style: Prose with short paragraphs (2-4 sentences)
- Focus: Practical workflows, common use cases
- Examples: quick-start.md, android-guide.md, troubleshooting.md

**2. Reference** - Exhaustive option/command documentation
- Location: `wiki/reference/` or `docs/reference/`
- Style: Organized by component, concise descriptions
- Focus: Every option, variable, method, command
- Examples: REFERENCE.md, environment-variables.md, cli-commands.md

**3. Project** - Architecture, conventions, contributing
- Location: `wiki/project/` or `docs/project/`
- Style: Technical detail with decision rationale
- Focus: How system works, why decisions made
- Examples: ARCHITECTURE.md, CONVENTIONS.md, CONTRIBUTING.md

## Documentation Standards

### Writing Style

**Guides:**
- Prose style with 2-4 sentence paragraphs
- Bullet points and numbered lists for steps only
- Practical workflows and use cases
- Runnable code examples
- One concept per paragraph

**Reference:**
- Exhaustive coverage of all options
- Organized by component
- Concise descriptions without fluff
- Include valid values, defaults, constraints
- Quick-lookup tables

**General rules:**
- Write concisely, remove unnecessary words
- No marketing language ("powerful," "seamless," "robust")
- Active voice ("The script validates" not "Validation is performed")
- One concept per paragraph
- Code examples must be runnable and realistic

### File Organization

```
wiki/ or docs/
├── guides/              # Task-oriented docs
│   ├── quick-start.md
│   ├── {feature}-guide.md
│   └── cheatsheets/
├── reference/           # Exhaustive option docs
│   ├── cli-commands.md
│   ├── environment-variables.md
│   └── REFERENCE.md
└── project/             # Architecture and conventions
    ├── ARCHITECTURE.md
    ├── CONVENTIONS.md
    └── CONTRIBUTING.md
```

## Review Workflow

### 1. Find All Documentation

```bash
# Find markdown files (exclude node_modules, .git)
find . -type f -name "*.md" \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/build/*"
```

### 2. Check Accuracy Against Code

For each doc, verify:
- Command examples match actual CLI syntax
- File paths reference existing files
- Environment variables match current code
- Code snippets are syntactically correct

Methods:
```bash
# Extract commands from doc
grep -E '^\s*```bash' -A 10 doc.md

# Check if commands/files exist
command -v android.sh
test -f path/from/doc.md

# Verify env vars used in code
grep -r "ANDROID_SDK_ROOT" plugins/
```

### 3. Identify Target Audience

Docs should clearly target one of:
- End users (app developers using plugins)
- Contributors (plugin developers)
- Maintainers (core team)

Red flags:
- Mixing audiences (beginner + advanced in same doc)
- Unclear who doc is for
- Assumes knowledge without stating prerequisites

### 4. Check Organization

**Good organization:**
- Logical flow (basics → advanced)
- Clear section headers
- Consistent structure across similar docs
- Table of contents for long docs (>200 lines)
- Cross-references to related docs

**Poor organization:**
- Random topic order
- Unclear section hierarchy
- Missing headers
- Dead internal links
- No navigation between related docs

### 5. Verify Singular Focus

Each doc should have one clear purpose.

**Good focus:**
- "Android Emulator Setup Guide" - covers emulator setup only
- "Environment Variables Reference" - lists all env vars
- "Testing Conventions" - explains test structure

**Poor focus (too broad):**
- "Android Guide" - covers setup, emulation, building, testing, deployment
- "Everything About iOS" - unfocused grab bag

**Fix:** Split into multiple focused docs.

### 6. Check for Overlap

Docs should complement, not duplicate.

**Acceptable overlap:**
- Guide references detailed options in reference doc
- Troubleshooting repeats commands with context
- Quick-start shows subset of full guide

**Problematic overlap:**
- Two guides explaining same workflow differently
- Reference docs duplicating each other
- Architecture doc repeating conventions doc

**Fix:** Consolidate or cross-reference.

## Review Output Format

```markdown
# Documentation Review: [repo-name]

**Reviewed:** YYYY-MM-DD
**Docs found:** N files
**Issues:** X

---

## Summary

[1-2 sentences on overall doc health]

**Strengths:**
- [What's working well]

**Issues:**
- [Major problems found]

---

## Accuracy Issues

### [doc-name.md]

**Issue:** Command example outdated
**Location:** Line 45
**Current:** `android.sh devices create`
**Actual:** `android.sh devices create <name> --api <version>`
**Fix:** Update command syntax to match current CLI

### [doc-name.md]

**Issue:** Referenced file doesn't exist
**Location:** Line 78
**Reference:** `scripts/setup.sh`
**Actual:** File moved to `scripts/init/setup.sh`
**Fix:** Update path reference

---

## Target Audience Issues

### [doc-name.md]

**Issue:** Mixed audience levels
**Problem:** Starts with beginner setup, jumps to advanced internals
**Fix:** Split into "Quick Start Guide" (beginners) and "Advanced Configuration" (experienced)

### [doc-name.md]

**Issue:** Unclear audience
**Problem:** No indication who should read this or prerequisites
**Fix:** Add audience statement at top

---

## Organization Issues

### [doc-name.md]

**Issue:** Poor topic flow
**Problem:** Advanced topics before basics, no logical progression
**Fix:** Reorder sections: Overview → Setup → Basic Usage → Advanced

### [doc-name.md]

**Issue:** Missing table of contents
**Problem:** 400+ line doc with no navigation
**Fix:** Add TOC at top with section links

---

## Focus Issues

### [doc-name.md]

**Issue:** Too broad
**Problem:** Covers setup, configuration, deployment, troubleshooting in one doc
**Fix:** Split into:
- setup-guide.md (installation and configuration)
- deployment-guide.md (deployment workflows)
- troubleshooting.md (common problems)

---

## Overlap Issues

### [doc-a.md] and [doc-b.md]

**Issue:** Duplicate content
**Problem:** Both docs explain device creation with identical examples
**Fix:** Keep detailed explanation in reference doc, link from guide

### [doc-c.md] and [doc-d.md]

**Issue:** Conflicting instructions
**Problem:** doc-c says use method A, doc-d says use method B
**Fix:** Standardize on one method, update both docs

---

## Recommendations

**High priority:**
1. Fix command syntax in android-guide.md (users will get errors)
2. Split monolithic setup.md into focused docs
3. Resolve conflicting deployment instructions

**Medium priority:**
1. Add TOCs to long docs
2. Update file path references
3. Add audience statements

**Low priority:**
1. Improve cross-references between docs
2. Add more code examples to guides

---

## Doc Health Score

- Accuracy: 7/10 (some outdated commands)
- Audience: 6/10 (mixed audience levels)
- Organization: 8/10 (mostly logical)
- Focus: 5/10 (some docs too broad)
- Overlap: 7/10 (minor duplication)

**Overall: 6.6/10** - Docs functional but need updates
```

## Creating New Documentation

### 1. Determine Doc Type

From description, identify type:
- Task workflow → Guide
- Option listing → Reference
- System design → Project

### 2. Choose Location

```
Guide: wiki/guides/{feature}-guide.md
Reference: wiki/reference/{component}.md
Project: wiki/project/{TOPIC}.md
```

### 3. Generate Structure

**Guide template:**
```markdown
# {Feature} Guide

Brief description (1-2 sentences).

## Prerequisites

- Requirement 1
- Requirement 2

## Overview

[2-3 paragraphs explaining what, why, when]

## Setup

Step-by-step instructions:

1. Step one
```bash
command example
```

2. Step two
```bash
command example
```

## Common Workflows

### Workflow 1

Purpose: [what this accomplishes]

Steps:
1. Action
2. Action

```bash
# Example
commands
```

### Workflow 2

[Same structure]

## Troubleshooting

### Problem 1

Symptom: [what user sees]
Cause: [why it happens]
Fix:
```bash
solution command
```

## Next Steps

- [Link to related guide]
- [Link to reference doc]
```

**Reference template:**
```markdown
# {Component} Reference

Complete reference for all {component} options.

## Overview

[1-2 sentences on what this component is]

## Commands

### command-name

Description: [what it does]

Syntax:
```bash
command-name [options] <args>
```

Options:
- `--option`: Description (default: value)
- `--flag`: Description

Examples:
```bash
command-name --option value
command-name --flag
```

### command-name-2

[Same structure]

## Environment Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| VAR_NAME | Purpose | `value` | `export VAR_NAME=x` |

## Configuration Files

### file-name.json

Location: `path/to/file`

Structure:
```json
{
  "key": "value"
}
```

Fields:
- `key`: Description (required/optional)

## Error Messages

### "Error message text"

Cause: [why this happens]
Fix: [how to resolve]
```bash
solution
```
```

**Project template:**
```markdown
# {TOPIC}

Technical explanation of {topic}.

## Overview

[2-4 paragraphs explaining concept at high level]

## Architecture

[Component diagram or structure]

Components:
- Component A: Purpose
- Component B: Purpose

## Design Decisions

### Decision 1

Problem: [what we needed to solve]
Options considered:
- Option A: pros/cons
- Option B: pros/cons

Decision: [what we chose]
Rationale: [why we chose it]

### Decision 2

[Same structure]

## Implementation

Key implementation details that affect usage or contribution.

[Code structure, algorithms, patterns]

## Trade-offs

What we gained:
- Benefit 1
- Benefit 2

What we gave up:
- Cost 1
- Cost 2

## Future Considerations

[Known limitations, planned improvements]
```

### 4. Write Content

Follow documentation standards:
- Concise, active voice
- No marketing language
- Runnable code examples
- One concept per paragraph
- Logical organization

### 5. Cross-reference Related Docs

Link to:
- Prerequisites (if guide)
- Related guides
- Reference docs for details
- Architecture docs for context

## Parameter Parsing

```bash
arg="$*"

# Empty - review mode
if [ -z "$arg" ]; then
  mode="review"
fi

# Description provided - create mode
if [ -n "$arg" ]; then
  mode="create"
  description="$arg"
fi
```

## Integration Steps

### Review Mode

When invoked with no args:

1. Find all .md files in repo (exclude node_modules, .git, build)
2. For each doc:
   - Check command examples against actual CLI
   - Verify file/path references exist
   - Extract env vars, check usage in code
   - Assess target audience clarity
   - Check organization (flow, headers, TOC)
   - Identify focus (single purpose or scattered)
   - Compare with other docs for overlap
3. Generate review report with issues categorized
4. Provide actionable fixes for each issue
5. Calculate health scores per category

### Create Mode

When invoked with description:

1. Analyze description to determine doc type (guide/reference/project)
2. Choose appropriate location based on type
3. Select template (guide/reference/project)
4. Generate content outline from description
5. Fill in sections following standards
6. Add cross-references to existing docs
7. Write file to appropriate location
8. Report created doc path

## Validation Checks

**Accuracy checks:**
```bash
# Extract commands from markdown
grep -oP '(?<=```bash\n).*?(?=\n```)' doc.md

# Check command exists
command -v android.sh

# Verify file paths
test -f path/from/doc

# Check env var usage
grep -r "ENV_VAR_NAME" .
```

**Organization checks:**
- Count header levels (should be hierarchical)
- Check header order (logical flow)
- Verify TOC links (for long docs)
- Check internal links (no dead links)

**Focus checks:**
- Count distinct topics in doc
- Identify section coherence
- Flag if >3 unrelated topics

**Overlap checks:**
- Compare section headers across docs
- Identify duplicate code examples
- Flag conflicting instructions

## Quick Reference

| Task | Command |
|------|---------|
| Review all docs | `/docs` |
| Create guide | `/docs "guide for X"` |
| Create reference | `/docs "reference for Y commands"` |
| Create project doc | `/docs "architecture of Z"` |

## Integration with Other Skills

**cleanup:** Use to find orphaned/outdated docs before review.

**pr:** Include doc updates in PRs when code changes.

**review:** Check for missing docs when reviewing code PRs.

## Common Patterns

### Review Before Release

```bash
# Check docs are current
/docs

# Fix issues found
# ... edit docs ...

# Create PR with doc updates
/pr
```

### Create Docs for New Feature

```bash
# Add feature code
# ... implement feature ...

# Create guide
/docs "guide for using new feature X"

# Create reference
/docs "reference for feature X commands"

# Include in feature PR
/pr
```

### Consolidate Overlapping Docs

```bash
# Review finds overlap
/docs

# Consolidate content
# ... merge docs, add cross-references ...

# Remove duplicates
git rm wiki/guides/duplicate-doc.md

# Create cleanup PR
/pr
```
