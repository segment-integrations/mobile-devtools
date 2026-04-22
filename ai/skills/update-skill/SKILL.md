---
name: update-skill
description: Update skills based on user requests or verify CLI syntax against current tool versions. Handles content modifications, new features, corrections, and automated CLI verification.
argument-hint: [skill-name] [modification-description or empty for CLI verification]
disable-model-invocation: false
allowed-tools: Read Bash(*) Grep Edit Write
---

# Skill Update and Modification

## Overview

Updates skills in two modes:

1. **Modification Mode**: Apply user-requested changes to skill content, structure, or behavior
2. **Verification Mode**: Automatically verify CLI command syntax against current tool versions

Choose mode based on user request or default to CLI verification when no specific changes requested.

## Mode Selection

Determine mode from user request:

**Modification Mode** - User specifies changes:
```
/update-skill cleanup add detection for X files
/update-skill pr change description format to Y
/update-skill devbox-android update device selection behavior
/update-skill rebase add conflict resolution examples
```

**Verification Mode** - No specific changes mentioned:
```
/update-skill devbox          # Verify devbox CLI syntax
/update-skill                 # Verify all skills with CLI commands
```

## Modification Mode Workflow

When user requests specific changes to a skill:

### 1. Understand the Request

Parse user intent:
- What skill to modify
- What aspect to change (content, examples, structure, behavior)
- What the desired outcome is

Examples:
- "add X feature" → Add new section or examples
- "change Y to Z" → Replace or update existing content
- "improve documentation for X" → Enhance clarity or completeness
- "remove outdated X" → Delete deprecated information
- "reorganize sections" → Restructure content

### 2. Read Current Skill

```bash
cat ai/skills/<skill-name>/SKILL.md
```

Understand:
- Current structure and organization
- Existing content and examples
- Writing style and format
- Where changes should be integrated

### 3. Apply Requested Changes

Make modifications following create-skill guidelines:

**Content changes:**
- Add new sections with clear headings
- Update examples with current syntax
- Improve clarity of explanations
- Remove outdated information
- Fix inaccuracies

**Structure changes:**
- Reorganize sections logically
- Split large sections if needed
- Add subsections for clarity
- Improve information hierarchy

**Format requirements:**
- Agent-readable structure
- No emojis or decorative symbols
- Direct, concise statements
- Inline code examples
- Clear section boundaries

### 4. Verify Changes

After editing:
- Re-read modified sections
- Check examples are correct and runnable
- Ensure changes integrate smoothly
- Verify formatting follows create-skill guidelines
- Test any command examples if possible

### 5. Report Changes

Summarize what was modified:
```markdown
Updated <skill-name>:
- Added: X feature documentation
- Changed: Y section to Z format
- Removed: Outdated A information
- Improved: Clarity of B examples
```

## Verification Mode Workflow

When automatically verifying CLI command syntax:

### 1. Identify Skills to Update

```bash
# Update all skills
ls /Users/abueide/code/mobile-devtools/ai/skills/*/SKILL.md

# Update specific skill
/Users/abueide/code/mobile-devtools/ai/skills/<skill-name>/SKILL.md
```

### 2. Extract Commands from Skill

Read skill SKILL.md and identify:
- Command names in code blocks
- Documented flags and arguments
- Stated behavior and defaults

Look for:
- Inline command examples: `command --flag arg`
- Command documentation sections
- Flag/option lists
- Default value claims

### 3. Verify Against Current Version

For each command found:

**CLI Tools:**
```bash
# Get help output
<command> --help
<command> -h
<command> help

# Get version
<command> --version
<command> version
```

**For tools without --help:**
- Check man pages: `man <command>`
- Read online docs (tool website/GitHub)
- Check tool repo README

### 4. Compare and Identify Discrepancies

Check for:
- Flags that no longer exist
- New flags not documented
- Changed flag names (e.g., --config vs -c)
- Changed default values
- Changed behavior descriptions
- Deprecated commands or options
- New commands or subcommands

### 5. Update Skill

Apply updates following create-skill guidelines:

**Syntax updates:**
- Update flag names
- Add new flags to lists
- Remove deprecated flags
- Correct default values
- Update command examples

**Format requirements:**
- Keep agent-readable structure
- No emojis or decorative symbols
- Direct statements
- Inline warnings where relevant
- Command blocks with current syntax

### 6. Verify Update

After editing:
- Re-read updated section
- Verify syntax matches --help output
- Check examples are runnable
- Ensure formatting follows create-skill guidelines

## Command Patterns by Skill Type

