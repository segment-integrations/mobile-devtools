# Testing Guide

This document describes the testing infrastructure for the Devbox mobile plugins repository. Tests are organized into multiple categories with different purposes and execution speeds.

## Overview

### Testing Philosophy

Tests are designed to provide fast feedback during development while ensuring comprehensive coverage before merging. The test suite uses process-compose for orchestration, enabling parallel execution, automatic dependency management, and health checks.

**Key principles:**
- Fast tests run frequently during development
- Slow tests run before merging or in CI
- Tests are isolated and reproducible
- All tests use project-local state (no global pollution)
- Process-compose orchestrates complex workflows

### Test Categories

Tests are organized into three categories by speed and scope:

| Category | Purpose | When to Run |
|----------|---------|-------------|
| **Fast Tests** | Linting, unit tests, integration tests | After every code change |
| **Plugin Tests** | Plugin script validation | Before committing |
| **E2E Tests** | Full workflow with emulators/simulators | Before merging, in CI |

## Test Categories

### Fast Tests

Fast tests provide quick feedback without starting emulators or simulators.

**What they include:**
- Shellcheck linting for all scripts
- GitHub workflow syntax validation
- Plugin unit tests (lib.sh, devices.sh)
- Integration tests (device management, validation, caching)

**Running fast tests:**
```bash
# Run all fast tests
devbox run test:fast

# Or run individual categories
devbox run lint                    # Linting only
devbox run test:plugin:unit        # Plugin unit tests
devbox run test:integration        # Integration tests
```

**Typical output:**
```
Running fast tests (lint + unit + integration)...
✓ Shellcheck: Android scripts
✓ Shellcheck: iOS scripts
✓ Android lib.sh: 45 tests passed
✓ Android devices.sh: 23 tests passed
✓ iOS lib.sh: 38 tests passed
✓ Integration: device management
✓ Integration: validation logic
```

### Plugin Tests

Plugin tests validate individual plugin scripts without full application workflows.

**What they test:**

**Android plugin tests:**
- `test-lib.sh` - Utility functions (path manipulation, JSON parsing, logging)
- `test-devices.sh` - Device CLI commands (list, create, delete, eval)
- `test-device-mgmt.sh` - Device CRUD operations with fixtures
- `test-validation.sh` - Lock file validation and checksum verification
- `test-emulator-detection.sh` - Emulator state detection
- `test-emulator-modes.sh` - Pure mode vs development mode behavior

**iOS plugin tests:**
- `test-lib.sh` - Utility functions (Xcode discovery, version parsing)
- `test-devices.sh` - Device CLI commands (list, create, delete, eval)
- `test-device-mgmt.sh` - Simulator management with fixtures
- `test-cache.sh` - Cache invalidation and TTL behavior
- `test-simulator-detection.sh` - Simulator state detection
- `test-simulator-modes.sh` - Pure mode vs development mode behavior

**Running plugin tests:**
```bash
# Run all plugin tests
devbox run test:plugin:unit

# Or run specific platforms
devbox run test:plugin:android
devbox run test:plugin:ios

# Or run specific test files
devbox run test:plugin:android:lib
devbox run test:plugin:ios:devices
```

### E2E Tests

E2E tests validate complete application workflows with real emulators and simulators.

**What they test:**
- Full application lifecycle (build → deploy → verify)
- Emulator/simulator startup and boot verification
- APK/app installation and launch
- Process isolation and cleanup

**Running E2E tests:**
```bash
# Run all E2E tests (orchestrated: android+ios parallel, then react-native)
devbox run test:e2e

# Or run individual platforms
devbox run test:e2e:android         # Android only
devbox run test:e2e:ios             # iOS only
devbox run test:e2e:rn              # React Native (both platforms)
```

