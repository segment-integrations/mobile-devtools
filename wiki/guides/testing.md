# Testing Guide

This guide covers testing strategies, test execution, and debugging for all platforms. Whether you're running unit tests, integration tests, or full end-to-end tests, this guide explains how to run tests effectively and understand the results.

## Overview

The repository includes three categories of tests:

- **Unit Tests** - Test individual functions and components in isolation. Fast execution.
- **Integration Tests** - Test plugin workflows and device management. Medium speed.
- **E2E Tests** - Test complete application lifecycle from build to deployment. Slow execution.

All tests use [process-compose](https://github.com/F1bonacc1/process-compose) for orchestration, providing concurrent execution, dependency management, health checks, and structured logging.

## Quick Commands

### Fast Tests

```bash
# Unit tests only
devbox run test:plugin:unit

# Integration tests only
devbox run test:integration

# Everything except E2E
devbox run test:fast
```

### Platform-Specific Tests

```bash
# Android: lint + unit + integration
devbox run test:android

# iOS: lint + unit + integration
devbox run test:ios

# React Native: lint only
devbox run test:rn
```

### E2E Tests

```bash
# All E2E tests
devbox run test:e2e

# Individual platforms
devbox run test:e2e:android
devbox run test:e2e:ios
devbox run test:e2e:rn
```

### Complete Suite

```bash
# Everything
devbox run test
```

## Test Modes

Tests can run in two modes: development mode and pure mode. Understanding the difference helps you choose the right mode for your workflow.

### Development Mode

Development mode is the default for interactive work. It reuses existing emulators and simulators, keeps processes running after tests complete, and optimizes for fast iteration.

**Use development mode when:**
- Running tests locally during development
- Iterating quickly on code changes
- Debugging test failures
- Working on a single platform

**Behavior:**
- Reuses existing emulators/simulators if already running
- Starts emulator/simulator only if not already running
- Leaves emulator/simulator running after tests complete
- No cleanup of test artifacts
- Fast iteration between test runs

**Example:**
```bash
# Run in development mode (default)
devbox run test:android
```

### Pure Mode (`--pure`)

Pure mode creates a completely isolated test environment. It starts fresh emulators/simulators, runs in a clean environment, and performs full cleanup after tests complete.

**Use pure mode when:**
- Running in CI/CD pipelines
- Reproducing CI failures locally
- Verifying reproducible builds
- Testing on multiple devices in parallel

**Behavior:**
- Always starts fresh emulator/simulator
- Clean state with no cached data
- Automatic cleanup of all resources
- Completely isolated from other processes
- Environment variables reset unless passed with `-e` flag

**Example:**
```bash
# Run in pure mode
devbox run --pure test:e2e:android

# Pass environment variables in pure mode
devbox run --pure -e BOOT_TIMEOUT=300 test:e2e:android

# E2E tests automatically use pure mode
devbox run test:e2e:ios  # Runs with --pure by default
```

**Important:** When using `--pure`, environment variables must be passed with the `-e` flag. Setting them before the command does not work because pure mode resets the environment.

```bash
# Correct
devbox run --pure -e ANDROID_SKIP_SETUP=1 test:e2e:ios

# Incorrect (variable gets reset)
ANDROID_SKIP_SETUP=1 devbox run --pure test:e2e:ios
```

## Android Testing

### Running Android Tests

```bash
# Run all Android tests (lint + unit + integration)
devbox run test:android

# Individual test suites
devbox run test:android:lib            # Library function tests
devbox run test:android:devices        # Device list/management tests
devbox run test:android:device-mgmt    # Device CRUD operations
devbox run test:android:validation     # Validation logic tests
devbox run lint:android                # Shellcheck only

# E2E test
cd examples/android
devbox run test:e2e
```

### Android E2E Test Flow

The Android E2E test follows this sequence:

1. **Build** - Gradle assembles debug APK
2. **Sync AVDs** - Ensures emulator definitions match device configs
3. **Start Emulator** - Boots Android emulator (or reuses existing)
4. **Deploy** - Installs and launches APK
5. **Verify** - Checks that app is running
6. **Cleanup** - Stops app and emulator in pure mode

### Configuration

Configure Android tests via environment variables in `devbox.json`:

```json
{
  "env": {
    "ANDROID_APP_APK": "app/build/outputs/apk/debug/app-debug.apk",
    "ANDROID_APP_ID": "com.example.myapp",
    "ANDROID_DEFAULT_DEVICE": "max",
    "ANDROID_SERIAL": "emulator-5554",
    "TEST_TIMEOUT": "300",
    "BOOT_TIMEOUT": "90"
  }
}
```

### Android Test Logs

Logs are written to `reports/android-e2e-logs/`:

```bash
# View all logs
ls -la reports/android-e2e-logs/

# View specific process log
cat reports/android-e2e-logs/build-app.log
cat reports/android-e2e-logs/android-emulator.log
cat reports/android-e2e-logs/deploy-app.log
```

## iOS Testing

### Running iOS Tests

```bash
# Run all iOS tests (lint + unit + integration)
devbox run test:ios

# Individual test suites
devbox run test:ios:lib           # Library function tests
devbox run test:ios:device-mgmt   # Device CRUD operations
devbox run test:ios:cache         # Cache behavior tests
devbox run lint:ios               # Shellcheck only

# E2E test
cd examples/ios
devbox run test:e2e
```

### iOS E2E Test Flow

The iOS E2E test follows this sequence:

1. **Build** - xcodebuild compiles for iOS simulator
2. **Sync Simulators** - Ensures simulator definitions match device configs
3. **Start Simulator** - Boots iOS simulator (or reuses existing)
4. **Deploy** - Installs and launches app bundle
5. **Verify** - Checks that app is running
6. **Cleanup** - Cleans up test simulators in pure mode

### Configuration

Configure iOS tests via environment variables in `devbox.json`:

```json
{
  "env": {
    "IOS_APP_PROJECT": "MyApp.xcodeproj",
    "IOS_APP_SCHEME": "MyApp",
    "IOS_APP_BUNDLE_ID": "com.example.myapp",
    "IOS_APP_ARTIFACT": ".devbox/virtenv/ios/DerivedData/Build/Products/Debug-iphonesimulator/MyApp.app",
    "IOS_DEFAULT_DEVICE": "max",
    "IOS_DOWNLOAD_RUNTIME": "0",
    "TEST_TIMEOUT": "300",
    "BOOT_TIMEOUT": "120"
  }
}
```

### iOS Test Logs

Logs are written to `reports/ios-e2e-logs/`:

```bash
# View all logs
ls -la reports/ios-e2e-logs/

# View specific process log
cat reports/ios-e2e-logs/build-app.log
cat reports/ios-e2e-logs/ios-simulator.log
cat reports/ios-e2e-logs/deploy-app.log
```

## React Native Testing

React Native testing includes both Android and iOS E2E tests plus web bundle tests. The Metro bundler requires special handling for parallel test execution.

### Running React Native Tests

```bash
# All React Native tests (lint + E2E for both platforms)
devbox run test:rn

# Individual E2E tests
cd examples/react-native
devbox run test:e2e:android    # Android only
devbox run test:e2e:ios        # iOS only
devbox run test:e2e:web        # Web bundle test
devbox run test:e2e:all        # Both platforms in parallel
```

### Platform-Specific Optimization

Wrapper scripts skip the unused platform for faster startup:

```bash
# iOS tests only (skips Android SDK evaluation)
./tests/run-ios-tests.sh

# Android tests only (skips iOS setup)
./tests/run-android-tests.sh
```

These scripts use the correct `-e` flag syntax to pass environment variables in pure mode:

```bash
# iOS wrapper skips Android
devbox run --pure -e ANDROID_SKIP_SETUP=1 test:e2e:ios

# Android wrapper skips iOS
devbox run --pure -e IOS_SKIP_SETUP=1 test:e2e:android
```

### React Native E2E Test Flow

React Native E2E tests follow this sequence:

1. **Allocate Metro Port** - Reserves unique port for this test suite
2. **Build Node** - Install npm dependencies
3. **Build Platform** - Compile Android or iOS app
4. **Sync Devices** - Ensure emulator/simulator definitions match configs
5. **Start Emulator/Simulator** - Boot device (or reuse existing)
6. **Start Metro** - Launch Metro bundler on allocated port
7. **Deploy** - Install and launch app
8. **Verify** - Check app is running
9. **Cleanup** - Stop Metro, app, and device in pure mode

### Metro Bundler Management

The React Native plugin provides robust Metro bundler management with isolated state for parallel testing.

#### Automatic Metro Management

Process-compose handles Metro lifecycle automatically in test suites:

```yaml
# Metro is started automatically
metro-bundler:
  command: "metro.sh start android"
  depends_on:
    allocate-metro-port:
      condition: process_completed_successfully
  shutdown:
    command: "metro.sh stop android || true"
```

#### Manual Metro Control

For advanced scenarios, control Metro manually:

```bash
# Start Metro for specific suite
metro.sh start android

# Stop Metro for specific suite
metro.sh stop android

# Check Metro status
metro.sh status android

# Health check (exit code only, for readiness probes)
metro.sh health android ios

# Clean up Metro state files
metro.sh clean android
```

#### Metro Port Allocation

Metro uses dynamic port allocation in the range 8091-8199. Each test suite gets a unique port to enable parallel execution:

```bash
# Example from test suite
. ${REACT_NATIVE_VIRTENV}/scripts/lib/lib.sh
metro_port=$(rn_allocate_metro_port "android")
rn_save_metro_env "android" "$metro_port"
```

The allocated port is saved to an environment file that other processes source:

```bash
# Source Metro environment in deploy steps
. ${REACT_NATIVE_VIRTENV}/metro/env-android.sh
echo "Using Metro port: $METRO_PORT"
```

#### Metro State Files

Metro state is tracked in project-local files:

- `${DEVBOX_VIRTENV}/metro/port-{suite}.txt` - Allocated port number
- `${DEVBOX_VIRTENV}/metro/pid-{suite}.txt` - Metro process ID
- `${DEVBOX_VIRTENV}/metro/env-{suite}.sh` - Environment variables

### Parallel Testing Multiple Versions

To test multiple Android or iOS versions in parallel, create separate test suite files with unique suite names. The suite name isolates Metro bundler ports and state.

**Example: Testing API 21 and API 35 in parallel**

```yaml
# test-suite-android-api21.yaml
environment:
  - "ANDROID_DEFAULT_DEVICE=min"

processes:
  allocate-metro-port:
    command: |
      . ${REACT_NATIVE_VIRTENV}/scripts/lib/lib.sh
      metro_port=$(rn_allocate_metro_port "android-api21")
      rn_save_metro_env "android-api21" "$metro_port"

  metro-bundler:
    command: "metro.sh start android-api21"

  cleanup:
    command: "metro.sh stop android-api21"
```

```yaml
# test-suite-android-api35.yaml
environment:
  - "ANDROID_DEFAULT_DEVICE=max"

processes:
  allocate-metro-port:
    command: |
      . ${REACT_NATIVE_VIRTENV}/scripts/lib/lib.sh
      metro_port=$(rn_allocate_metro_port "android-api35")
      rn_save_metro_env "android-api35" "$metro_port"

  metro-bundler:
    command: "metro.sh start android-api35"

  cleanup:
    command: "metro.sh stop android-api35"
```

Run both test suites in parallel:

```bash
devbox run --pure test:android-api21 &
devbox run --pure test:android-api35 &
wait
```

Each test gets its own Metro instance on a unique port with isolated state files.

### Configuration

Configure React Native tests via environment variables:

```json
{
  "env": {
    "ANDROID_APP_ID": "com.reactnativeexample",
    "IOS_APP_BUNDLE_ID": "com.reactnativeexample",
    "BUILD_CONFIG": "Release",
    "TEST_TIMEOUT": "300"
  }
}
```

### Build Configuration

React Native tests support different build configurations:

- **Development mode** (`start:*` commands): Uses Debug builds for fast compilation
- **E2E tests** (`test:e2e:*` commands): Uses Release builds for production-like behavior

Override with environment variables:

```bash
# Force Debug build in E2E test
IOS_BUILD_CONFIG=Debug devbox run test:e2e:ios

# Force Release build in dev mode
BUILD_CONFIG=Release devbox run start:android
```

### React Native Test Logs

Logs are organized by test type:

- Development: `reports/react-native-{platform}-dev-logs/`
- E2E tests: `reports/react-native-{platform}-e2e-logs/`

```bash
# View Android E2E logs
ls -la reports/react-native-android-e2e-logs/

# View iOS E2E logs
ls -la reports/react-native-ios-e2e-logs/
```

## Process-Compose Orchestration

All test suites use process-compose for orchestration. Process-compose provides several advantages over plain shell scripts:

- Concurrent execution of independent processes
- Dependency management between processes
- Health checks with readiness and liveness probes
- Real-time status monitoring
- Automatic retry on failure
- Graceful shutdown handling
- Structured logging per process

### Understanding Test Suite YAML

A typical test suite defines processes with dependencies:

```yaml
version: "0.5"

environment:
  - "TEST_TIMEOUT=300"

log_location: "reports/test-logs"
log_level: info

processes:
  # Phase 1: Build (no dependencies)
  build-app:
    command: "gradle assembleDebug"
    availability:
      restart: "no"

  # Phase 2: Start emulator (after sync completes)
  android-emulator:
    command: "android.sh emulator start max"
    depends_on:
      sync-avds:
        condition: process_completed_successfully
    readiness_probe:
      exec:
        command: "adb shell getprop sys.boot_completed | grep -q 1"
      initial_delay_seconds: 10
      period_seconds: 5
      timeout_seconds: 180

  # Phase 3: Deploy (after build and emulator are ready)
  deploy-app:
    command: "android.sh run app.apk"
    depends_on:
      build-app:
        condition: process_completed_successfully
      android-emulator:
        condition: process_healthy
```

### Dependencies and Conditions

Process-compose supports several dependency conditions:

- `process_completed_successfully` - Process exited with code 0
- `process_completed` - Process exited (any exit code)
- `process_healthy` - Readiness probe succeeded
- `process_running` - Process is currently running

### Readiness Probes

Readiness probes verify that a process is ready before dependent processes start:

```yaml
readiness_probe:
  exec:
    command: "health-check-command"
  initial_delay_seconds: 10    # Wait before first check
  period_seconds: 5             # Check every 5 seconds
  timeout_seconds: 180          # Give up after 180 seconds
  success_threshold: 1          # Succeed after 1 successful check
  failure_threshold: 12         # Fail after 12 failed checks
```

Common readiness probes:

- **Android emulator**: Check `sys.boot_completed` property
- **iOS simulator**: Check `xcrun simctl bootstatus`
- **Metro bundler**: HTTP health check to Metro port
- **App container**: Check app container exists

### Shutdown Handling

Processes can define custom shutdown behavior:

```yaml
processes:
  metro-bundler:
    command: "metro.sh start android"
    shutdown:
      command: "metro.sh stop android || true"
      signal: 15
      timeout_seconds: 5
```

### Summary Process Pattern

All test suites use a summary process that displays results:

```yaml
summary:
  command: "bash tests/test-summary.sh 'Test Suite Name' 'logs/path'"
  depends_on:
    cleanup:
      condition: process_completed  # Run even if tests fail
  availability:
    restart: "no"
  shutdown:
    signal: 15
    timeout_seconds: 1
```

## TUI Mode

Process-compose supports Terminal UI (TUI) mode for interactive monitoring. TUI shows real-time process status, logs, and dependency graphs.

### Enabling TUI

```bash
# Non-interactive mode (default, for CI/scripts)
devbox run test:e2e:android

# Interactive TUI mode (for local debugging)
TEST_TUI=true devbox run test:e2e:android
```

### TUI Controls

When TUI is enabled, use these keyboard shortcuts:

- `h` - Help
- `q` - Quit
- Arrow keys - Navigate processes
- Enter - View process logs
- Tab - Switch panels

### TUI Behavior

- `TEST_TUI=false` (default): Shows summary and exits immediately
- `TEST_TUI=true`: Shows interactive dashboard with "Press Ctrl+C to exit" message

TUI automatically falls back to non-interactive mode when running in CI or non-interactive terminals.

## Environment Variables

### Global Test Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TEST_TUI` | Enable interactive TUI mode | `false` |
| `TEST_TIMEOUT` | Overall test timeout (seconds) | `300` |
| `LOG_LEVEL` | Logging verbosity (info, debug) | `info` |
| `DEBUG` | Enable debug logging globally | `0` |

### Android Test Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ANDROID_DEBUG_SETUP` | Enable Android debug logging | `0` |
| `ANDROID_SERIAL` | Device serial number | `emulator-5554` |
| `ANDROID_APP_APK` | Path to APK file | Auto-detected |
| `ANDROID_APP_ID` | App package name | Required |
| `BOOT_TIMEOUT` | Emulator boot timeout (seconds) | `90` |

### iOS Test Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `IOS_DEBUG` | Enable iOS debug logging | `0` |
| `IOS_DEVICE` | Simulator device name | `max` |
| `IOS_APP_BUNDLE_ID` | App bundle identifier | Required |
| `BOOT_TIMEOUT` | Simulator boot timeout (seconds) | `120` |
| `SIM_HEADLESS` | Run simulator headless | `0` |

### React Native Test Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `BUILD_CONFIG` | Build configuration (Debug/Release) | `Debug` for dev, `Release` for E2E |
| `IOS_BUILD_CONFIG` | iOS-specific build config | `$BUILD_CONFIG` |
| `ANDROID_SKIP_SETUP` | Skip Android SDK evaluation | `0` |
| `IOS_SKIP_SETUP` | Skip iOS environment setup | `0` |

## Debugging Test Failures

### Check Test Logs

All test logs are written to the `reports/` directory. Start by examining the logs for the failed process.

```bash
# List all log directories
ls -la reports/

# View specific test logs
cat reports/android-e2e-logs/build-app.log
cat reports/ios-e2e-logs/deploy-app.log
cat reports/react-native-android-e2e-logs/metro-bundler.log
```

### Run with TUI

TUI mode provides real-time visibility into test execution:

```bash
TEST_TUI=true devbox run test:e2e:android
```

Watch the process status and logs in real-time to identify where the test fails.

### Run with Debug Logging

Enable debug logging to see detailed output:

```bash
# Android debug
ANDROID_DEBUG=1 devbox run test:e2e:android

# iOS debug
IOS_DEBUG=1 devbox run test:e2e:ios

# Global debug
DEBUG=1 devbox run test:e2e:rn
```

### Run Individual Test

Isolate the failing test by running it individually:

```bash
# Run specific test suite
devbox run test:android:lib
devbox run test:ios:device-mgmt

# Run specific E2E test
cd examples/android
devbox run test:e2e
```

### Common Issues

#### Build Failures

**Android:**
```bash
# Check Gradle version
gradle --version

# View detailed build log
cat reports/android-e2e-logs/build-app.log

# Clean build
cd examples/android/android
gradle clean
```

**iOS:**
```bash
# Check Xcode version
xcodebuild -version

# Verify project and scheme
xcodebuild -list -project $IOS_APP_PROJECT

# View detailed build log
cat reports/ios-e2e-logs/build-app.log
```

#### Emulator/Simulator Won't Start

**Android:**
```bash
# Check emulator status
adb devices

# Increase boot timeout
BOOT_TIMEOUT=300 devbox run test:e2e:android

# View emulator log
cat reports/android-e2e-logs/android-emulator.log
```

**iOS:**
```bash
# List simulators
xcrun simctl list devices

# Check running simulators
xcrun simctl list devices | grep Booted

# Restart CoreSimulatorService
killall -9 CoreSimulatorService

# View simulator log
cat reports/ios-e2e-logs/ios-simulator.log
```

#### App Won't Install

**Android:**
```bash
# Verify APK exists
ls -la $ANDROID_APP_APK

# Check emulator is ready
adb -s emulator-5554 shell getprop sys.boot_completed

# Manually install APK
adb -s emulator-5554 install -r $ANDROID_APP_APK
```

**iOS:**
```bash
# Verify app bundle exists
ls -la $IOS_APP_ARTIFACT

# Check simulator is booted
xcrun simctl list devices | grep Booted

# Verify bundle ID
defaults read "$IOS_APP_ARTIFACT/Info.plist" CFBundleIdentifier
```

#### Metro Bundler Issues

```bash
# Check Metro status
metro.sh status android

# View Metro logs
cat reports/react-native-android-e2e-logs/metro-bundler.log

# Manually start Metro
metro.sh start android

# Clean Metro state
metro.sh clean android

# Kill all Metro processes
pkill -f "react-native start"
pkill -f "metro"
```

#### Timeout Errors

Increase timeouts for slow machines:

```bash
# Increase emulator boot timeout
BOOT_TIMEOUT=300 devbox run test:e2e:android

# Increase overall test timeout
TEST_TIMEOUT=600 devbox run test:e2e:ios

# Both timeouts
BOOT_TIMEOUT=300 TEST_TIMEOUT=600 devbox run test:e2e:android
```

## Parallel Testing Patterns

### Testing Multiple Devices

Run tests on multiple devices in parallel by creating separate test suites with unique suite names:

```bash
# Create test suites for different devices
test-suite-pixel.yaml     # Uses "pixel" suite name
test-suite-tablet.yaml    # Uses "tablet" suite name

# Run in parallel
devbox run test:pixel &
devbox run test:tablet &
wait
```

### Testing Multiple Platforms

Run Android and iOS tests in parallel:

```bash
# Using E2E test suite
cd examples/react-native
devbox run test:e2e:all  # Runs android and ios in parallel
```

Or manually:

```bash
devbox run test:e2e:android &
devbox run test:e2e:ios &
wait
```

### Platform Isolation

When testing both platforms, skip the unused platform for faster startup:

```bash
# iOS only (skip Android SDK)
devbox run --pure -e ANDROID_SKIP_SETUP=1 test:e2e:ios

# Android only (skip iOS setup)
devbox run --pure -e IOS_SKIP_SETUP=1 test:e2e:android
```

## CI/CD Testing Best Practices

### Use Pure Mode

Always use pure mode in CI for reproducible builds:

```yaml
# GitHub Actions example
- name: Run E2E Test
  run: devbox run --pure test:e2e:android
```

E2E test commands automatically use pure mode:

```yaml
- name: Run E2E Test
  run: devbox run test:e2e:android  # Already uses --pure
```

### Disable TUI

Ensure TUI is disabled in CI (default behavior):

```yaml
- name: Run Tests
  run: devbox run test:e2e:android
  # TEST_TUI defaults to false
```

### Set Appropriate Timeouts

CI machines are often slower than local machines. Increase timeouts:

```yaml
- name: Run Android E2E Test
  env:
    BOOT_TIMEOUT: 180
    TEST_TIMEOUT: 600
  run: devbox run test:e2e:android
```

### Run Headless

Run simulators and emulators headless in CI:

```yaml
- name: Run iOS E2E Test
  env:
    SIM_HEADLESS: 1
  run: devbox run test:e2e:ios
```

### Platform-Specific Jobs

Split platform tests into separate CI jobs for parallel execution:

```yaml
jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: devbox run --pure -e IOS_SKIP_SETUP=1 test:e2e:android

  ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: devbox run --pure -e ANDROID_SKIP_SETUP=1 test:e2e:ios
```

### Artifact Logs

Upload test logs as artifacts for debugging:

```yaml
- name: Upload Test Logs
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: test-logs
    path: reports/
```

## Local CI Simulation

Test your CI configuration locally using `act`:

```bash
# Install act
devbox add act

# List workflows
act -l

# Run specific job
act -j android-plugin-tests
act -j ios-plugin-tests

# Run full workflow
act -W .github/workflows/pr-checks.yml
```

## Test Development

### Adding New Unit Tests

1. Create test script in `plugins/tests/<platform>/`:

```bash
# plugins/tests/android/test-new-feature.sh
#!/usr/bin/env bash
set -euo pipefail

# Source test framework
. "$(dirname "$0")/../../test-framework.sh"

test_new_feature() {
  # Your test implementation
  assert_equals "expected" "actual"
}

run_tests test_new_feature
```

2. Add to process-compose config:

```yaml
# tests/process-compose-unit-tests.yaml
test-android-new-feature:
  command: "bash plugins/tests/android/test-new-feature.sh"
  depends_on:
    lint-android:
      condition: process_completed_successfully
  availability:
    restart: "no"
```

3. Add to `devbox.json`:

```json
{
  "scripts": {
    "test:android:new-feature": "bash plugins/tests/android/test-new-feature.sh"
  }
}
```

### Adding New E2E Tests

1. Create orchestrated test script in `tests/e2e/`:

```bash
# tests/e2e/e2e-new-platform.sh
#!/usr/bin/env bash
set -euo pipefail

echo "Running new platform E2E test..."
# Your E2E test implementation
```

2. Create process-compose config:

```yaml
# tests/process-compose-new-e2e.yaml
version: "0.5"

log_location: "reports/new-e2e-logs"
log_level: info

processes:
  e2e-test:
    command: "bash tests/e2e/e2e-new-platform.sh"
    availability:
      restart: "no"

  summary:
    command: "bash tests/test-summary.sh 'New E2E Test' 'reports/new-e2e-logs'"
    depends_on:
      e2e-test:
        condition: process_completed
```

3. Add to `devbox.json`:

```json
{
  "scripts": {
    "test:e2e:new": "process-compose -f tests/process-compose-new-e2e.yaml --no-server --tui=\"${TEST_TUI:-false}\""
  }
}
```

### Testing Your Test Changes

Always test your test changes:

```bash
# Test the orchestration with TUI
TEST_TUI=true devbox run test:unit

# Verify logs are created
ls -la reports/test-logs/

# Run in pure mode like CI
devbox run --pure test:unit
```

## Summary

This guide covered:

1. Test categories (unit, integration, E2E) and execution times
2. Test modes (development vs pure) and when to use each
3. Platform-specific testing for Android, iOS, and React Native
4. Metro bundler management and parallel testing patterns
5. Process-compose orchestration with dependencies and health checks
6. TUI mode for interactive debugging
7. Environment variables for configuration
8. Debugging test failures with logs and debug modes
9. Parallel testing patterns for multiple devices and platforms
10. CI/CD best practices for reproducible testing
11. Test development and adding new tests

For more information:

- [Android Guide](android-guide.md) - Complete Android development workflow
- [iOS Guide](ios-guide.md) - Complete iOS development workflow
- [React Native Guide](react-native-guide.md) - React Native development
- [Device Management](device-management.md) - Create custom device configurations
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
