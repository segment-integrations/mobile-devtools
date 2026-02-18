# React Native Test Suites

This directory contains development and test suites for React Native, organized into two categories:

## Quick Start

### Development Mode (Interactive)
For fast iteration with hot reload, Debug builds, and optional TUI:

```bash
# Start development mode for each platform
devbox run start:android     # Android with Metro + hot reload
devbox run start:ios         # iOS with Metro + hot reload
devbox run start:web         # Web with Metro + browser

# Enable TUI for interactive monitoring
DEVBOX_TUI=true devbox run start:ios
```

### E2E Testing (Automated)
For automated testing with Release builds and cleanup:

```bash
# Run E2E tests (automatically uses --pure)
devbox run test:e2e:ios      # iOS Release build
devbox run test:e2e:android  # Android Release build
devbox run test:e2e:web      # Web bundle test
devbox run test:e2e:all      # Both platforms in parallel
```

## File Organization

### Development Compose Files (`dev-*.yaml`)
**Purpose:** Interactive development with hot reload and fast iteration.

**Files:**
- `dev-android.yaml` - Android development with Debug build
- `dev-ios.yaml` - iOS development with Debug build
- `dev-web.yaml` - Web development with browser auto-launch

**Features:**
- **Debug builds** - Fast compilation for quick iteration
- **Hot reload enabled** - See changes instantly
- **Reuses existing emulator/simulator** - No startup overhead
- **No automatic cleanup** - Keeps environment running
- **TUI optional** - Controlled via `DEVBOX_TUI` environment variable

**Usage:**
```bash
# Non-interactive (default)
devbox run start:ios

# With TUI for monitoring
DEVBOX_TUI=true devbox run start:android
```

### E2E Test Suites (`test-suite-*-e2e.yaml`)
**Purpose:** Automated end-to-end testing for CI/CD pipelines.

**Files:**
- `test-suite-android-e2e.yaml` - Android automated tests
- `test-suite-ios-e2e.yaml` - iOS automated tests
- `test-suite-web-e2e.yaml` - Web bundle tests
- `test-suite-all-e2e.yaml` - Multi-platform tests in parallel

**Features:**
- **Release builds** - Production-like behavior
- **No TUI** - Automated, non-interactive
- **Summary reports** - Test results and logs
- **Automatic cleanup** - Stops processes after completion
- **`--pure` flag** - Isolated, reproducible test runs (default)

**Usage:**
```bash
# E2E tests automatically run with --pure flag
devbox run test:e2e:ios       # Clean, isolated test run
devbox run test:e2e:android   # Clean, isolated test run
```

## Test Modes: --pure vs Development

### CI Mode (`--pure`) - Default for E2E Tests
**Purpose:** Deterministic, reproducible test runs for continuous integration.

**Behavior:**
- **Always starts fresh** - Creates a new simulator/emulator from scratch
- **Clean state** - No cached data or previous state
- **Automatic cleanup** - Stops and deletes simulators/emulators after tests complete
- **Isolated** - Each test run is completely independent

**Note:** E2E test commands (`test:e2e:*`) automatically use `--pure` flag.

### Development Mode - Default for start:* Commands
**Purpose:** Fast iteration during local development.

**Behavior:**
- **Reuses existing** - Uses already-running simulator/emulator if available
- **Starts if needed** - Opens simulator/emulator only if not already running
- **No cleanup** - Leaves simulator/emulator running after completion
- **Fast iteration** - No startup/shutdown overhead between runs

## Metro Bundler Management

The React Native plugin provides robust Metro bundler management with isolated state:

```bash
# Automatic Metro management (via process-compose)
devbox run start:ios          # Starts Metro automatically

# Manual Metro control (advanced)
metro.sh start android        # Start Metro for android suite
metro.sh stop android         # Stop Metro for android suite
metro.sh status android       # Check Metro status
metro.sh health android ios   # Health check (exit code only)
metro.sh clean android        # Clean up Metro state files
```