**E2E test workflow:**
```
Phase 1: Parallel execution (Android + iOS)
  Android E2E:
    1. Create/sync AVD definitions
    2. Build Android app
    3. Start emulator (with boot verification)
    4. Install APK
    5. Launch app
    6. Verify app is running
    7. Cleanup (stop emulator)

  iOS E2E:
    1. Create/sync simulator definitions
    2. Build iOS app
    3. Start simulator (with boot verification)
    4. Install app bundle
    5. Launch app
    6. Verify app is running
    7. Cleanup (stop simulator)

Phase 2: React Native (after Android + iOS complete)
    1. Install Node dependencies
    2. Build web bundle
    3. Run Android workflow
    4. Run iOS workflow
```

## Running Tests Locally

### Quick Commands

```bash
# Fast feedback during development
devbox run test:fast               # Lint + unit + integration

# Before committing
devbox run test:plugin:unit        # All plugin tests

# Before merging
devbox run test:e2e                # Full E2E suite

# Everything
devbox run test                    # Fast + E2E
```

### Platform-Specific Tests

```bash
# Android only
devbox run test:android            # Fast Android tests
devbox run test:e2e:android        # Android E2E

# iOS only
devbox run test:ios                # Fast iOS tests
devbox run test:e2e:ios            # iOS E2E

# React Native
devbox run test:rn                 # Linting only
devbox run test:e2e:rn             # React Native E2E
```

### Using --pure vs Development Mode

Tests support two execution modes:

**Development mode (default):**
- Reuses existing emulators/simulators if available
- Fast iteration (no startup overhead)
- No automatic cleanup
- Uses cached builds

```bash
# Development mode (default)
devbox run test:e2e:ios
```

**Pure mode (--pure flag):**
- Creates fresh emulators/simulators
- Clean state (no cached data)
- Automatic cleanup after tests
- Deterministic, reproducible

```bash
# Pure mode (isolated execution)
devbox run --pure test:e2e:ios
```

**Note:** E2E test commands in `devbox.json` automatically use `--pure` mode when appropriate (e.g., in CI).

### Interactive TUI Mode

Process-compose provides an interactive Terminal UI for monitoring test execution.

**Enable TUI mode:**
```bash
# With TUI (interactive monitoring)
TEST_TUI=true devbox run test:unit

# Default (non-interactive, for CI)
devbox run test:unit
```

**TUI controls:**
- `h` - Help
- `q` - Quit
- Arrow keys - Navigate processes
- Enter - View process logs

### Debugging Failed Tests

When tests fail, follow this workflow:

**1. Check the summary output:**
```bash
devbox run test:fast
# Output shows which test suite failed
```

**2. View detailed logs:**
```bash
# Logs are in reports/ directory
ls -la reports/logs/

# View specific test log
cat reports/logs/android-test-lib.txt
cat reports/logs/ios-test-devices.txt
```

**3. Run the specific failing test:**
```bash
# Run just the failing test
devbox run test:plugin:android:lib
```

**4. Enable debug logging:**
```bash
# Platform-specific debug mode
ANDROID_DEBUG=1 devbox run test:plugin:android:lib
IOS_DEBUG=1 devbox run test:plugin:ios:devices

# Global debug mode
DEBUG=1 devbox shell
```

**5. Run with TUI to see live progress:**
```bash
TEST_TUI=true devbox run test:unit
```

## Writing Tests

### Test File Structure

Tests follow a consistent structure across all platforms:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Setup logging
SCRIPT_DIR_NAME="$(basename "$(dirname "$0")")"
SCRIPT_NAME="$(basename "$0" .sh)"
mkdir -p "${TEST_LOGS_DIR:-reports/logs}"
LOG_FILE="${TEST_LOGS_DIR:-reports/logs}/${SCRIPT_DIR_NAME}-${SCRIPT_NAME}.txt"
exec > >(tee "$LOG_FILE")
exec 2>&1

# Source test framework
. "path/to/test-framework.sh"

