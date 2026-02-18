# Project Architecture

This document provides a comprehensive overview of the devbox-plugins repository architecture for contributors who need to understand how everything fits together.

## Repository Overview

This repository provides Devbox plugins and example projects for Android, iOS, and React Native mobile development. The core design principle is reproducible, project-local development environments that never touch global state (like `~/.android` or system-wide Xcode settings).

### Design Goals

1. **Project-local state** - All tooling, SDKs, emulators, and build artifacts live within the project directory under `.devbox/virtenv/`.
2. **Reproducibility** - Same code + same device definitions = identical environment on any machine.
3. **No global pollution** - Never modify `~/.android`, `~/Library/Android`, or other global directories.
4. **Parallel execution** - Multiple projects can run simultaneously without conflicts via `devbox run --pure`.
5. **CI optimization** - Lock files limit SDK evaluation to only required API levels.

### Key Principles

**Fail loudly, avoid fallbacks.** When something is wrong, scripts exit with clear error messages. Silent fallbacks hide problems.

**Validation warns but doesn't block.** Validation commands inform users of issues and provide fix commands, but never prevent continuing.

**Process isolation.** Only terminate processes we explicitly started. Track PIDs in project-local files and verify before killing.

**Project-local logging.** All logs go to `reports/logs/`, never `/tmp/`. This ensures logs survive system cleanup and are available in CI.

## Plugin System

The repository contains three plugins in `plugins/`:

```
plugins/
├── android/          # Android SDK + AVD management via Nix flake
├── ios/              # iOS simulator management for macOS
└── react-native/     # Composition layer over android + ios
```

### Plugin Composition Model

Plugins use Devbox's `include` mechanism to compose functionality:

```json
// plugins/react-native/plugin.json
{
  "name": "react-native",
  "include": [
    "path:../android/plugin.json",
    "path:../ios/plugin.json"
  ],
  "packages": {
    "nodejs": "20",
    "watchman": "latest"
  }
}
```

When a project includes the React Native plugin, it automatically inherits:
- Android SDK and emulator management
- iOS simulator management
- Node.js and Watchman for React Native
- All environment variables from both platforms
- Device management CLIs for both platforms

### Plugin.json Structure

Each plugin is defined by a `plugin.json` manifest with these sections:

**Environment Variables** - Define project-local paths and configuration:
```json
{
  "env": {
    "ANDROID_AVD_HOME": "{{ .Virtenv }}/android/avd",
    "ANDROID_DEVICES_DIR": "{{ .DevboxDir }}/devices",
    "ANDROID_DEFAULT_DEVICE": "max"
  }
}
```

**Packages** - Nix packages to install:
```json
{
  "packages": {
    "bash": "latest",
    "jq": "latest",
    "process-compose": "latest"
  }
}
```

**Create Files** - Copy plugin scripts and config to project:
```json
{
  "create_files": {
    "{{ .Virtenv }}/scripts/user/android.sh": "virtenv/scripts/user/android.sh",
    "{{ .DevboxDir }}/devices/min.json": "config/devices/min.json"
  }
}
```

**Init Hooks** - Run on `devbox shell` startup:
```json
{
  "shell": {
    "init_hook": [
      "bash {{ .Virtenv }}/scripts/init/init-hook.sh",
      ". {{ .Virtenv }}/scripts/init/setup.sh"
    ]
  }
}
```

**Scripts** - User-facing commands:
```json
{
  "shell": {
    "scripts": {
      "start:emu": ["android.sh emulator start \"${1:-}\""],
      "doctor": ["echo 'Android Environment Check'", "..."]
    }
  }
}
```

## Directory Structure

### Root Level

```
devbox-plugins/
├── plugins/              # Plugin source code (source of truth)
├── examples/             # Example projects using plugins
├── tests/                # E2E test scripts
├── scripts/              # Repository management scripts
├── .github/workflows/    # CI/CD workflows
└── devbox.json           # Root devbox config
```

### Plugin Directory Layout

```
plugins/{platform}/
├── config/
│   ├── devices/          # Default device definitions (min.json, max.json)
│   └── *.yaml            # Process-compose test suites
├── virtenv/
│   └── scripts/          # Runtime scripts (copied to .devbox/virtenv/)
│       ├── lib/          # Layer 1: Pure utilities
│       ├── platform/     # Layer 2: SDK/platform setup
│       ├── domain/       # Layer 3: Domain operations
│       ├── user/         # Layer 4: User-facing CLI
│       └── init/         # Layer 5: Environment initialization
├── plugin.json           # Plugin manifest
└── REFERENCE.md          # Complete API reference
```

