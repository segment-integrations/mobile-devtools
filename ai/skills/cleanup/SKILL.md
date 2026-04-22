---
name: cleanup
description: Scan git repos for files that shouldn't be committed, gitignored files currently tracked, and junk/outdated files. Read-only analysis returning categorized cleanup candidates.
argument-hint: [path | empty]
disable-model-invocation: false
allowed-tools: Bash(git *) Bash(find *) Bash(du *) Read Grep Glob
---

# Repository Cleanup Scanner

## Overview

Analyzes git repositories for problematic files. Returns categorized list of cleanup candidates without taking actions. Use for identifying committed build artifacts, tracked gitignored files, temp files, and junk.

## Default Behavior (No Arguments)

Scans current directory:

```bash
/cleanup                    # Scan current repo
```

## Parameters

```bash
/cleanup                           # Current directory
/cleanup /path/to/repo             # Specific repo path
/cleanup ../other-project          # Relative path
```

## Scan Categories

### 1. Tracked Files That Are Gitignored

Files committed before being added to .gitignore.

Check:
```bash
git ls-files -i --exclude-standard
```

Common cases:
- `.env` files committed before gitignore update
- IDE configs added to .gitignore later
- Build artifacts from old commits

### 2. Build Artifacts

Platform-specific build outputs that shouldn't be committed.

**Android:**
```
*.apk
*.aab
build/
.gradle/
local.properties
captures/
*.hprof
```

**iOS:**
```
*.app
*.ipa
*.dSYM
DerivedData/
*.xcworkspace/xcuserdata/
*.xcodeproj/xcuserdata/
Pods/
```

**React Native:**
```
android/app/build/
ios/build/
web/build/
metro-cache/
```

**Web:**
```
dist/
build/
.next/
.nuxt/
out/
```

Check with:
```bash
git ls-files | grep -E '\.(apk|aab|ipa|app)$'
git ls-files | grep -E '^(build|dist|DerivedData)/'
```

### 3. Dependency Directories

Package manager directories that should be .gitignored.

```
node_modules/
.pnpm-store/
Pods/
.gradle/
vendor/
__pycache__/
.venv/
```

Check:
```bash
git ls-files | grep -E '^(node_modules|Pods|vendor)/'
```

### 4. Temporary Files

Editor and system temp files.

```
.DS_Store
Thumbs.db
*.swp
*.swo
*.tmp
*.log
*.cache
*~
.*.swp
```

Check:
```bash
git ls-files | grep -E '\.(log|tmp|cache|swp|swo)$'
git ls-files | grep -E '(\.DS_Store|Thumbs\.db|~)$'
```

### 5. IDE and Editor Files

IDE-specific configs that shouldn't be shared.

```
.vscode/
.idea/
*.iml
.project
.classpath
.settings/
*.code-workspace
```

Check:
```bash
git ls-files | grep -E '^\.vscode/'
git ls-files | grep -E '\.(iml|code-workspace)$'
```

### 6. Environment and Secrets

Files that may contain credentials.

```
.env
.env.local
.env.*.local
credentials.json
secrets.yaml
*.pem
*.p12
*.keystore
google-services.json (if contains keys)
```

Check:
```bash
git ls-files | grep -E '\.(env|pem|p12|keystore)$'
git ls-files | grep -E '(credentials|secrets)\.'
```

### 7. Large Files

Files exceeding size thresholds (>1MB check, >10MB flag).

Check:
```bash
git ls-files | xargs -I {} sh -c 'test -f "{}" && du -k "{}" | awk "\$1 > 1024 {print \$2, \$1}"'
```

### 8. Outdated Files

Files with timestamp patterns indicating they're stale.

Patterns:
- `reports-2024-*.log` (old dated logs)
- `backup-*.zip` (old backups)
- `.devbox/virtenv/` (regenerated directories)
- `*.orig` (merge conflict backups)

Check:
```bash
git ls-files | grep -E '(backup|reports)-[0-9]{4}'
git ls-files | grep -E '\.(orig|bak)$'
```

### 9. AI-Generated Artifacts & Misplaced Documentation

AI-generated diagnostic files, implementation notes, and documentation in wrong locations.