# Test cases
start_test "Description of test"
assert_equal "expected" "actual" "Test message"
assert_success "some_command" "Command should succeed"
assert_file_exists "/path/to/file" "File should exist"

# Summary (exits with 1 if any tests failed)
test_summary "test-suite-name"
```

### Test Framework API

The test framework (`plugins/tests/test-framework.sh`) provides assertion helpers:

**Assertions:**
```bash
# Equality check
assert_equal "expected" "actual" "Optional message"

# File checks
assert_file_exists "/path/to/file" "File exists message"
assert_file_contains "/path/to/file" "pattern" "Contains pattern message"

# Command execution
assert_command_success "Command succeeds" command arg1 arg2

# Summary (exits with failure if tests failed)
test_summary "suite-name"
```

**Output format:**
```
✓ Test passed
✗ Test failed
  Expected: 'value1'
  Actual:   'value2'

==================================
Test Results:
  Passed: 45
  Failed: 2
==================================
```

### Test Naming Conventions

**Test files:**
```
test-{feature}.sh           # Unit test file
test-{feature}-mgmt.sh      # Integration test file
```

**Test functions:**
```bash
start_test "Feature: specific behavior"
start_test "CLI: command with valid input"
start_test "Validation: checksum mismatch"
```

**Examples:**
- `plugins/tests/android/test-lib.sh` - Android lib.sh unit tests
- `plugins/tests/ios/test-devices.sh` - iOS devices.sh CLI tests
- `tests/integration/android/test-device-mgmt.sh` - Android device management integration

### Logging Standards

All test output must go to `${TEST_LOGS_DIR}` (defaults to `reports/logs/`).

**Use standardized logging functions:**
```bash
# In plugin scripts (from lib.sh)
android_log_info "Test starting"
android_log_warn "Potential issue detected"
android_log_error "Test failed"
android_log_debug "Verbose diagnostic info"

ios_log_info "simulator.sh" "Simulator booting"
```

**File logging in tests:**
```bash
# Always use project-local paths
LOG_FILE="${TEST_LOGS_DIR:-reports/logs}/test-output.txt"
exec > >(tee "$LOG_FILE")
exec 2>&1

# NEVER use /tmp/ for test logs
```

## Process-Compose Test Suites

### Suite Structure

Process-compose test suites define orchestrated workflows with dependencies, health checks, and cleanup.

**Basic structure:**
```yaml
version: "0.5"

log_location: "${REPORTS_DIR:-reports}/test-suite-logs"
log_level: info

environment:
  - "TEST_TIMEOUT=300"
  - "BOOT_TIMEOUT=120"

processes:
  # Test process
  test-feature:
    command: "bash tests/test-feature.sh"
    availability:
      restart: "no"

  # Summary - runs after test completes
  summary:
    command: "bash tests/test-summary.sh 'Suite Name' 'reports/logs'"
    depends_on:
      test-feature:
        condition: process_completed
    availability:
      restart: "no"
```

### Process Dependencies

Use `depends_on` to control execution order:

```yaml
processes:
  build-app:
    command: "devbox run build"
    availability:
      restart: "no"

  start-emulator:
    command: "android.sh emulator start"
    depends_on:
      build-app:
        condition: process_completed_successfully
    availability:
      restart: "no"

  deploy-app:
    command: "android.sh deploy"
    depends_on:
      build-app:
        condition: process_completed_successfully
      start-emulator:
        condition: process_healthy
    availability:
      restart: "no"
```

**Condition types:**
- `process_completed` - Process finished (any exit code)
- `process_completed_successfully` - Process finished with exit code 0
- `process_healthy` - Process passed readiness probe

### Health Checks

Readiness probes verify process state before dependent processes start:

```yaml
processes:
  metro-bundler:
    command: "metro.sh start ios"
    readiness_probe:
      exec:
        command: "metro.sh health ios ios"
      initial_delay_seconds: 5
      period_seconds: 5
      timeout_seconds: 60
      success_threshold: 1
    availability:
      restart: "no"

  deploy-app:
    depends_on:
      metro-bundler:
        condition: process_healthy
    command: "deploy-app.sh"
    availability:
      restart: "no"