The `virtenv/` directory contains scripts that are copied to user projects at `.devbox/virtenv/` when the plugin is included.

### Example Project Layout

```
examples/{platform}/
├── .devbox/
│   └── virtenv/          # Auto-generated by devbox (NEVER edit directly)
│       ├── scripts/      # Plugin scripts (copied from plugins/)
│       └── {platform}/   # Platform-specific state (AVDs, cache files)
├── devbox.d/
│   └── {platform}/
│       └── devices/      # User device definitions
│           ├── min.json
│           ├── max.json
│           └── devices.lock
├── devbox.json           # Includes plugin
└── README.md
```

**Critical Rule**: `.devbox/virtenv/` is temporary and auto-regenerated. Never edit files there. Always edit plugin sources in `plugins/` and sync changes.

### Test Directory Layout

```
plugins/tests/
├── {platform}/
│   ├── test-lib.sh              # Unit tests for lib.sh
│   ├── test-devices.sh          # Unit tests for device management
│   ├── test-device-mgmt.sh      # Integration tests
│   └── test-validation.sh       # Validation tests
└── test-framework.sh            # Shared test utilities
```

## Script Layering Architecture

Plugin scripts are organized into strict layers to prevent circular dependencies and maintain clear separation of concerns.

### The Five Layers

```
Layer 1: lib/        Pure utilities (no platform logic)
  ↓
Layer 2: platform/   SDK resolution, PATH setup, device config
  ↓
Layer 3: domain/     Domain operations (AVD, emulator, deployment)
  ↓
Layer 4: user/       User-facing CLI (android.sh, devices.sh)
  ↓
Layer 5: init/       Environment initialization (setup.sh)
```

### Critical Layer Rule

Scripts can only source/depend on scripts from **earlier layers**, never from the same layer or later layers. This prevents circular dependencies and makes the codebase easier to understand.

### Layer 1: Pure Utilities

**File**: `lib/lib.sh`

**Purpose**: Pure utility functions with no platform-specific logic.

**Functions**:
- String manipulation (`android_normalize_name`, `android_sanitize_avd_name`)
- Path resolution (`android_resolve_project_path`, `android_resolve_config_dir`)
- JSON parsing and validation
- Checksums (`android_compute_devices_checksum`)
- Logging (`android_log_info`, `android_log_error`, `android_log_debug`)
- Requirement checking (`android_require_tool`, `android_require_jq`)

**Dependencies**: None

### Layer 2: Platform Setup

**Files**: `platform/core.sh`, `platform/device_config.sh`

**Purpose**: SDK resolution, PATH setup, and device configuration utilities.

**core.sh responsibilities**:
- SDK resolution (Nix flake evaluation or local SDK detection)
- PATH setup (`android_setup_path`)
- Environment variable setup (`android_setup_sdk_environment`)
- Debug utilities

**device_config.sh responsibilities**:
- Device file discovery and selection
- Device definition loading and parsing
- Device filtering by `{PLATFORM}_DEVICES` env var
- Lock file generation and validation

**Dependencies**: Layer 1 only

### Layer 3: Domain Operations

**Directory**: `domain/`

**Purpose**: Internal domain logic for platform operations. These scripts are atomic, independent operations that should not call each other.

**Android domain scripts**:
- `domain/avd.sh` - AVD creation, deletion, and management
- `domain/avd-reset.sh` - AVD reset operations
- `domain/emulator.sh` - Emulator lifecycle (start/stop)
- `domain/deploy.sh` - App deployment to emulators
- `domain/validate.sh` - Environment validation

**iOS domain scripts**:
- `domain/device_manager.sh` - Simulator creation and management
- `domain/simulator.sh` - Simulator lifecycle (start/stop)
- `domain/deploy.sh` - App deployment to simulators
- `domain/validate.sh` - Environment validation

**Critical Rule**: Domain layer scripts CANNOT source or call functions from other domain layer scripts. If two domain scripts need the same functionality, that functionality must be moved to layer 2 or layer 1.

**Why?** Domain operations should be atomic and independent. Orchestration of multiple domain operations belongs in layer 4 (user CLI).

**Example - WRONG**:
```bash
# domain/emulator.sh calling domain/avd.sh - VIOLATES LAYER RULE
android_start_emulator() {
  android_setup_avds  # ❌ Calling another layer 3 function
  # ... start emulator
}
```

