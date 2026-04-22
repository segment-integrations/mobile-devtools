---
name: update-skill
description: Verify and update skill command syntax against current tool versions via --help flags and documentation. Ensures skills stay accurate and consistent with latest CLI changes.
argument-hint: [skill-name or empty for all skills]
disable-model-invocation: false
allowed-tools: Read Bash(*) Grep Edit Write
---

# Skill Update and Verification

## Overview

Verifies skill documentation accuracy by checking command syntax against current tool versions. Updates skills with correct flags, arguments, and behavior.

## Workflow

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

When invoked with argument:

**Update specific skill:**
```
/update-skill devbox
```

Process:
1. Read ai/skills/devbox/SKILL.md
2. Extract commands (devbox run, devbox add, etc.)
3. Run `devbox --help` and `devbox <cmd> --help`
4. Compare documented vs actual syntax
5. Update SKILL.md with corrections
6. Report changes made

**Update all skills:**
```
/update-skill
```

Process:
1. List all skills in ai/skills/
2. For each skill, perform specific update workflow
3. Report changes per skill

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

## Quick Reference

| Task | Command |
|------|---------|
| Update specific skill | `/update-skill <skill-name>` |
| Update all skills | `/update-skill` |
| List skills | `ls ai/skills/*/SKILL.md` |
| Verify command | `<command> --help` |
| Check man page | `man <command>` |
| Read skill | `Read ai/skills/<name>/SKILL.md` |
| Update skill | `Edit ai/skills/<name>/SKILL.md` |