### CLI Tool Skills (devbox, gh, git)

Extract and verify:
```markdown
### command-name

```bash
command --flag value arg
command --other-flag
```

FLAGS:
- --flag: Purpose (default: X)
- --other-flag: Purpose
```

Verification:
1. Run `command --help`
2. Compare flags list
3. Check default values
4. Verify flag purposes
5. Update if discrepancies found

### Process Skills (pr-format, pr-review)

Focus on command examples used in workflows:
```markdown
### Creating PRs

```bash
gh pr create --draft --title "..." --label "..."
```
```

Verification:
1. Extract `gh` commands
2. Run `gh pr create --help`
3. Verify flags exist and behavior matches
4. Update command examples

### Architecture/Concept Skills (create-skill)

Usually no CLI verification needed unless examples reference commands.

## Skills Directory Structure

```
ai/skills/
├── devbox/SKILL.md           # CLI tool - verify devbox commands
├── pr-format/SKILL.md        # Process - verify gh commands
├── pr-review/SKILL.md        # Process - verify gh, git commands
├── create-skill/SKILL.md     # Concept - no CLI verification
└── update-skill/SKILL.md     # Process - verify various commands
```

## Verification Checklist

For each skill:

- [ ] Read SKILL.md
- [ ] Extract all command references
- [ ] Identify CLI tools documented
- [ ] Run --help for each command
- [ ] Compare flags and syntax
- [ ] Check default values
- [ ] Verify behavior descriptions
- [ ] Note deprecated features
- [ ] Note new features
- [ ] Update SKILL.md with corrections
- [ ] Verify update follows create-skill guidelines
- [ ] Test command examples if possible

## Common Tools to Verify

**Git:**
```bash
git --help
git <subcommand> --help
```

**GitHub CLI:**
```bash
gh --help
gh <subcommand> --help
gh pr create --help
gh pr edit --help
```

**Devbox:**
```bash
devbox --help
devbox run --help
devbox shell --help
```

**Git-town:**
```bash
git town --help
git town <subcommand> --help
```

## Example Update Process

### Before: Outdated devbox skill

```markdown
### devbox run

```bash
devbox run --config file test
```

FLAGS:
- --config: Config file
```

### Verification

```bash
$ devbox run --help
Usage: devbox run [flags] <cmd> [args...]

Flags:
  -c, --config string   Config file (default "devbox.json")
      --cwd string      Working directory
  -e, --env strings     Environment variables
      --pure           Pure mode
```

Findings:
- `-c` short form exists
- `--cwd`, `-e`, `--pure` not documented
- Default value for --config is "devbox.json"

### After: Updated skill

```markdown
### devbox run

Executes commands in devbox environment.

```bash
devbox run test                      # Script from devbox.json
devbox run python script.py          # Any binary
devbox run --pure test               # Isolated (no system PATH)
devbox run -c alt.json test          # Use alternate config
devbox run --cwd /path test          # Change working directory
devbox run -e DEBUG=1 test           # Set environment variable
```

FLAGS:
- --config / -c: Config file (default: devbox.json)
- --cwd: Working directory
- --env / -e: Environment variables
- --pure: Isolated mode (no system PATH)
```

## Integration Workflow

### Modification Mode Examples

**Add new feature:**
```
/update-skill cleanup add detection for AI-generated files

Process:
1. Read ai/skills/cleanup/SKILL.md
2. Find appropriate section (detection categories)
3. Add new detection pattern and examples
4. Update summary and checklist
5. Report changes
```

**Change behavior:**
```
/update-skill pr change to create PRs as ready instead of draft

Process:
1. Read ai/skills/pr/SKILL.md
2. Find PR creation workflow
3. Update gh pr create examples (remove --draft)
4. Update description text
5. Report changes
```

**Improve documentation:**
```
/update-skill devbox improve error handling documentation

Process:
1. Read ai/skills/devbox/SKILL.md
2. Find error handling sections
3. Add examples of common errors
4. Document recovery steps
5. Report changes
```

**Remove outdated content:**
```
/update-skill git-town remove deprecated commands

Process:
1. Read ai/skills/git-town/SKILL.md
2. Identify deprecated commands (check via --help)
3. Remove or mark as deprecated
4. Update examples to use current commands
5. Report changes
```

### Verification Mode Examples

**Verify specific skill:**
```
/update-skill devbox

Process:
1. Read ai/skills/devbox/SKILL.md
2. Extract commands (devbox run, devbox add, etc.)
3. Run `devbox --help` and `devbox <cmd> --help`
4. Compare documented vs actual syntax
5. Update SKILL.md with corrections
6. Report changes made
```