**Example - CORRECT**:
```bash
# user/android.sh (layer 4) orchestrates multiple layer 3 operations
case "$1" in
  emulator)
    . domain/avd.sh
    . domain/emulator.sh

    # Step 1: Setup AVDs
    android_setup_avds

    # Step 2: Start emulator
    android_start_emulator
    ;;
esac
```

**Dependencies**: Layers 1 & 2 only

### Layer 4: User CLI

**Files**: `user/android.sh`, `user/ios.sh`, `user/devices.sh`, `user/config.sh`

**Purpose**: User-facing command-line interfaces that orchestrate layer 3 operations.

**Main CLI commands**:
- `android.sh` / `ios.sh` - Primary entry points
  - `devices` - Delegate to devices.sh
  - `config` - Configuration management
  - `emulator`/`simulator` - Device lifecycle operations
  - `deploy` - App deployment

- `devices.sh` - Device management
  - `list` - List device definitions
  - `create` - Create device definition
  - `update` - Update device definition
  - `delete` - Delete device definition
  - `eval` - Generate devices.lock
  - `sync` - Sync AVDs/simulators with definitions

- `config.sh` - Configuration display
  - `show` - Display current configuration

**Dependencies**: Can source from layers 1, 2, and 3

### Layer 5: Setup & Init

**File**: `init/setup.sh`

**Purpose**: Dual-purpose initialization script run by devbox init hooks.

**Two execution modes**:

1. **Executed mode** (`bash setup.sh`): Configuration file generation
   - Generates platform config JSON from environment variables
   - Generates `devices.lock` from device definitions
   - Makes scripts executable
   - Runs once on `devbox shell` startup

2. **Sourced mode** (`. setup.sh`): Environment initialization
   - Sources `platform/core.sh` for SDK resolution and PATH setup
   - Runs validation (non-blocking)
   - Optionally displays SDK summary
   - Runs on every shell startup

The script detects its execution mode and behaves accordingly.

**Dependencies**: Sources layer 2 (`platform/core.sh`), which sources layer 1 (`lib/lib.sh`)

### Dependency Graph

```
lib/lib.sh (layer 1)
  ↓
platform/core.sh (layer 2) ─────┐
platform/device_config.sh (layer 2)
  ↓                              │
domain/avd.sh (layer 3)          │
domain/emulator.sh (layer 3)     │
domain/deploy.sh (layer 3)       │
domain/validate.sh (layer 3)     │
  ↓                              │
user/android.sh (layer 4)        │
user/devices.sh (layer 4)        │
  ↓                              │
init/setup.sh (layer 5) ─────────┘
  (sources core.sh when sourced)
```

## Android Plugin Architecture

### SDK Management via Nix Flake

The Android SDK is composed using a Nix flake at `devbox.d/android/flake.nix` in each project.

**Flake inputs**:
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

**Flake outputs**:
- `android-sdk` - Standard SDK with platforms from device definitions
- `android-sdk-full` - Extended SDK with NDK, CMake, extras
- `android-sdk-preview` - Preview/beta API levels

**Device-driven SDK composition**: The flake reads `devices.lock` to determine which API levels to include, avoiding expensive evaluation of all SDK versions.

**Evaluation flow**:
```
1. User runs `devbox shell`
2. init-hook.sh generates android.json from env vars
3. devices.sh eval generates devices.lock with checksums
4. Nix evaluates flake.nix using android.json + devices.lock
5. Nix builds/fetches SDK packages for required API levels
6. setup.sh sources core.sh which exports ANDROID_SDK_ROOT
```

### AVD Management

AVDs (Android Virtual Devices) are stored project-locally at `$ANDROID_AVD_HOME` (`.devbox/virtenv/android/avd`).

**AVD lifecycle**:
1. **Device definition** - JSON file defines emulator config
2. **AVD creation** - `avdmanager create avd` creates AVD from definition
3. **AVD sync** - `devices.sh sync` ensures AVDs match device definitions
4. **Emulator start** - `emulator @avd_name` launches emulator
5. **Emulator stop** - Kill emulator process by PID

**Device definition format**:
```json
{
  "name": "pixel_api30",
  "api": 30,
  "device": "pixel",
  "tag": "google_apis",
  "preferred_abi": "x86_64"
}
```

### Script Organization