**Common patterns:**
```
*DIAGNOSIS*.md
*ANALYSIS*.md
*SUMMARY*.md
*DEBUG*.md
*REPORT*.md (uppercase = often AI-generated)
claude_conversation_*
chatgpt_export_*
conversation_*.md
transcript_*
scratch_*
draft_*
wip_*
notes_* (in root, not docs/)
```

**Internal docs that don't belong in repos:**
- Implementation notes → GitHub issues or PR descriptions
- Diagnostic reports → GitHub issues with links to failed runs
- Meeting notes → Confluence, Notion, or team wiki
- Architecture drafts → Confluence or team wiki
- Internal process docs → Confluence or team wiki
- Only public-facing docs belong in repos (README, API docs, user guides)
- Non-standard .md files (excluding: README, CHANGELOG, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, CLAUDE)

Check:
```bash
# AI diagnostic/summary files (case-insensitive uppercase patterns)
git ls-files | grep -iE '(DIAGNOSIS|ANALYSIS|SUMMARY|DEBUG|REPORT).*\.md$'

# AI conversation exports
git ls-files | grep -E '(claude_|chatgpt_|conversation_|transcript_)'

# Scratch/draft files
git ls-files | grep -iE '(scratch|draft|wip|todo)_'

# Root-level docs (excluding standard files)
git ls-files | grep -E '^[^/]+\.md$' | grep -vE '^(README|CHANGELOG|LICENSE|CONTRIBUTING|CODE_OF_CONDUCT|CLAUDE)\.md$'
```

**Why these shouldn't be committed:**
- Implementation notes become stale as code evolves
- AI diagnostic files are point-in-time snapshots with no long-term value
- Internal docs belong in external systems (Confluence, GitHub issues, PR descriptions)
- Only public-facing documentation should be in version control
- Committing internal docs creates noise and makes git history harder to navigate
- Better to document decisions in code comments, commit messages, or team wiki

## Scanning Workflow

1. **Validate git repo:**
```bash
if [ ! -d "$path/.git" ]; then
  echo "Not a git repository"
  exit 1
fi
cd "$path"
```

2. **Check for tracked gitignored files:**
```bash
git ls-files -i --exclude-standard
```

3. **Check for build artifacts:**
```bash
# Android
git ls-files | grep -E '\.(apk|aab)$'
git ls-files | grep -E '^android/.*/(build|captures)/'

# iOS
git ls-files | grep -E '\.(ipa|app|dSYM)$'
git ls-files | grep -E '^ios/.*/build/'
git ls-files | grep -E 'Pods/'

# Web
git ls-files | grep -E '^(dist|build|out)/'
```

4. **Check for dependencies:**
```bash
git ls-files | grep -E '^(node_modules|Pods|\.gradle|vendor|__pycache__)/'
```

5. **Check for temp files:**
```bash
git ls-files | grep -E '\.(log|tmp|cache|swp|swo)$'
git ls-files | grep -E '(\.DS_Store|Thumbs\.db)$'
```

6. **Check for IDE files:**
```bash
git ls-files | grep -E '^(\.vscode|\.idea)/'
git ls-files | grep -E '\.(iml|code-workspace)$'
```

7. **Check for environment files:**
```bash
git ls-files | grep -E '\.env'
git ls-files | grep -E '\.(pem|p12|keystore)$'
```

8. **Check for large files:**
```bash
git ls-files -z | xargs -0 -I {} sh -c '
  if [ -f "{}" ]; then
    size=$(du -k "{}" | cut -f1)
    if [ "$size" -gt 1024 ]; then
      echo "{}" "$size"
    fi
  fi
'
```

9. **Check for outdated files:**
```bash
git ls-files | grep -E '(backup|reports)-[0-9]{4}'
git ls-files | grep -E '\.(orig|bak)$'
git ls-files | grep -E '\.devbox/virtenv/'
```

