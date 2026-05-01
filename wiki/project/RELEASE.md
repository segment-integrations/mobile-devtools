# Release Process

This document describes the release process for the devbox-plugins repository.

## Overview

**Plugins (Android, iOS, React Native)**: GitHub-based, ref-based distribution with no explicit version numbers. Users reference plugins directly via GitHub URLs and can pin to specific commits or tags.

## Versioning Strategy

### Plugins

Plugins use GitHub-based distribution without explicit version numbers.

**How users reference plugins:**
```json
{
  "include": [
    "github:segment-integrations/devbox-plugins?dir=plugins/android",
    "github:segment-integrations/devbox-plugins?dir=plugins/ios&ref=main",
    "github:segment-integrations/devbox-plugins?dir=plugins/react-native&ref=v1.2.0"
  ]
}
```

**Reference types:**
- No ref specified: Uses repository's default branch (main)
- `ref=main`: Tracks latest changes on main branch
- `ref=v1.2.0`: Pins to specific tag
- `ref=abc123`: Pins to specific commit SHA

**When to create tags:**
- Major plugin changes that warrant a stable reference point
- Before making breaking changes (tag the last stable version)
- When users need a stable version for production use

**Tag format:** `v{major}.{minor}.{patch}` (e.g., `v1.2.0`, `v2.0.0`)

Tags are created manually via git and pushed to GitHub:
```bash
git tag -a v1.2.0 -m "Release plugins v1.2.0"
git push origin v1.2.0
```

## Conventional Commits

All commits must follow conventional commit format for automated release notes and version bumping.

**Format:**
```
{type}({scope}): {description}

[optional body]

[optional footer]
```

### Commit Types

**Types that trigger releases:**
- `feat`: New feature (triggers minor version bump)
- `fix`: Bug fix (triggers patch version bump)
- `perf`: Performance improvement (triggers patch version bump)
- `revert`: Revert previous commit (triggers patch version bump)
- `docs`: Documentation changes (triggers patch version bump, except README-only changes)
- `refactor`: Code refactoring without behavior change (triggers patch version bump)
- `style`: Code style changes (triggers patch version bump)

**Types that do NOT trigger releases:**
- `chore`: Maintenance tasks, dependency updates
- `test`: Test changes
- `build`: Build system changes
- `ci`: CI/CD configuration changes

### Scopes

Common scopes in this repository:
- `android`: Android plugin
- `ios`: iOS plugin
- `react-native`: React Native plugin
- `ci`: CI/CD workflows
- `docs`: Documentation
- `tests`: Test infrastructure

### Examples

**Feature commits:**
```
feat(android): add device sync command

Adds a new `android.sh devices sync` command that synchronizes
AVDs with device definitions in devbox.d/android/devices/.

Closes #123
```

**Bug fix commits:**
```
fix(ios): resolve Xcode path caching issue

The Xcode developer directory cache was not being invalidated
after the TTL expired. Now checks cache age before using cached value.
```

**Breaking changes:**
```
feat(android)!: change device definition schema

BREAKING CHANGE: Device definitions now require explicit ABI field.
Previous schema used 'preferred_abi', now uses 'abi'.

Migration: Rename 'preferred_abi' to 'abi' in all device JSON files.
```

**Chore commits (no release):**
```
chore(deps): update @modelcontextprotocol/sdk to 0.6.0
```

```
chore: update lock files from test runs
```

**Documentation commits:**
```
docs(android): add AVD troubleshooting guide
```

```
docs: fix typo in RELEASE.md
```

**Test commits:**
```
test(react-native): add Metro port management unit tests
```

## Plugin Releases

Plugins do not have explicit version numbers or formal releases, but best practices apply for changes.

### Making Plugin Changes

**Non-breaking changes** (new features, bug fixes):
- Make changes in `plugins/{platform}/`
- Follow conventional commit format
- Sync to examples: `devbox run sync` or `scripts/dev/sync-examples.sh`
- Test changes in example projects
- Submit PR with descriptive commit messages
- Changes take effect immediately for users tracking main branch

**Breaking changes** (schema changes, removed features):
- Tag the current stable version before making changes:
  ```bash
  git tag -a v1.4.0 -m "Last stable before breaking changes"
  git push origin v1.4.0
  ```