```
.devbox/virtenv/scripts/
├── lib/
│   └── lib.sh                    # Utilities, logging, checksums
├── platform/
│   ├── core.sh                   # SDK resolution, PATH setup
│   └── device_config.sh          # Device file handling
├── domain/
│   ├── avd.sh                    # AVD create/delete/list
│   ├── avd-reset.sh              # AVD reset operations
│   ├── emulator.sh               # Emulator start/stop
│   ├── deploy.sh                 # APK install and launch
│   └── validate.sh               # Environment validation
├── user/
│   ├── android.sh                # Main CLI entry point
│   ├── devices.sh                # Device management CLI
│   └── config.sh                 # Config display
└── init/
    ├── init-hook.sh              # Pre-shell hook (exec mode)
    └── setup.sh                  # Environment setup (source mode)
```

## iOS Plugin Architecture

### Xcode Discovery

iOS plugin discovers Xcode using multiple strategies:

1. `IOS_DEVELOPER_DIR` environment variable (highest priority)
2. `xcode-select -p` (system default)
3. `/Applications/Xcode*.app` (latest by version number)

The discovered path is cached in `.xcode_dev_dir.cache` with 1-hour TTL to avoid repeated expensive lookups.

**Discovery flow**:
```
1. Check IOS_DEVELOPER_DIR env var
2. If not set, try xcode-select -p
3. If fails, search /Applications/Xcode*.app
4. Sort by version, select latest
5. Cache path in .xcode_dev_dir.cache
6. Export DEVELOPER_DIR for Xcode tools
```

### Simulator Management

iOS simulators are managed via `xcrun simctl` commands. Unlike Android AVDs, simulators are not project-local but shared system-wide.

**Device definition format**:
```json
{
  "name": "iphone15",
  "runtime": "17.5"
}
```

**Simulator lifecycle**:
1. **Device definition** - JSON file specifies device and runtime
2. **Simulator creation** - `xcrun simctl create` creates simulator
3. **Device sync** - `devices.sh sync` ensures simulators match definitions
4. **Simulator boot** - `xcrun simctl boot` starts simulator
5. **Simulator shutdown** - `xcrun simctl shutdown` stops simulator

**Runtime download**: If `IOS_DOWNLOAD_RUNTIME=1`, missing runtimes are automatically downloaded via `xcodebuild -downloadPlatform`.

### Script Organization

```
.devbox/virtenv/scripts/
├── lib/
│   └── lib.sh                    # Utilities, logging, checksums
├── platform/
│   ├── core.sh                   # Xcode discovery, PATH setup
│   └── device_config.sh          # Device file handling
├── domain/
│   ├── device_manager.sh         # Simulator create/delete/list
│   ├── simulator.sh              # Simulator boot/shutdown
│   ├── deploy.sh                 # App install and launch
│   └── validate.sh               # Environment validation
├── user/
│   ├── ios.sh                    # Main CLI entry point
│   ├── devices.sh                # Device management CLI
│   └── config.sh                 # Config display
└── init/
    ├── init-hook.sh              # Pre-shell hook (exec mode)
    └── setup.sh                  # Environment setup (source mode)
```

## React Native Plugin Architecture

The React Native plugin is a composition layer that includes both Android and iOS plugins plus React Native-specific tooling.

### Plugin Composition

```json
{
  "name": "react-native",
  "include": [
    "path:../android/plugin.json",
    "path:../ios/plugin.json"
  ],
  "packages": {
    "nodejs": "20",
    "watchman": "latest"
  }
}
```

This gives React Native projects:
- Full Android SDK and AVD management
- Full iOS Xcode and simulator management
- Node.js for Metro bundler
- Watchman for file watching

### Metro Bundler Management

Metro bundler requires careful port management to enable parallel test execution.

**Port allocation flow**:
```
1. rn_allocate_metro_port "${suite_name}"
   - Finds free port in range RN_METRO_PORT_START to RN_METRO_PORT_END
   - Writes port to ${REACT_NATIVE_VIRTENV}/metro/port-${suite_name}.txt
2. rn_save_metro_env "${suite_name}" "$port"
   - Writes METRO_PORT=$port to env-${suite_name}.sh
3. Test processes source env-${suite_name}.sh
   - React Native uses METRO_PORT for bundler connection
```

**Metro process tracking**:
```bash
# Start Metro and track PID
metro.sh start android &
metro_pid=$!
rn_track_metro_pid "android" "$metro_pid"

# Stop Metro (only if we started it)
metro.sh stop android
```

**Why this matters**: Multiple test suites can run in parallel with `--pure` because each suite gets its own Metro port.

### Parallel Testing

React Native example includes process-compose test suites for parallel execution:

```
examples/react-native/tests/
├── test-suite-android-e2e.yaml    # Android E2E tests
├── test-suite-ios-e2e.yaml        # iOS E2E tests
├── test-suite-web-e2e.yaml        # Web build tests
└── test-suite-all-e2e.yaml        # All platforms in parallel
```

Each suite allocates its own Metro port and runs independently.

## Device Management System

### Device Definitions

Device definitions are JSON files in `devbox.d/{platform}/devices/`:

**Android device** (`pixel_api30.json`):
```json
{
  "name": "pixel_api30",
  "api": 30,
  "device": "pixel",
  "tag": "google_apis",
  "preferred_abi": "x86_64"
}
```

**iOS device** (`iphone15.json`):
```json
{
  "name": "iphone15",
  "runtime": "17.5"
}
```

**Default devices**:
- `min.json` - Minimum supported version (e.g., API 21, iOS 15.4)
- `max.json` - Maximum/latest version (e.g., API 36, iOS 18.2)

### Lock Files

`devices.lock` is a plain text file mapping device names to checksums:

```
min:a3f5b8c9d2e1f4a6
max:d9e7f2b4c1a8d5e3
pixel_api30:f1a2b3c4d5e6f7a8
```

**Purpose**: Optimize CI by limiting which SDK versions Nix evaluates. Instead of evaluating all API levels 21-36, only evaluate the levels defined in device files.

**Generation**: `{platform}.sh devices eval` computes checksums and writes lock file.

**Validation**: Scripts check if device file checksums match lock file. Mismatches trigger warning with fix command but don't block execution.

### Device Sync

`{platform}.sh devices sync` ensures AVDs/simulators match device definitions:

1. Read all device definition files
2. For each device, check if AVD/simulator exists
3. If missing, create it
4. If configuration changed (checksum mismatch), recreate it

This enables declarative device management - define devices in JSON, sync applies the state.

## Environment and Caching

### .devbox/virtenv/ Directory

The `.devbox/virtenv/` directory is a temporary runtime directory that is automatically regenerated when you run `devbox shell` or `devbox run`.

**What's in virtenv**:
- `scripts/` - Plugin scripts (copied from `plugins/`)
- `{platform}/` - Platform-specific state (AVDs, emulators, cache files)
- `metro/` - Metro bundler state (React Native)

**Critical**: Never edit files in `.devbox/virtenv/` directly. Always edit plugin sources in `plugins/` and sync changes.

**Regeneration**: Devbox regenerates virtenv when:
- Running `devbox shell`
- Running `devbox run`
- After modifying `devbox.json`
- After running `devbox sync`

### Environment Variable Scoping

All plugins follow consistent naming patterns:

**Path variables**:
- `{PLATFORM}_CONFIG_DIR` - Configuration directory (`devbox.d/`)
- `{PLATFORM}_DEVICES_DIR` - Device definitions
- `{PLATFORM}_SCRIPTS_DIR` - Runtime scripts
- `{PLATFORM}_RUNTIME_DIR` - Runtime state (`virtenv/`)

**Configuration variables**:
- `{PLATFORM}_DEFAULT_DEVICE` - Default device name
- `{PLATFORM}_DEVICES` - Comma-separated list of devices to evaluate (empty = all)

**Platform-specific**:
- Android: `ANDROID_SDK_ROOT`, `ANDROID_AVD_HOME`, `ANDROID_USER_HOME`
- iOS: `IOS_DEVELOPER_DIR`, `DEVELOPER_DIR`
- React Native: `METRO_CACHE_DIR`, `RN_METRO_PORT_START`, `RN_METRO_PORT_END`

### Caching Strategy

**Nix caching**: Nix handles flake evaluation caching internally. After first evaluation, subsequent `devbox shell` calls are fast.

**iOS caching**:
- `.xcode_dev_dir.cache` - Cached Xcode path (1-hour TTL)
- `.shellenv.cache` - Cached xcrun environment (1-hour TTL)

These avoid expensive operations like searching `/Applications` and running `xcrun --show-sdk-path`.

**Android caching**: No custom caching needed. Nix manages SDK caching automatically.

## Testing Architecture

The repository has three tiers of tests optimized for speed and coverage.

### Test Categories

**Fast tests** (~5-10 seconds):
- Linting and formatting checks
- JSON schema validation
- Shell script syntax checks
- Repository structure validation

**Plugin tests** (~2-5 minutes per platform):
- Unit tests for individual scripts
- Device management integration tests
- Lock file generation and validation
- Environment setup tests