**Verify all skills:**
```
/update-skill

Process:
1. List all skills in ai/skills/
2. For each skill, perform verification workflow
3. Report changes per skill
```

### Mixed Requests

User may combine modification with verification:
```
/update-skill gh update to latest CLI version and add examples for new flags

Process:
1. Run verification mode (check gh --help)
2. Apply modification mode (add new flag examples)
3. Report both types of changes
```

## Output Format

Report findings:

```markdown
## Skill: <skill-name>

### Commands Verified
- command1: Up to date
- command2: Updated (changes listed below)
- command3: No --help available, manual verification needed

### Changes Made

#### command2
- Added flag: --new-flag
- Removed flag: --deprecated-flag
- Updated default: --config (old: none, new: config.json)
- Updated description: More accurate behavior

### Recommendations
- Consider documenting --new-useful-flag
- Remove section about deprecated feature X
```

## Special Cases

### No --help Available

For commands without --help:
1. Check man pages
2. Search for official docs online
3. Check tool's GitHub repository
4. Note in skill: "No --help available, verify manually"

### Breaking Changes

If major version change detected:
1. Note breaking changes
2. Update skill with version-specific info if needed
3. Add WARNING about version compatibility

### Deprecated Commands

If command deprecated:
1. Add WARNING in skill
2. Document replacement command
3. Keep old command with deprecation notice

## Maintenance Schedule

Recommended verification frequency:
- Monthly: CLI tools with frequent updates (gh, devbox)
- Quarterly: Stable CLI tools (git, git-town)
- On-demand: After known tool updates
- On-error: When user reports incorrect syntax

## Argument Parsing

Parse user request to determine mode and action:

**Skill name only** → Verification mode:
```
/update-skill devbox
/update-skill gh
```

**Skill name + modification keywords** → Modification mode:
```
/update-skill cleanup add X
/update-skill pr change Y to Z
/update-skill devbox update documentation
/update-skill rebase improve examples
```

**No arguments** → Verification mode (all skills):
```
/update-skill
```

**Keywords indicating modification:**
- add, include, insert
- change, modify, update, revise
- remove, delete, drop
- improve, enhance, clarify
- fix, correct
- reorganize, restructure

**Keywords indicating verification:**
- verify, check, validate
- sync, update (without specifics)
- No keywords (default to verification)

## Common Modification Patterns

### Adding Content

**New detection category:**
```
Add section for X file types
Add examples for Y scenario
Add workflow for Z use case
```

Implementation:
1. Find appropriate section
2. Insert new subsection
3. Add examples and commands
4. Update any reference lists

**New examples:**
```
Add example of handling X error
Add workflow example for Y
Add command example showing Z flag
```

Implementation:
1. Find examples section
2. Add new example with explanation
3. Ensure formatting matches existing

### Changing Content

**Update behavior:**
```
Change default from X to Y
Update workflow to use Z approach
Modify examples to show new pattern
```

Implementation:
1. Find relevant sections
2. Update descriptions and examples
3. Check for consistency across skill

**Improve clarity:**
```
Clarify section about X
Simplify explanation of Y
Make Z more explicit
```

Implementation:
1. Read section carefully
2. Rewrite for clarity
3. Add examples if helpful
4. Remove ambiguity

### Removing Content

**Remove outdated:**
```
Remove deprecated command X
Delete outdated section Y
Drop old workflow Z
```

Implementation:
1. Locate content
2. Verify it's outdated (check --help or docs)
3. Remove completely or mark deprecated
4. Update related sections

### Restructuring

**Reorganize:**
```
Reorganize sections for better flow
Split section X into subsections
Merge related sections Y and Z
```

Implementation:
1. Plan new structure
2. Move content systematically
3. Update cross-references
4. Verify logical flow

## Quick Reference

| Task | Command |
|------|---------|
| Add feature to skill | `/update-skill <name> add <feature>` |
| Change skill behavior | `/update-skill <name> change <aspect>` |
| Improve documentation | `/update-skill <name> improve <section>` |
| Remove outdated content | `/update-skill <name> remove <content>` |
| Verify CLI syntax | `/update-skill <name>` |
| Verify all skills | `/update-skill` |
| List skills | `ls ai/skills/*/SKILL.md` |
| Check command syntax | `<command> --help` |
| Read skill | `Read ai/skills/<name>/SKILL.md` |
| Update skill | `Edit ai/skills/<name>/SKILL.md` |