- Make breaking changes
- Update plugin REFERENCE.md with migration guide
- Use conventional commit with `BREAKING CHANGE:` footer
- Document migration path in commit message
- Update example projects to use new API

**Adding new plugins:**
- Create plugin directory: `plugins/{name}/`
- Add `plugin.json` manifest
- Add runtime scripts in `scripts/`
- Create REFERENCE.md documentation
- Add example project in `examples/{name}/`
- Update root README.md to list new plugin

### Plugin Tag Strategy

Tags provide stable reference points for users who need pinned versions:

**When to tag:**
- Before breaking changes (tag last stable version)
- After significant feature additions (tag new capabilities)
- For production-ready milestones (tag stable releases)
- When documentation references specific versions

**Tag naming:**
- Format: `v{major}.{minor}.{patch}`
- Example: `v1.2.0`, `v2.0.0`, `v1.4.3`
- Increment major for breaking changes
- Increment minor for new features
- Increment patch for bug fixes

**Creating tags:**
```bash
# Tag current commit
git tag -a v1.2.0 -m "Release v1.2.0: Add device sync feature"
git push origin v1.2.0

# Tag specific commit
git tag -a v1.2.0 abc1234 -m "Release v1.2.0"
git push origin v1.2.0

# List existing tags
git tag -l

# Delete tag (if needed)
git tag -d v1.2.0
git push origin :refs/tags/v1.2.0
```

## Release Checklist

### Pre-Release

**For plugin releases (if tagging):**
- [ ] All plugin tests pass: `cd plugins/tests/{platform} && ./test-*.sh`
- [ ] Example projects tested: `cd examples/{platform} && devbox run build`
- [ ] REFERENCE.md updated with new features
- [ ] Device lock files regenerated if devices changed
- [ ] Breaking changes documented in commit messages
- [ ] Migration guide added to REFERENCE.md if breaking changes

### Release Execution

**Plugin tagging (manual):**
1. Ensure main branch is at the commit to tag
2. Create annotated tag: `git tag -a v1.2.0 -m "Release v1.2.0"`
3. Push tag: `git push origin v1.2.0`
4. Verify tag appears on GitHub releases page

### Post-Release Verification

**For plugin tags:**
- [ ] Tag appears on GitHub releases page
- [ ] Tag can be referenced in devbox.json:
  ```json
  {
    "include": [
      "github:segment-integrations/devbox-plugins?dir=plugins/android&ref=v1.2.0"
    ]
  }
  ```
- [ ] Example project using tag works: `devbox shell`

### Rollback Procedure

**Plugin rollback:**

If plugin changes cause issues:

1. **Revert commit on main**:
   ```bash
   git revert abc1234
   git push origin main
   ```
   Users tracking main get the revert immediately.

2. **Tag previous stable version**:
   ```bash
   git tag -a v1.3.1 <commit-before-bug> -m "Stable version before bug"
   git push origin v1.3.1
   ```
   Document the stable tag in issue/PR comments.

3. **Communicate to users**:
   - Create GitHub issue describing the problem
   - Recommend pinning to stable tag in issue description
   - Document rollback in PR that introduced the bug

## Breaking Changes

### What Constitutes a Breaking Change

**For plugins:**
- Changes to device definition schema (required fields, field names)
- Removal of CLI commands or options
- Changes to environment variable names or behavior
- Changes to script exit codes or output format
- Removal of supported platform versions
- Changes to default behavior that affect existing projects

### Communicating Breaking Changes

**In commit messages:**
```
feat(android)!: change device definition schema

BREAKING CHANGE: Device definitions now require explicit 'abi' field.
The 'preferred_abi' field has been renamed to 'abi'.

Migration:
1. Rename 'preferred_abi' to 'abi' in all device JSON files
2. Run `devbox run android.sh devices eval` to regenerate lock file

Before:
{
  "name": "pixel",
  "api": 30,
  "preferred_abi": "x86_64"
}

After:
{
  "name": "pixel",
  "api": 30,
  "abi": "x86_64"
}
```

**In REFERENCE.md:**
- Add "Breaking Changes" section at top
- Document what changed and why
- Provide migration guide with examples
- List affected versions

**In GitHub releases:**
- Semantic-release automatically highlights breaking changes
- Release notes show BREAKING CHANGE section prominently
- Include migration guide link