10. **Check for AI artifacts and misplaced docs:**
```bash
# AI diagnostic/summary files
git ls-files | grep -iE '(DIAGNOSIS|ANALYSIS|SUMMARY|DEBUG|REPORT).*\.md$'

# AI conversation exports
git ls-files | grep -E '(claude_|chatgpt_|conversation_|transcript_)'

# Scratch/draft files
git ls-files | grep -iE '(scratch|draft|wip|todo)_'

# Root-level non-standard docs
git ls-files | grep -E '^[^/]+\.md$' | grep -vE '^(README|CHANGELOG|LICENSE|CONTRIBUTING|CODE_OF_CONDUCT|CLAUDE)\.md$'
```

## Output Format

```markdown
# Repository Cleanup Report: [repo-name]

**Path:** /path/to/repo
**Scanned:** YYYY-MM-DD HH:MM:SS
**Total tracked files:** N

---

## Summary

- Tracked gitignored files: X
- Build artifacts: Y
- Dependency directories: Z
- Temporary files: A
- IDE files: B
- Environment/secrets: C
- Large files (>1MB): D
- Outdated files: E
- AI artifacts & misplaced docs: F

**Total cleanup candidates:** [sum]

---

## 1. Tracked Gitignored Files

Files committed before .gitignore rules added.

```
path/to/file1
path/to/file2
```

**Fix:**
```bash
git rm --cached path/to/file1
git rm --cached path/to/file2
git commit -m "chore: remove tracked gitignored files"
```

---

## 2. Build Artifacts

Platform build outputs that shouldn't be committed.

**Android (N files):**
```
android/app/build/outputs/apk/debug/app-debug.apk (2.3 MB)
android/app/build/intermediates/...
```

**iOS (N files):**
```
ios/build/Build/Products/Debug-iphonesimulator/MyApp.app
ios/Pods/...
```

**Web (N files):**
```
dist/bundle.js (1.5 MB)
build/index.html
```

**Fix:**
```bash
git rm -r --cached android/app/build ios/build dist build
git commit -m "chore: remove build artifacts"
```

---

## 3. Dependency Directories

Package manager directories committed by mistake.

```
node_modules/ (12,543 files, 245 MB)
ios/Pods/ (1,234 files, 87 MB)
```

**Fix:**
```bash
git rm -r --cached node_modules ios/Pods
git commit -m "chore: remove dependency directories"
```

---

## 4. Temporary Files

Editor and system temp files.

```
.DS_Store (3 files)
src/.file.swp
reports/test.log
```

**Fix:**
```bash
git rm --cached .DS_Store src/.file.swp reports/test.log
git commit -m "chore: remove temp files"
```

---

## 5. IDE Files

IDE-specific configs.

```
.vscode/settings.json
.idea/workspace.xml
android/app.iml
```

**Fix:**
```bash
git rm -r --cached .vscode .idea
git rm --cached android/app.iml
git commit -m "chore: remove IDE files"
```

---

## 6. Environment/Secrets

Files that may contain credentials.

**CRITICAL - REVIEW BEFORE REMOVING:**
```
.env (contains API_KEY)
android/app/google-services.json
ios/MyApp/GoogleService-Info.plist
credentials.json
```

**Fix (CAREFUL):**
```bash
# Review files first to confirm they contain secrets
git rm --cached .env credentials.json
git commit -m "chore: remove environment files with secrets"

# If secrets were committed, consider them compromised
# Rotate keys/credentials immediately
```

---

## 7. Large Files (>1MB)

Files exceeding size thresholds.

```
assets/video.mp4 (25.3 MB) - Consider git-lfs or external storage
reports/coverage.html (2.1 MB)
docs/assets/demo.gif (1.8 MB)
```

**Fix:**
```bash
# Remove if unnecessary
git rm --cached assets/video.mp4

