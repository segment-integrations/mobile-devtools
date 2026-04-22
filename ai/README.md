# AI Directory

## Skills

The `skills/` directory contains Claude Code skills optimized for agent consumption.

### Available Skills

**CLI Tools:**
- **devbox/** - Devbox CLI usage, project structure, and common workflows
- **devbox-android/** - Android Devbox plugin for reproducible Android development
- **devbox-ios/** - iOS Devbox plugin for reproducible iOS development (macOS only)
- **devbox-rn/** - React Native Devbox plugin (composes Android + iOS + Metro)
- **gh/** - GitHub CLI for PRs, repos, issues, and labels
- **git-town/** - Git Town CLI for stacked branches and PR series management
- **rebase/** - Rebase branches and PR series (uses git-town for series, git rebase for single branches)

**Processes:**
- **cleanup/** - Scan repos for problematic files (gitignored tracked files, build artifacts, junk)
- **docs/** - Review docs for accuracy/organization/focus, or create new docs following standards
- **pr/** - Create/update PRs with standardized format (commits changes, flexible parameters)
- **review/** - Review code changes from PRs or branches (size enforcement, bugs, smells)

**Meta:**
- **create-skill/** - Guidelines for creating new skills
- **update-skill/** - Verify and update skills against current command syntax

Each skill is a directory containing a `SKILL.md` file.

### Local Integration

These skills are symlinked to `~/.claude/skills/` for use across all Claude Code sessions:

```bash
~/.claude/skills/devbox -> /path/to/mobile-devtools/ai/skills/devbox
~/.claude/skills/devbox-android -> /path/to/mobile-devtools/ai/skills/devbox-android
~/.claude/skills/devbox-ios -> /path/to/mobile-devtools/ai/skills/devbox-ios
~/.claude/skills/devbox-rn -> /path/to/mobile-devtools/ai/skills/devbox-rn
~/.claude/skills/gh -> /path/to/mobile-devtools/ai/skills/gh
~/.claude/skills/git-town -> /path/to/mobile-devtools/ai/skills/git-town
~/.claude/skills/rebase -> /path/to/mobile-devtools/ai/skills/rebase
~/.claude/skills/cleanup -> /path/to/mobile-devtools/ai/skills/cleanup
~/.claude/skills/docs -> /path/to/mobile-devtools/ai/skills/docs
~/.claude/skills/pr -> /path/to/mobile-devtools/ai/skills/pr
~/.claude/skills/review -> /path/to/mobile-devtools/ai/skills/review
~/.claude/skills/create-skill -> /path/to/mobile-devtools/ai/skills/create-skill
~/.claude/skills/update-skill -> /path/to/mobile-devtools/ai/skills/update-skill
```

Changes to `SKILL.md` files in this repo automatically update the global skills.

### Setup Symlinks

To set up symlinks on a new machine:

```bash
cd ~/.claude/skills
ln -s /Users/abueide/code/mobile-devtools/ai/skills/devbox devbox
ln -s /Users/abueide/code/mobile-devtools/ai/skills/devbox-android devbox-android
ln -s /Users/abueide/code/mobile-devtools/ai/skills/devbox-ios devbox-ios
ln -s /Users/abueide/code/mobile-devtools/ai/skills/devbox-rn devbox-rn
ln -s /Users/abueide/code/mobile-devtools/ai/skills/gh gh
ln -s /Users/abueide/code/mobile-devtools/ai/skills/git-town git-town
ln -s /Users/abueide/code/mobile-devtools/ai/skills/rebase rebase
ln -s /Users/abueide/code/mobile-devtools/ai/skills/cleanup cleanup
ln -s /Users/abueide/code/mobile-devtools/ai/skills/docs docs
ln -s /Users/abueide/code/mobile-devtools/ai/skills/pr pr
ln -s /Users/abueide/code/mobile-devtools/ai/skills/review review
ln -s /Users/abueide/code/mobile-devtools/ai/skills/create-skill create-skill
ln -s /Users/abueide/code/mobile-devtools/ai/skills/update-skill update-skill
```

### Skill Design Principles

See `create-skill.md` for guidelines. Key points:

- Agent readability over human readability
- Eliminate non-semantic formatting (no emojis, decorative symbols)
- Organize logically (basics → advanced → edge cases)
- Be concise and actionable
- Place warnings inline where relevant
- Front-load critical information

Target 50-70% size reduction compared to human-friendly documentation.