### Migration Guides

Migration guides should include:

1. **What changed**: Specific API or behavior change
2. **Why it changed**: Rationale for the breaking change
3. **How to migrate**: Step-by-step instructions
4. **Code examples**: Before and after examples
5. **Timeline**: Deprecation period if applicable

Example migration guide structure:
```markdown
## Migration Guide: Device Definition Schema v2

### What Changed
Device definitions now use 'abi' instead of 'preferred_abi'.

### Why
The 'preferred' prefix was misleading - the ABI is required, not preferred.

### How to Migrate
1. Update all device JSON files in devbox.d/{platform}/devices/
2. Rename 'preferred_abi' to 'abi'
3. Regenerate lock file: `devbox run {platform}.sh devices eval`
4. Test device creation: `devbox run {platform}.sh devices sync`

### Before
{
  "name": "pixel",
  "api": 30,
  "preferred_abi": "x86_64"
}

### After
{
  "name": "pixel",
  "api": 30,
  "abi": "x86_64"
}

### Affected Versions
- Breaking change introduced in v2.0.0
- Last version supporting old schema: v1.4.0
```

### Deprecation Strategy

For non-urgent breaking changes, follow a deprecation period:

1. **Announce deprecation** (version N):
   - Add deprecation warning to code
   - Document in REFERENCE.md
   - Support both old and new API

2. **Warn users** (version N through N+2):
   - Log warnings when deprecated API is used
   - Direct users to migration guide
   - Provide 2-3 versions for migration

3. **Remove deprecated API** (version N+3):
   - Breaking change release
   - Remove old API completely
   - Document removal in CHANGELOG

Example deprecation timeline:
```
v1.2.0: Add new API, deprecate old API, log warnings
v1.3.0: Still support both, continue warnings
v1.4.0: Still support both, final warning
v2.0.0: Remove old API (breaking change)
```

## Hotfixes

### When Hotfixes Are Needed

Hotfixes are needed for:
- Critical security vulnerabilities
- Data loss bugs
- Complete feature breakage
- CI/CD system failures preventing all users from building

Hotfixes are NOT needed for:
- Minor bugs with workarounds
- Documentation errors
- Performance issues
- Feature requests

### Hotfix Workflow

**For plugins:**

1. **Create fix on main branch**:
   ```bash
   # Fix bug in plugins/{platform}/
   git add plugins/{platform}/
   git commit -m "fix({platform}): critical bug description"
   git push origin main
   ```

2. **Tag hotfix version** (if users need stable reference):
   ```bash
   git tag -a v1.2.1 -m "Hotfix: critical bug description"
   git push origin v1.2.1
   ```

3. **Communicate fix**:
   - Comment on related issues
   - Update PR with hotfix info
   - Document in plugin CHANGELOG.md if significant

### Backporting to Release Branches

This repository does not maintain release branches. All fixes go to main branch.

**Rationale:**
- Plugins are consumed from main or tagged commits
- Plugins are distributed via GitHub (no release branches needed)
- Users can pin to specific tags for stability
- Maintaining release branches adds complexity without clear benefit

**If backporting becomes necessary:**
1. Create release branch: `git checkout -b release/v1.x`
2. Cherry-pick fix: `git cherry-pick <commit-sha>`
3. Tag backport: `git tag -a v1.2.1 -m "Backport: fix description"`
4. Push branch and tag: `git push origin release/v1.x v1.2.1`

## Release URLs and Resources

**Plugins:**
- Main branch: https://github.com/segment-integrations/devbox-plugins
- Tags: https://github.com/segment-integrations/devbox-plugins/tags
- Releases: https://github.com/segment-integrations/devbox-plugins/releases

**CI/CD:**
- PR checks: https://github.com/segment-integrations/devbox-plugins/actions/workflows/pr-checks.yml

**Documentation:**
- Android Plugin: https://github.com/segment-integrations/devbox-plugins/blob/main/plugins/android/REFERENCE.md
- iOS Plugin: https://github.com/segment-integrations/devbox-plugins/blob/main/plugins/ios/REFERENCE.md
- React Native Plugin: https://github.com/segment-integrations/devbox-plugins/blob/main/plugins/react-native/REFERENCE.md