**E2E tests** (~10-15 minutes per platform):
- Full build and deployment workflow
- Emulator/simulator lifecycle
- App installation and launch verification
- Multi-platform parallel execution

### Test Organization

```
plugins/tests/
├── android/
│   ├── test-lib.sh              # Unit: lib.sh utilities
│   ├── test-devices.sh          # Unit: device management
│   ├── test-device-mgmt.sh      # Integration: full device workflow
│   └── test-validation.sh       # Unit: validation logic
├── ios/
│   └── (similar structure)
└── test-framework.sh            # Shared test utilities

examples/{platform}/tests/
├── test-suite-android-e2e.yaml  # E2E: Android workflow
├── test-suite-ios-e2e.yaml      # E2E: iOS workflow
└── test-summary.sh              # Test result display
```

### Process-Compose Orchestration

E2E tests use process-compose for complex multi-process workflows:

**Test phases**:
```
Phase 0: Allocate Metro port (React Native only)
Phase 1: Build Node dependencies
Phase 2: Build platform app (Android/iOS)
Phase 3: Sync devices (AVDs/simulators)
Phase 4: Start emulator/simulator
Phase 5: Start Metro bundler (React Native only)
Phase 6: Deploy app
Phase 7: Verify app running
Cleanup: Stop processes, clean state
Summary: Display results
```

**Process dependencies**:
```yaml
processes:
  build-android:
    command: "gradle assembleDebug"
    depends_on:
      build-node:
        condition: process_completed_successfully

  android-emulator:
    command: "android.sh emulator start"
    depends_on:
      sync-avds:
        condition: process_completed_successfully
    readiness_probe:
      exec:
        command: "adb shell getprop sys.boot_completed"
      timeout_seconds: 180

  deploy-android:
    command: "android.sh deploy"
    depends_on:
      android-emulator:
        condition: process_healthy  # Wait for readiness
```

**Health checks**: Process-compose monitors process health via readiness probes. Dependent processes wait for `process_healthy` status before starting.

**Cleanup strategy**: Cleanup processes depend on `process_completed` (not `process_completed_successfully`) to ensure cleanup always runs, even on failure.

### CI/CD Integration

GitHub Actions workflows run tests in matrix mode:

**pr-checks.yml** (fast feedback):
- Runs on every PR
- Fast tests + plugin tests
- Default devices only
- ~15-30 minutes total

**e2e-full.yml** (comprehensive coverage):
- Manual trigger or weekly schedule
- Full E2E tests with min/max devices
- Matrix execution (parallel)
- ~45-60 minutes per platform

See `.github/workflows/README.md` for CI/CD architecture details.

## Development Workflow

### Working with Plugins

1. Edit plugin sources in `plugins/{platform}/virtenv/scripts/`
2. Sync changes to example projects:
   - Full sync: `devbox run sync` (reinstalls, slow)
   - Quick sync: `scripts/dev/sync-examples.sh` (copies scripts only, fast)
3. Test changes in example project: `cd examples/{platform} && devbox shell`
4. Virtenv regenerates automatically on `devbox shell`

### Adding New Scripts

When adding a new script, determine its layer:

1. **What does this script depend on?**
   - Only utilities → Layer 1 (lib/)
   - Needs SDK/platform setup → Layer 2 (platform/)
   - Performs domain operations → Layer 3 (domain/)
   - User-facing CLI → Layer 4 (user/)
   - Environment initialization → Layer 5 (init/)

2. **Can I avoid same-layer dependencies?**
   - If a layer 3 script needs another layer 3 script:
     - Move shared logic to layer 2
     - Have layer 4 source both scripts
     - Split into smaller, focused scripts

3. **Is this script internal or user-facing?**
   - Internal domain operations → `domain/` directory
   - User-facing CLI → `user/` directory

### Testing Layer Violations

Check for layer violations:

```bash
# Layer 3 scripts should not source other layer 3 scripts
grep -r "ANDROID_SCRIPTS_DIR}/domain" plugins/android/virtenv/scripts/domain/

# Should return no matches (except in comments)
```

## References

For additional architectural details, see:

- `../../CONVENTIONS.md` - Plugin development patterns
- `../reference/android.md` - Android plugin API reference
- `../reference/ios.md` - iOS plugin API reference
- `../reference/react-native.md` - React Native plugin API reference
- `../../.github/workflows/README.md` - CI/CD architecture
- `../../CLAUDE.md` - Repository overview and development guidelines