**Key features:**
- **Unique suite names** - Isolate Metro instances (android, ios, web, all)
- **Dynamic port allocation** - 8091-8199 range
- **Parallel test support** - Multiple Metro instances can run simultaneously
- **Automatic cleanup** - Process-compose handles lifecycle

## Parallel Testing Multiple Versions

Each test suite uses a unique suite name to isolate Metro bundler ports and state. To test multiple Android or iOS versions in parallel, create separate test suite files with unique names:

```yaml
# test-suite-android-api21.yaml
environment:
  - "ANDROID_DEFAULT_DEVICE=min"

processes:
  allocate-metro-port:
    command: |
      . ${REACT_NATIVE_VIRTENV}/scripts/lib/lib.sh
      metro_port=$(rn_allocate_metro_port "android-api21")  # Unique suite name
      rn_save_metro_env "android-api21" "$metro_port"

  metro-bundler:
    command: "metro.sh start android-api21"  # Matches suite name

  cleanup:
    command: "metro.sh stop android-api21"  # Matches suite name
```

```yaml
# test-suite-android-api35.yaml
environment:
  - "ANDROID_DEFAULT_DEVICE=max"

processes:
  allocate-metro-port:
    command: |
      . ${REACT_NATIVE_VIRTENV}/scripts/lib/lib.sh
      metro_port=$(rn_allocate_metro_port "android-api35")  # Different suite name
      rn_save_metro_env "android-api35" "$metro_port"

  metro-bundler:
    command: "metro.sh start android-api35"

  cleanup:
    command: "metro.sh stop android-api35"
```

**Key requirement**: Use unique suite names for:
- `rn_allocate_metro_port` calls
- `metro.sh start/stop` commands
- Environment file names

This ensures each test gets its own Metro instance on a unique port with isolated state.

## Platform-Specific Optimization

The wrapper scripts optimize startup time by skipping the unused platform:

```bash
# iOS tests only (fast - skips Android SDK)
./tests/run-ios-tests.sh

# Android tests only (fast - skips iOS setup)
./tests/run-android-tests.sh
```

**Environment variables:**
- `ANDROID_SKIP_SETUP=1` - Skip Android SDK Nix flake evaluation
- `IOS_SKIP_SETUP=1` - Skip iOS environment setup

**Important:** When using `--pure` mode, environment variables must be passed with the `-e` flag:
```bash
# Correct way to skip Android SDK in pure mode
devbox run --pure -e ANDROID_SKIP_SETUP=1 test:e2e:ios

# Incorrect - env var gets reset to default
ANDROID_SKIP_SETUP=1 devbox run --pure test:e2e:ios
```

The wrapper scripts (`run-ios-tests.sh` and `run-android-tests.sh`) use the correct `-e` flag syntax automatically. This is particularly useful in CI/CD pipelines where you split platform tests into separate jobs.

## Build Configuration

**Development mode (start:*):** Uses Debug builds for fast compilation.

**E2E tests (test:e2e:*):** Uses Release builds for production-like behavior.

Override with environment variables:
```bash
# Force Debug build in E2E test
IOS_BUILD_CONFIG=Debug devbox run test:e2e:ios

# Force Release build in dev mode (slower compilation)
BUILD_CONFIG=Release devbox run start:android
```

## Test Logs

Logs are written to `reports/` directory:
- Dev mode: `reports/react-native-{platform}-dev-logs/`
- E2E tests: `reports/react-native-{platform}-e2e-logs/`

## TUI Mode

Process-compose supports Terminal UI (TUI) mode for interactive monitoring of processes.

**Control TUI:**
```bash
# Disable TUI (default for automated runs)
devbox run start:ios

# Enable TUI for interactive monitoring
DEVBOX_TUI=true devbox run start:ios
```

**Note:** TUI requires an interactive terminal. It automatically falls back to non-TUI mode when running in CI or non-interactive contexts.

## Interactive Development

For interactive development with full environment setup (both platforms available):

```bash
devbox shell
```

This gives you a fully configured environment with both Android SDK and iOS tooling ready to use.
