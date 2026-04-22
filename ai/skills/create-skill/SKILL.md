---
name: create-skill
description: Guidelines for creating skills optimized for agent consumption. Emphasizes concise, actionable content with semantic structure over decorative formatting.
argument-hint: [skill-name or topic]
disable-model-invocation: false
---

# Skill Creation Guide

## Purpose

Skills provide specialized knowledge and workflows to agents. They should be optimized for agent parsing and decision-making, not human reading pleasure.

## Core Principles

### 1. Agent Readability Over Human Readability

Write for parsing and information extraction, not narrative flow.

**Prefer:**
- Direct statements: "Use X for Y"
- Command syntax blocks
- Structured lists
- Compact tables (when semantic value)

**Avoid:**
- Prose paragraphs
- Marketing language ("powerful", "seamless", "robust")
- Conversational tone
- Verbose explanations

### 2. Eliminate Non-Semantic Formatting

Remove formatting that doesn't convey information.

**Remove:**
- Emojis and decorative symbols (⚠️, 🚨, 💡, ✅, ❌, 🎉)
- Visual separators beyond markdown headers
- Excessive whitespace
- Box drawing or ASCII art
- Redundant emphasis (bold/italic for non-semantic reasons)

**Keep:**
- Code blocks with syntax
- Headers for structure
- Bold for critical terms (WARNING, CRITICAL)
- Lists for enumerations
- Tables when data is tabular

### 3. Organize Information Logically

Present information in order of understanding, not discovery.

**Structure:**
1. Overview/definition
2. Basic usage
3. Common commands/patterns
4. Advanced usage
5. Edge cases/warnings
6. Reference tables

**Place warnings:**
- Inline where relevant, not dumped at top
- Adjacent to the concept/command they affect
- Use "WARNING:" or "CRITICAL:" prefix for scanning

### 4. Be Concise and Actionable

Every sentence should enable a decision or action.

**Prefer:**
- "Run X to do Y"
- "Use --flag for behavior"
- "File contains X, Y, Z"

**Avoid:**
- "You might want to consider..."
- "It's generally a good idea to..."
- "One approach you could take..."

### 5. Front-Load Critical Information

Put decision-making information early, details later.

**Pattern:**
```markdown
## Command Name

Does X. Use for Y.

```bash
command --flag arg
```

WARNING: Common mistake - explain pitfall.

Additional details...
```

## Skill File Structure

### Frontmatter (if supported)

```yaml
---
name: skill-name
description: One sentence summary. Include key constraints or patterns.
argument-hint: [expected-argument-format]
disable-model-invocation: false
allowed-tools: Tool1(*) Tool2(specific command)
---
```

### Body Structure

```markdown
# Skill Title

## Overview
[2-3 sentences: What it is, when to use it]

## Core Concepts/Commands
[Essential information agents need to act]

### Concept 1
[Direct explanation]
[Code/syntax if applicable]
[WARNING: Inline if relevant]

### Concept 2
[Direct explanation]
[Code/syntax if applicable]

## Common Patterns
[Workflows combining concepts]

## Reference
[Tables, command lists, quick lookup]

## Edge Cases
[Specific warnings, gotchas]
```

## Content Guidelines

### Command Documentation

Show syntax, flags, and purpose:

```markdown
### command-name

Does X. Returns Y.

```bash
command-name --flag value arg
command-name --other-flag        # Use when Z
```

FLAGS:
- --flag: Purpose (default: value)
- --other-flag: Purpose

WARNING: Common mistake explanation.
```

### Workflow Documentation

List steps concisely:

```markdown
### Workflow Name

Purpose: Accomplish X

Steps:
1. Command 1 - Purpose
2. Command 2 - Purpose
3. Command 3 - Purpose

```bash
command1 --flag
command2 arg
command3
```
```

### Decision Trees

Use clear conditionals:

```markdown
### When to Use X vs Y

Use X when:
- Condition A
- Condition B

Use Y when:
- Condition C
- Condition D

Default to X unless Y conditions explicit.
```

### Warnings and Gotchas

Place inline, use consistent formatting:

```markdown
WARNING: Description of problem. Consequence if ignored.

Correct: `correct syntax`
Wrong: `wrong syntax`
```

## What to Include

