# Contributing Guide

This guide helps you contribute to the devbox-plugins mobile development templates repository. The repository provides Devbox plugins for Android, iOS, and React Native with example projects demonstrating reproducible, project-local mobile development environments.

## Getting Started

### Prerequisites

Install Devbox following the instructions at [jetify.com/devbox](https://www.jetify.com/devbox/).

### Clone and Setup

Clone the repository and verify your environment.

```bash
# Clone the repository
git clone https://github.com/segment-integrations/devbox-plugins.git
cd devbox-plugins

# Install root dependencies
devbox shell

# Verify plugin installation in an example project
cd examples/android
devbox shell
devbox run android.sh devices list

# Return to root
cd ../..
```

### Repository Structure

```
.
├── plugins/
│   ├── android/          # Android plugin
│   ├── ios/              # iOS plugin
│   ├── react-native/     # React Native plugin
│   ├── tests/            # Plugin unit tests
│   └── CONVENTIONS.md    # Plugin development patterns
├── examples/
│   ├── android/          # Minimal Android app
│   ├── ios/              # Swift package example
│   └── react-native/     # React Native app
├── tests/                # E2E test scripts
├── .github/workflows/    # CI/CD workflows
└── devbox.json           # Root devbox config
```

### Using Plugins in Projects

Reference plugins from GitHub using the Devbox plugin syntax.

```json
{
  "include": [
    "github:segment-integrations/devbox-plugins?dir=plugins/android",
    "github:segment-integrations/devbox-plugins?dir=plugins/ios",
    "github:segment-integrations/devbox-plugins?dir=plugins/react-native"
  ]
}
```

## Development Workflow

### Critical Rules

**Never modify `.devbox/virtenv/` directly.** These are temporary runtime directories regenerated from plugin sources. Changes to these files are lost when the virtenv regenerates.

**Correct workflow:**
1. Edit source files in `plugins/{platform}/scripts/`
2. Run `devbox run sync` to copy changes to example projects
3. The `.devbox/virtenv/` directories regenerate automatically on `devbox shell` or `devbox run`

**Development sync commands:**
- `devbox run sync` - Full sync, reinstalls all example projects (slow, complete)
- `scripts/dev/sync-examples.sh` - Quick sync, copies plugin scripts only (fast, development-only)

### Working with Plugins

Plugin configuration lives in `plugin.json`. This file defines initialization hooks, environment variables, and script locations. Runtime scripts go in the `scripts/` directory.

**Plugin directory layout:**
```
plugins/{platform}/
├── config/              # Template files copied to user projects
│   ├── devices/         # Default device definitions
│   └── *.yaml           # Process-compose test suites
├── scripts/             # Runtime scripts
│   ├── {platform}.sh    # Main CLI
│   ├── lib.sh           # Shared utilities
│   ├── env.sh           # Environment setup
│   └── {feature}.sh     # Feature scripts
├── plugin.json          # Plugin manifest
└── REFERENCE.md         # Complete API reference
```

### Script Layering Architecture

Plugin scripts follow strict layers to prevent circular dependencies. Scripts can only source/depend on scripts from earlier layers.

```
scripts/
├── lib/        # Layer 1: Pure utilities
├── platform/   # Layer 2: SDK/platform setup
├── domain/     # Layer 3: Domain operations (AVD, emulator, run)
├── user/       # Layer 4: User-facing CLI
└── init/       # Layer 5: Environment initialization
```

**Key principles:**
- `lib/`: Pure utility functions, no platform-specific logic
- `platform/`: SDK resolution, PATH setup, device configuration
- `domain/`: Internal domain operations - atomic, independent, orchestrated by layer 4
- `user/`: User-facing CLI commands - orchestrates domain operations
- `init/`: Environment initialization run by devbox hooks

Domain layer scripts cannot call each other. If two domain scripts need the same functionality, that functionality must be moved to the platform or lib layer.

### Device Management Workflow

Device definitions are JSON files in `devbox.d/{platform}/devices/`. Modify devices using CLI commands, not manual editing.

```bash
# Android - specify API level and device profile
devbox run --pure android.sh devices create pixel_api30 \
  --api 30 \
  --device pixel \
  --tag google_apis \
  --preferred_abi x86_64

# iOS - specify simulator runtime version
devbox run --pure ios.sh devices create iphone14 --runtime 16.4

# Regenerate lock file after changes
devbox run --pure {platform}.sh devices eval
```

After creating, updating, or deleting devices, regenerate the lock file. Lock files optimize CI by limiting which SDK versions are evaluated. Commit lock files to the repository.

### Debugging

Enable debug logging with environment variables.

```bash
# Platform-specific
ANDROID_DEBUG=1 devbox shell
IOS_DEBUG=1 devbox shell

# Global
DEBUG=1 devbox shell
```

Validate lock files after device changes.

```bash
devbox run --pure android.sh devices eval
devbox run --pure ios.sh devices eval
```

## Code Standards

### Code Philosophy

**Simplicity and readability first.** Code should be easy to understand at a glance. Prefer straightforward solutions over clever ones. If you need to explain what code does, the code is probably too complex.

**DRY and single responsibility.** Extract repeated logic into functions with clear names. Each function should do one thing well. Each file should have a focused purpose.

**Keep files focused and manageable.** Split large files by concern. When a file exceeds ~500 lines or contains unrelated functions, split it.

Example file organization:
- `lib.sh` - Generic utilities (path manipulation, JSON parsing, logging)
- `devices.sh` - Device management operations
- `avd.sh` - AVD-specific operations
- `env.sh` - Environment variable setup

**Minimal comments in code.** Write self-documenting code with clear function and variable names. Use comments only for:
- Why decisions were made (not what the code does)
- Complex algorithms that can't be simplified
- Workarounds for external tool bugs

Document public APIs exhaustively in REFERENCE.md files, not in code comments.

**Fail loudly, avoid fallbacks.** When something is wrong, the code should exit with a clear error message and non-zero status. Avoid silent fallbacks that hide problems.

**Reduce edge cases and unexpected behavior.** Design for the common path. When edge cases arise, validate assumptions early and fail fast rather than adding complex branching logic.

**Scripts fail on error.** All shell scripts use `set -euo pipefail` (or `set -eu` for POSIX sh). Functions return 0 on success, non-zero on failure. Avoid `|| true` except in validation functions where warnings shouldn't block execution.

**Validation warns but doesn't block.** User-facing validation commands (like lock file checksum mismatches) should warn with actionable fix commands but never prevent the user from continuing. The validation philosophy is "inform, don't obstruct."

### Logging Standards

All logs must go to `${TEST_LOGS_DIR}` (defaults to `reports/logs/`), never to `/tmp/`.

**Use standardized logging functions from `lib.sh`:**

```bash
# Auto-detects script name from $0
android_log_info "Creating AVD: pixel_api30"
android_log_warn "Emulator already running"
android_log_error "APK not found"
android_log_debug "SDK path: /nix/store/..."

# Or explicitly provide script name
android_log_info "avd.sh" "Creating AVD: pixel_api30"
ios_log_warn "simulator.sh" "Simulator boot timeout"
```

**Output format:**
```
[INFO] [avd.sh] Creating AVD: pixel_api30
[WARN] [emulator.sh] Emulator already running
[ERROR] [deploy.sh] APK not found
[DEBUG] [core.sh] SDK path: /nix/store/...
```

**Log levels:**
- `android_log_debug` / `ios_log_debug` - Only shown when `DEBUG=1` or `ANDROID_DEBUG=1` / `IOS_DEBUG=1`
- `android_log_info` / `ios_log_info` - Always shown
- `android_log_warn` / `ios_log_warn` - Always shown
- `android_log_error` / `ios_log_error` - Always shown

**File logging paths:**

```bash
# Use environment variables (preferred)
echo "$data" > "${TEST_LOGS_DIR}/test-output.txt"
mkdir -p "${TEST_LOGS_DIR}"
log_file="${TEST_LOGS_DIR}/$(date +%Y%m%d-%H%M%S)-test.log"

# Or use hardcoded path if variables unavailable
echo "$data" > reports/logs/test-output.txt
mkdir -p reports/logs
```

**Incorrect:**
```bash
echo "$data" > /tmp/test-output.txt  # WRONG - /tmp not project-local
log_file="/tmp/test.log"              # WRONG - may be cleaned up by system
```

### Process Isolation and Safety

**Critical rule:** Only terminate processes that we explicitly started. Never interfere with external processes that may have been spawned by other projects.

**Implementation requirements:**

1. **Track Process IDs:** When starting a process, record its PID in a project-local file.
2. **Verify Before Killing:** Before terminating a process, verify the PID file exists, the process is still running, and the process is what we expect.
3. **Let Process Managers Handle Lifecycle:** When using process-compose, let it manage process termination. Cleanup scripts should only remove state files.

This ensures multiple projects can run simultaneously without conflicts and enables reproducible, conflict-free execution.

### Naming Standards

**Environment Variables:**
```
{PLATFORM}_{CATEGORY}_{DESCRIPTOR}

Examples:
- ANDROID_DEFAULT_DEVICE
- ANDROID_SDK_ROOT
- IOS_DEVELOPER_DIR
- ANDROID_BUILD_TOOLS_VERSION
```

**Shell Scripts:**
```
{platform}.sh       - Main CLI entry point (android.sh, ios.sh)
{feature}.sh        - Feature-specific scripts (devices.sh, avd.sh, env.sh)
lib.sh              - Shared utility functions
test-{feature}.sh   - Test scripts
```

**Shell Functions:**
```
{platform}_{category}_{action}

Examples:
- android_devices_list
- android_devices_create
- ios_get_developer_dir
- android_validate_lock_file
```

**Device Files:**
```
{descriptor}.json   - Device definition files

Examples:
- min.json          - Minimum supported version
- max.json          - Maximum/latest version
- pixel_api30.json  - Descriptive device name
```

**Lock Files:**
```
devices.lock        - Generated lock file (plain text, device:checksum format)
```

**Cache Files:**
```
.{feature}.cache    - Hidden cache files with descriptive names

Examples:
- .xcode_dev_dir.cache
- .shellenv.cache
```

### Process-Compose Standards

**File naming:**
```
process-compose-{suite}.yaml

Examples:
- lint.yaml
- unit-tests.yaml
- e2e.yaml
```

**Process naming:**
```
{category}-{feature}

Examples:
- lint-android
- test-android-lib
- e2e-android
- summary
```

**Log locations:**
```
test-results/{suite-name}-logs

Examples:
- test-results/devbox-lint-logs
- test-results/android-repo-e2e-logs
```

**Always include a summary process:**
- Depends on all other processes with `process_completed` (not `process_completed_successfully`)
- Displays test results in clean, scannable format
- Lists log file locations for debugging

## Documentation Standards

Documentation is split into two types with different purposes.

### Guides and Examples

Help users accomplish tasks.

- Use prose style with short, digestible paragraphs (2-4 sentences)
- Only use bullet points and numbered lists for step-by-step instructions
- Focus on practical workflows and common use cases
- Include runnable code examples
- No marketing language or superlatives
- Examples: CLAUDE.md, CONVENTIONS.md, workflow README files

### Reference Documentation

Exhaustive explanations of all options.

- Document every user-facing option, variable, method, and command
- Organized by component (environment variables, CLI commands, config options)
- Concise descriptions without fluff
- Include valid values, defaults, and constraints
- Examples: REFERENCE.md files for each plugin

### General Writing Rules

- Write concisely. Remove unnecessary words.
- No marketing language. Avoid terms like "powerful," "seamless," "robust," "flexible."
- Use active voice. "The script validates" not "Validation is performed."
- One concept per paragraph.
- Code examples should be runnable and realistic.

## Testing Requirements

### Running Tests Locally

**Fast tests (lint + unit + integration):**
```bash
devbox run test:fast
```

**Plugin-specific tests:**
```bash
# Android plugin tests
cd plugins/tests/android
./test-lib.sh
./test-devices.sh

# iOS plugin tests
cd plugins/tests/ios
./test-lib.sh
./test-devices.sh
```

**End-to-end tests:**
```bash
# Android E2E
cd examples/android
devbox run test:e2e

# iOS E2E
cd examples/ios
devbox run test:e2e

# React Native E2E
cd examples/react-native
devbox run test:e2e:android
devbox run test:e2e:ios
devbox run test:e2e:web
```

### Test Categories

**Fast tests:**
- Linting and formatting checks
- Plugin unit tests (device management, validation, utilities)
- Quick integration tests

**E2E tests:**
- Full build and deployment workflows
- Emulator/simulator boot and app launch
- Tests min and max platform versions:
  - Android: API 21 (min) to API 36 (max)
  - iOS: iOS 15.4 (min) to iOS 26.2 (max)

### Running CI Locally

Use `act` to run GitHub Actions workflows locally (requires Docker).

```bash
# Install act
devbox add act

# Run specific jobs
act -j fast-tests
act -j android-e2e
act -j ios-e2e

# Run full workflow
act -W .github/workflows/pr-checks.yml
```

### Coverage Expectations

- New features should include unit tests
- Bug fixes should include regression tests
- CLI commands should have integration tests
- Changes to device management should update E2E tests

## Pull Request Process

### Before Submitting

1. Run fast tests locally: `devbox run test:fast`
2. Test affected platform E2E tests
3. Update REFERENCE.md if adding/changing public APIs
4. Update device lock files if changing device definitions
5. Ensure commit messages follow conventions

### Commit Message Format

Use conventional commit format:

```
{type}({scope}): {description}

Examples:
- feat(android): add device sync command
- fix(ios): resolve Xcode path caching issue
- docs(contributing): add naming standards
- test(android): add device management tests
- refactor(react-native): simplify plugin composition
```

**Types:** feat, fix, docs, test, refactor, perf, chore

**Scopes:** android, ios, react-native, ci, docs, tests

### PR Checklist

Before submitting your pull request:

- [ ] Fast tests pass locally
- [ ] E2E tests pass for affected platforms
- [ ] Code follows naming conventions
- [ ] Functions follow DRY principles
- [ ] Scripts use standardized logging
- [ ] Process isolation rules followed
- [ ] Public APIs documented in REFERENCE.md
- [ ] Device lock files updated if needed
- [ ] Commit messages follow conventions

### Review Process

Pull requests require approval from maintainers. The CI runs fast tests automatically on every PR. Full E2E tests run on a weekly schedule or can be triggered manually.

Reviewers check for:
- Code simplicity and readability
- Adherence to naming conventions
- Proper error handling and validation
- Test coverage
- Documentation completeness

## CI/CD

### Fast PR Checks (`pr-checks.yml`)

Runs automatically on every PR.

- Plugin validation and quick smoke tests
- Fast tests (lint + unit + integration)
- E2E tests for min and max devices on each platform

### Full E2E Tests (`e2e-full.yml`)

Manual trigger or weekly schedule.

- Tests min/max platform versions comprehensively
- Android: API 21 (min) to API 36 (max)
- iOS: iOS 15.4 (min) to iOS 26.2 (max)
- React Native: Full cross-platform testing
- Matrix execution for parallel testing

### Workflow Structure

Both workflows use matrix execution to test multiple platforms and devices in parallel. They cache build artifacts (Gradle, CocoaPods, Xcode) to speed up execution. All workflows upload reports and logs as artifacts when tests complete.

## Additional Resources

For complete command and configuration references, see:
- `../reference/android.md` - Android plugin API reference
- `../reference/ios.md` - iOS plugin API reference
- `../reference/react-native.md` - React Native plugin API reference
- `../../CONVENTIONS.md` - Plugin development patterns and best practices
- `../../.github/workflows/README.md` - CI/CD workflow documentation

## Questions and Support

For questions about contributing:
- Open an issue on GitHub
- Review existing issues and pull requests
- Check the REFERENCE.md files for API documentation
- Review CONVENTIONS.md for development patterns