# Or move to git-lfs
git lfs track "*.mp4"
git add .gitattributes
git commit -m "chore: track large files with git-lfs"
```

---

## 8. Outdated Files

Files with timestamp patterns indicating they're stale.

```
reports-2024-03-15.log
backup-20240112.zip
test.orig
.devbox/virtenv/android/scripts/lib.sh (regenerated)
```

**Fix:**
```bash
git rm --cached reports-2024-03-15.log backup-20240112.zip test.orig
git commit -m "chore: remove outdated files"
```

---

## 9. AI-Generated Artifacts & Misplaced Documentation

AI-generated diagnostic files and root-level documentation that should be elsewhere.

**AI diagnostic/summary files:**
```
CI_FAILURE_DIAGNOSIS.md (root-level diagnostic)
IMPLEMENTATION_SUMMARY.md (root-level implementation notes)
DEBUG_ANALYSIS.md
```

**Why problematic:**
- Point-in-time snapshots that become outdated quickly
- Clutter repository root and git history
- Belong in external systems, not version control

**AI conversation exports:**
```
claude_conversation_2024-03-15.md
chatgpt_export.txt
```

**Scratch/draft files:**
```
scratch_notes.md
draft_architecture.md
wip_design.md
```

**Fix:**
```bash
# Remove from repository
git rm --cached CI_FAILURE_DIAGNOSIS.md IMPLEMENTATION_SUMMARY.md
git commit -m "chore: remove AI-generated diagnostic files"

# Before removing, extract valuable info to appropriate systems:
# 1. Create GitHub issue if tracking a bug/feature
# 2. Add to PR description if implementation context
# 3. Document in Confluence/Notion if team knowledge
# 4. Add to code comments if explaining complex logic
```

**Where this content should go instead:**
- **CI failures** → GitHub issue with diagnosis + link to failed run
- **Implementation notes** → PR description or commit messages
- **Architecture decisions** → Confluence, Notion, or team wiki
- **Diagnostics** → Code comments or test documentation
- **Meeting notes** → Confluence, Notion, or team wiki
- **Scratch notes** → Local files, don't commit

**Repository documentation philosophy:**
- **Only commit public-facing docs**: README, API docs, user guides, quickstarts
- **Everything else belongs elsewhere**: internal notes, diagnostics, meeting minutes, drafts
- **Use external systems**: Confluence for team docs, GitHub issues for tracking, PRs for implementation context

---

## Next Steps

1. **Review candidates** - Verify each file should be removed
2. **Update .gitignore** - Add patterns to prevent re-committing
3. **Remove files** - Use commands above to git rm --cached
4. **Commit changes** - Commit removals with descriptive message
5. **Rotate secrets** - If environment files were committed, rotate credentials

**IMPORTANT:** Use `git rm --cached` not `git rm` to keep local files.
```

## Parameter Parsing

```bash
path="${1:-.}"

# Validate path exists
if [ ! -d "$path" ]; then
  echo "Path does not exist: $path"
  exit 1
fi

# Validate is git repo
if [ ! -d "$path/.git" ]; then
  echo "Not a git repository: $path"
  exit 1
fi

cd "$path" || exit 1
```

## Detection Commands

### Tracked Gitignored Files
```bash
git ls-files -i --exclude-standard
```

### Build Artifacts by Platform
```bash
# Android
git ls-files | grep -E '\.apk$|\.aab$|^android/.*/build/'

# iOS
git ls-files | grep -E '\.ipa$|\.app/|\.dSYM/|^ios/.*/build/|Pods/'

# Web
git ls-files | grep -E '^(dist|build|out|\.next)/'

# React Native
git ls-files | grep -E 'metro-cache/'
```

### Dependencies
```bash
git ls-files | grep -E '^(node_modules|Pods|\.gradle|vendor|__pycache__|\.pnpm-store)/'
```

### Temp Files
```bash
git ls-files | grep -E '\.(log|tmp|cache|swp|swo)$|\.DS_Store|Thumbs\.db|~$'
```

### IDE Files
```bash
git ls-files | grep -E '^(\.vscode|\.idea)/|\.(iml|code-workspace)$'
```

### Environment Files
```bash
git ls-files | grep -E '\.env|credentials|secrets|\.(pem|p12|keystore)$'
```

### Large Files
```bash
git ls-files -z | xargs -0 du -k 2>/dev/null | awk '$1 > 1024 {printf "%s (%d KB)\n", $2, $1}'
```

### Outdated Files
```bash
git ls-files | grep -E '(backup|reports)-[0-9]{4}|\.devbox/virtenv/|\.(orig|bak)$'
```