```

**Readiness probe fields:**
- `initial_delay_seconds` - Wait before first check
- `period_seconds` - Time between checks
- `timeout_seconds` - Total timeout for health
- `success_threshold` - Consecutive successes needed

### Summary Processes

All test suites should include a summary process:

```yaml
processes:
  summary:
    command: "bash tests/test-summary.sh 'Test Suite Name' 'reports/logs'"
    depends_on:
      test-feature:
        condition: process_completed  # Use process_completed, not process_completed_successfully
    availability:
      restart: "no"
    shutdown:
      signal: 15
      timeout_seconds: 1
```

**Why `process_completed`:**
Using `process_completed` (not `process_completed_successfully`) ensures the summary runs even when tests fail, displaying results and logs.

### Log Management

Process-compose automatically manages per-process logs:

**Configure log location:**
```yaml
log_location: "${REPORTS_DIR:-reports}/test-suite-logs"
log_level: info
```

**Access logs:**
```bash
# View all logs
ls -la reports/test-suite-logs/

# View specific process log
cat reports/test-suite-logs/process-name/out.log
tail -f reports/test-suite-logs/process-name/out.log
```

## Testing Best Practices

### Test Isolation

Tests must be isolated and not interfere with each other:

**Use temporary directories:**
```bash
TEST_ROOT="/tmp/test-$$"
mkdir -p "$TEST_ROOT"
cd "$TEST_ROOT"

# ... run tests ...

# Cleanup
rm -rf "$TEST_ROOT"
```

**Use unique suite names for parallel tests:**
```bash
# Allocate unique Metro ports for parallel React Native tests
metro_port=$(rn_allocate_metro_port "android-api21")  # Unique suite name
metro.sh start android-api21
```

**Clean up processes you started:**
```bash
# Track PIDs when starting processes
echo "$pid" > "${DEVBOX_VIRTENV}/runtime/process.pid"

# Kill only processes you started
if [ -f "${DEVBOX_VIRTENV}/runtime/process.pid" ]; then
  kill "$(cat "${DEVBOX_VIRTENV}/runtime/process.pid")" 2>/dev/null || true
  rm -f "${DEVBOX_VIRTENV}/runtime/process.pid"
fi
```

### Reproducible Environments

Use `--pure` mode for deterministic test execution:

```bash
# Pure mode: isolated, clean state
devbox run --pure test:e2e:android

# Pass environment variables with -e flag in pure mode
devbox run --pure -e ANDROID_DEFAULT_DEVICE=min test:e2e:android
```

**Pure mode behavior:**
- Clean environment (no inherited variables except those explicitly passed)
- Fresh emulators/simulators created
- Automatic cleanup after tests
- Deterministic execution

### Handling Timing Issues

Mobile tests often involve timing-sensitive operations:

**Use health checks instead of sleep:**
```yaml
# Bad: arbitrary sleep
deploy-app:
  command: |
    start-emulator.sh
    sleep 60  # Hope emulator is ready
    deploy.sh

# Good: readiness probe
start-emulator:
  command: "android.sh emulator start"
  readiness_probe:
    exec:
      command: "android.sh emulator status"
    period_seconds: 5
    timeout_seconds: 120

deploy-app:
  command: "deploy.sh"
  depends_on:
    start-emulator:
      condition: process_healthy
```

**Retry with timeout:**
```bash
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if emulator_is_ready; then
    break
  fi
  attempt=$((attempt + 1))
  echo "Waiting for emulator... (attempt $attempt/$max_attempts)"
  sleep 2
done

if [ $attempt -eq $max_attempts ]; then
  echo "ERROR: Emulator did not start within timeout"
  exit 1