Essential content:
- Commands and their syntax
- Flags and their effects
- File/directory structure and purpose
- Decision-making criteria
- Common workflows
- Critical warnings (data loss, breaking changes)
- Quick reference tables

## What to Exclude

Non-essential content:
- Background/history
- Implementation details (unless needed for decisions)
- Alternative approaches without clear decision criteria
- Verbose examples (one clear example > three verbose ones)
- Motivational content
- Redundant restatements

## Examples

### Good: Concise Command Documentation

```markdown
### devbox run

Executes commands in devbox environment. Can run any binary in PATH.

```bash
devbox run test                  # Script from devbox.json
devbox run python script.py      # Any binary
devbox run --pure test           # Isolated (no system PATH)
```

WARNING: `devbox shell -c "cmd"` does NOT execute commands. Use `devbox run cmd`.
```

### Bad: Verbose Command Documentation

```markdown
### devbox run - The Command Execution Tool

The `devbox run` command is a powerful feature that allows you to execute commands and scripts within your devbox environment. It's important to understand that this command provides a lot of flexibility - you can use it not only to run scripts that you've defined in your devbox.json configuration file, but also to run any binary that's available in your PATH! This is really useful because...

[continues for paragraphs]
```

### Good: Concise Decision Tree

```markdown
### Series vs Independent PRs

Use series (git-town) ONLY when:
- PR 2 cannot merge until PR 1
- Code dependencies exist

Use independent PRs when:
- Can merge in any order
- No code dependencies

Default to independent unless dependencies clear.
```

### Bad: Verbose Decision Tree

```markdown
### Deciding Between Series and Independent PRs

When you're working on splitting up your PRs, you'll need to think carefully about whether you should use a series approach or independent PRs. This is an important decision! Let me walk you through the considerations...

A series makes sense when you have dependencies. What do I mean by dependencies? Well, imagine you have PR 2 that literally cannot be merged until PR 1 is already in the main branch...

[continues for paragraphs]
```

## Skill-Specific Considerations

### For CLI Tools

Focus on:
- Command syntax and flags
- Common workflows
- File structure
- Environment variables
- Critical warnings

### For Processes (PR review, formatting)

Focus on:
- Decision criteria
- Step-by-step workflows
- Output format templates
- Exception handling
- Priority ordering

### For Concepts/Architecture

Focus on:
- Component relationships
- Key rules/constraints
- Decision trees
- File/directory purposes
- Integration patterns

## Testing Your Skill

Before finalizing, verify:

1. Can agent extract commands? (clear syntax blocks)
2. Are decisions actionable? (if X then Y format)
3. Are warnings adjacent to relevant content? (not dumped at top)
4. Is structure logical? (basics → advanced)
5. Is every paragraph necessary? (remove if not actionable)
6. Are tables semantic? (remove if just formatting)
7. Are examples minimal? (one clear > many verbose)

## Checklist

- [ ] Frontmatter complete (if supported)
- [ ] Overview in first section
- [ ] Basics before advanced topics
- [ ] Warnings inline where relevant
- [ ] No emojis or decorative symbols
- [ ] No marketing language
- [ ] Commands have syntax blocks
- [ ] Decisions have clear criteria
- [ ] Tables convey semantic information
- [ ] No verbose examples
- [ ] No redundant paragraphs
- [ ] Quick reference section included

## Anti-Patterns

**Avoid:**

1. **Emoji/symbol soup**: Using icons instead of words
2. **Wall of warnings**: Dumping all warnings at top
3. **Chatty tone**: Writing like blog post
4. **Over-explanation**: Explaining why something is good/powerful
5. **Example bloat**: Showing 5 examples when 1 would do
6. **Decorative formatting**: Boxes, lines, excessive bold/italic
7. **Historical context**: How things used to work
8. **Motivational content**: Why reader should care

## Size Guidelines

Aim for conciseness:
- Simple tool/concept: 2-4KB
- Complex tool/workflow: 5-10KB
- Comprehensive reference: 10-15KB

If skill exceeds 15KB, consider splitting into multiple skills.

## Revision Process

To improve existing skill:

1. Remove all emojis and decorative symbols
2. Convert prose to direct statements
3. Move warnings inline
4. Eliminate redundant examples
5. Condense verbose explanations
6. Remove marketing language
7. Restructure: basics first, advanced later
8. Test: Can agent quickly find needed information?

Target 50-70% size reduction from human-friendly version.