### AI Artifacts & Misplaced Docs
```bash
# AI diagnostic/summary files (case-insensitive)
git ls-files | grep -iE '(DIAGNOSIS|ANALYSIS|SUMMARY|DEBUG|REPORT).*\.md$'

# AI conversation exports
git ls-files | grep -E '(claude_|chatgpt_|conversation_|transcript_)'

# Scratch/draft files
git ls-files | grep -iE '(scratch|draft|wip|todo)_'

# Root-level non-standard docs
git ls-files | grep -E '^[^/]+\.md$' | grep -vE '^(README|CHANGELOG|LICENSE|CONTRIBUTING|CODE_OF_CONDUCT|CLAUDE)\.md$'
```

## Gitignore Recommendations

After cleanup, suggest adding to .gitignore:

```gitignore
# Build artifacts
build/
dist/
out/
*.apk
*.aab
*.ipa
*.app
*.dSYM
DerivedData/

# Dependencies
node_modules/
Pods/
.gradle/
vendor/
__pycache__/
.pnpm-store/

# Temp files
*.log
*.tmp
*.cache
*.swp
*.swo
.DS_Store
Thumbs.db
*~

# IDE
.vscode/
.idea/
*.iml
*.code-workspace
.project
.classpath
.settings/

# Environment
.env
.env.local
.env.*.local
credentials.json
secrets.yaml
*.pem
*.p12
*.keystore

# Platform specific
android/local.properties
android/captures/
ios/Pods/
.expo/
.expo-shared/

# AI-generated artifacts (don't commit these)
*DIAGNOSIS*.md
*ANALYSIS*.md
*SUMMARY*.md
*DEBUG*.md
*REPORT*.md
claude_conversation_*
chatgpt_export_*
conversation_*.md
transcript_*
scratch_*
draft_*
notes_*.md
```

## Safety Rules

- **Never remove files** - Only report candidates
- **Never modify .gitignore** - Only suggest additions
- **Flag secrets** - Warn about environment files
- **Preserve local files** - Always use `git rm --cached` in examples
- **Verify before removing** - User must review candidates

## Edge Cases

**Submodules:**
Check if paths are submodules before flagging:
```bash
git submodule status | awk '{print $2}'
```

**Empty directories:**
Git doesn't track empty directories. Skip directory-only checks.

**Symlinks:**
Git tracks symlinks. Include in scan but note they're symlinks.

**Binary files:**
Use `git ls-files` to identify tracked binaries:
```bash
git ls-files | xargs file | grep -v text
```

## Quick Reference

| Category | Command |
|----------|---------|
| Tracked gitignored | `git ls-files -i --exclude-standard` |
| Build artifacts | `git ls-files \| grep -E '\.apk$\|build/'` |
| Dependencies | `git ls-files \| grep -E '^node_modules/'` |
| Temp files | `git ls-files \| grep -E '\.log$\|\.DS_Store'` |
| IDE files | `git ls-files \| grep -E '^\.vscode/'` |
| Env files | `git ls-files \| grep -E '\.env'` |
| Large files | `git ls-files -z \| xargs -0 du -k` |
| Outdated | `git ls-files \| grep -E '\.orig$'` |
| AI artifacts | `git ls-files \| grep -iE 'DIAGNOSIS\|SUMMARY'` |

## Integration Steps

When invoked:

1. **Parse arguments** to determine repo path (default: current dir)
2. **Validate git repo** exists at path
3. **Run detection commands** for all categories
4. **Categorize findings** by type
5. **Calculate file sizes** for large files and dependency dirs
6. **Format output** with structured markdown
7. **Provide fix commands** for each category
8. **Suggest .gitignore additions** if patterns missing
9. **Warn about secrets** if environment files found
10. **Report summary** with total cleanup candidates

## Error Handling

- Path doesn't exist: Error with message
- Not a git repo: Error with helpful message
- No cleanup candidates: Success message
- Permission denied: Note which files couldn't be checked
- Binary files: Include but note they're binary

## Integration with Other Skills

**git-town:** Use after cleanup to ensure clean series of PRs without junk files.

**pr:** Run cleanup before creating PR to avoid committing unwanted files.

**review:** Cleanup skill checks tracked files; review skill checks PR changes (complementary).

**devbox:** Cleanup can identify `.devbox/virtenv/` files that shouldn't be committed (regenerated by plugin).