fi
```

### Process Tracking for Multi-Instance Scenarios

When running multiple instances of the same service (e.g., Metro bundler):

**Track process state with unique identifiers:**
```bash
# Allocate unique port
metro_port=$(rn_allocate_metro_port "android-api21")

# Save environment for this suite
rn_save_metro_env "android-api21" "$metro_port"

# Start Metro with unique suite name
metro.sh start android-api21

# Stop only this Metro instance
metro.sh stop android-api21
```

**Why this matters:**
- Multiple test suites can run in parallel
- Each suite has isolated state
- No port conflicts or process interference
- Clean separation enables `--pure` mode testing

## CI/CD Testing

### GitHub Actions Workflows

The repository includes two main CI workflows:

**1. PR Fast Checks (`pr-checks.yml`):**
- Runs automatically on every PR and push to main
- Fast validation
- Linting, unit tests, quick smoke tests

**2. Full E2E Tests (`e2e-full.yml`):**
- Manual trigger or weekly schedule
- Comprehensive testing
- Tests min/max platform versions (API 21-36, iOS 15.4-18.2)

### Running Tests in CI

**Automatic triggers:**
```yaml
# pr-checks.yml runs automatically
on:
  push:
    branches: [main]
  pull_request:
```

**Manual triggers:**
```yaml
# e2e-full.yml requires manual dispatch
on:
  workflow_dispatch:
    inputs:
      run_android:
        description: 'Run Android E2E tests'
        default: true
      run_ios:
        description: 'Run iOS E2E tests'
        default: true
```

**To run E2E tests manually:**
1. Go to GitHub Actions tab
2. Select "Full E2E Tests" workflow
3. Click "Run workflow"
4. Select platforms to test
5. Click "Run workflow"

### Running CI Locally with act

Test CI workflows locally before pushing:

```bash
# Install act (if not already installed)
devbox add act

# List available workflows
act -l

# Run specific job
act -j lint-and-validate
act -j android-plugin-tests
act -j ios-plugin-tests

# Run full PR checks workflow
act -W .github/workflows/pr-checks.yml

# Run with specific event
act push
act pull_request
```

**Limitations of act:**
- Cannot run macOS jobs (iOS tests) on Linux/Windows
- KVM acceleration may not work
- Some GitHub Actions features unsupported

### Artifacts and Logs

CI uploads artifacts on failure:

**View artifacts:**
1. Go to failed workflow run
2. Scroll to "Artifacts" section
3. Download logs (e.g., `android-e2e-logs`, `ios-e2e-logs`)

**Artifact contents:**
- Process-compose logs for each process
- Test output files from `reports/logs/`
- Emulator/simulator boot logs
- Build logs

**Local equivalent:**
```bash
# Run tests locally
devbox run test:e2e:android

# Logs are in reports/
ls -la reports/logs/
ls -la reports/e2e-logs/
```

### Debugging CI Failures

When tests fail in CI:

**1. Check the workflow summary:**
- Which job failed?
- What was the exit code?

**2. Download and examine artifacts:**
- Process logs show detailed output
- Look for errors, timeouts, or unexpected behavior

**3. Reproduce locally:**
```bash
# Use same environment as CI
devbox run --pure test:e2e:android

# Or with specific device
ANDROID_DEFAULT_DEVICE=min devbox run --pure test:e2e:android
```

**4. Enable debug logging in CI:**
Add to workflow YAML:
```yaml
env:
  ANDROID_DEBUG: 1
  DEBUG: 1
```

**5. Run with act to test workflow changes:**
```bash
# Test workflow locally before pushing
act -j android-plugin-tests
```

## Related Documentation

- `../../tests/README.md` - Test suite quick reference
- `../../examples/react-native/tests/README.md` - React Native test suites
- `../../.github/workflows/README.md` - CI/CD workflows
- `../../CONVENTIONS.md` - Plugin development patterns
- `../../CLAUDE.md` - Repository overview and critical rules
