---
name: devbox-ios
description: iOS Devbox plugin for reproducible iOS development with Xcode, simulators, and device management. macOS only, no global state pollution.
argument-hint: [command or workflow]
disable-model-invocation: false
allowed-tools: Bash(devbox *) Bash(ios.sh *) Read Edit Write
---

# Devbox iOS Plugin

## Overview

iOS Devbox plugin provides reproducible iOS development environments on macOS. Uses system Xcode with project-local configuration. No global state pollution.

Key features:
- Xcode auto-detection and environment setup
- Device definitions as JSON files
- Simulator management with state isolation
- App building, deployment, and lifecycle control

CRITICAL: macOS only. Requires Xcode installed. On non-Darwin platforms, plugin exits silently.

## Setup

### Include Plugin

In `devbox.json`:
```json
{
  "include": ["github:segment-integrations/mobile-devtools?dir=plugins/ios&ref=main"],
  "packages": {
    "process-compose": "latest"
  }
}
```

### Initialize

```bash
devbox shell                # Sets up environment, detects Xcode
```

First run auto-detects Xcode, generates lock file. Subsequent runs are fast (cached).

## Device Management

### Device Definitions

Devices defined in JSON files at `devbox.d/ios/devices/*.json`.

Schema:
```json
{
  "name": "iPhone 15 Pro",
  "runtime": "17.5"
}
```

Fields:
- `name` (required): Simulator display name
- `runtime` (required): iOS version (e.g., "17.5", "18.0", "15.4")

### Device Commands

List devices:
```bash
devbox run --pure ios.sh devices list
```

Show device details:
```bash
devbox run --pure ios.sh devices show <name>
```

Create device:
```bash
devbox run --pure ios.sh devices create <name> --runtime <version>
```

Example:
```bash
devbox run --pure ios.sh devices create iphone15 --runtime 17.5
```

Update device:
```bash
devbox run --pure ios.sh devices update <name> [--name <new>] [--runtime <version>]
```

Delete device:
```bash
devbox run --pure ios.sh devices delete <name>
```

Regenerate lock file:
```bash
devbox run --pure ios.sh devices eval
```

After creating/updating/deleting devices, regenerate `devices.lock`. Commit lock file to version control.

WARNING: Always run `devices eval` after modifying device definitions. Lock file tracks which simulators to create.

Sync simulators:
```bash
devbox run --pure ios.sh devices sync
```

Creates/updates simulators to match device definitions. Reports matched, recreated, created, skipped.

## Simulator Operations

### Start Simulator

```bash
devbox run --pure ios.sh simulator start [device]
devbox run --pure ios.sh simulator start --pure [device]
devbox run start:sim [device]                           # Alias
```

Behavior:
- Without `--pure`: Reuses running simulator if exists (fast, preserves data)
- With `--pure`: Creates isolated test simulator with clean state
- Auto-detects pure mode when `DEVBOX_PURE_SHELL=1` (set by `devbox run --pure`)

Override pure mode:
```bash
devbox run --pure -e REUSE_SIM=1 ios.sh simulator start [device]
```

Device selection:
- Argument: `devbox run start:sim min`
- Default: Uses `IOS_DEFAULT_DEVICE` from devbox.json
- Override: `IOS_DEVICE_NAME=max devbox run start:sim`

Pure mode test simulator naming:
- Includes suite label for isolation
- Example: `"iPhone 17 (iOS 26.2) Test-ios-e2e"`

Simulator UDID saved to `$IOS_RUNTIME_DIR/${SUITE_NAME:-default}/simulator-udid.txt`.

### Stop Simulator

```bash
devbox run --pure ios.sh simulator stop
devbox run stop:sim                                     # Alias
```

Pure mode: Shuts down and deletes test simulator, cleans state files.
Normal mode: Shuts down simulator only.

### Check Simulator Ready

```bash
devbox run --pure ios.sh simulator ready
```

Silent probe. Exit 0 if booted, exit 1 if not. Designed for process-compose readiness probes.

### Reset Simulators

```bash
devbox run --pure ios.sh simulator reset
```

Stops all running simulators, deletes simulators matching device definitions.

## App Building & Deployment

### Build App

Define build script in `devbox.json` using `ios.sh xcodebuild`:

```json
{
  "shell": {
    "scripts": {
      "build": [
        "ios.sh xcodebuild -project MyApp.xcodeproj -scheme MyApp -configuration Debug -destination 'generic/platform=iOS Simulator' build"
      ],
      "build:release": [
        "ios.sh xcodebuild -project MyApp.xcodeproj -scheme MyApp -configuration Release build"
      ]
    }
  }
}
```

`ios.sh xcodebuild` wrapper removes Nix-incompatible environment variables in subshell. All arguments forwarded to xcodebuild.

WARNING: Use `ios.sh xcodebuild` not bare `xcodebuild` in scripts. Wrapper strips Nix flags that break Xcode builds.

Run:
```bash
devbox run build
devbox run build:release
```

### Deploy App

```bash
ios.sh deploy [app_path]
```

Installs and launches .app bundle on running simulator. No build, no simulator start.

.app resolution (when no path provided):
1. `IOS_APP_ARTIFACT` env var (glob relative to project root)
2. `xcodebuild -showBuildSettings` (queries BUILT_PRODUCTS_DIR + FULL_PRODUCT_NAME)
3. Recursive search from project root for `*.app` (excludes Pods/, .build/, node_modules/, .devbox/, DerivedData/ModuleCache/)
4. Recursive search from `$PWD` if different

Bundle ID extracted from `Info.plist` via PlistBuddy or xcodebuild.

State saved:
- Bundle ID → `$IOS_RUNTIME_DIR/${SUITE_NAME:-default}/bundle-id.txt`

### Run App (Build + Deploy)

```bash
ios.sh run [app_path] [device]
devbox run start:app [app_path]                         # Alias
```

Full workflow:
1. Starts simulator if not running
2. Builds project (calls `build:ios` or `build` script)
3. Resolves .app bundle
4. Installs and launches app

Example:
```bash
ios.sh run                                # Build, detect .app, use default device
ios.sh run MyApp.app min                  # Use specific .app and device
devbox run start:app                      # Via alias
```

Define in `devbox.json`:
```json
{
  "shell": {
    "scripts": {
      "start:app": ["ios.sh run ${1:-}"]
    }
  }
}
```

### App Lifecycle

Check app status:
```bash
ios.sh app status
```

Exit 0 if running, exit 1 if not. Reads bundle ID from state file.

Stop app:
```bash
ios.sh app stop
```

Terminates app via `xcrun simctl terminate`.

## Configuration

### View Configuration

```bash
devbox run --pure ios.sh config show
```

Shows all iOS plugin environment variables.

### View SDK Info

```bash
devbox run --pure ios.sh info
```

Shows:
- Xcode developer directory
- iOS SDK version
- Available runtimes
- Device configuration

### Key Environment Variables

Set in `devbox.json` env section:

**Device selection:**
- `IOS_DEFAULT_DEVICE`: Default device name (e.g., "max")
- `IOS_DEVICES`: Comma-separated device names for eval (empty = all)

**Xcode settings:**
- `IOS_DEVELOPER_DIR`: Xcode developer directory (empty = auto-detect)
- `IOS_XCODE_VERSION`: Pinned Xcode version for CI (default: "26.2")
- `IOS_DOWNLOAD_RUNTIME`: Auto-download missing runtimes (1/0; default: 1)

**App configuration:**
- `IOS_APP_ARTIFACT`: .app path or glob (empty = auto-detect)
- `IOS_APP_SCHEME`: Xcode scheme override (empty = auto-detect from project)
- `IOS_APP_PROJECT`: Explicit .xcworkspace or .xcodeproj path (empty = auto-detect)
- `IOS_BUILD_CONFIG`: Build type (Debug, Release; default: Debug)
- `IOS_DERIVED_DATA_PATH`: DerivedData directory (default: .devbox/virtenv/ios/DerivedData)

**Performance:**
- `IOS_SKIP_SETUP`: Skip iOS setup during init (0/1; default: 0)
  - Use in Android-only contexts to speed up React Native workflows
  - Set before shell init: `devbox run -e IOS_SKIP_SETUP=1 build:android`

**Runtime state:**
- `IOS_RUNTIME_DIR`: State files directory (default: .devbox/virtenv/ios/runtime)
- `SUITE_NAME`: Test suite name for state isolation (default: "default")
  - Each suite gets subdirectory: `$IOS_RUNTIME_DIR/$SUITE_NAME/`
  - State files: simulator-udid.txt, test-simulator-udid.txt (pure mode), bundle-id.txt
  - Set in process-compose for parallel tests

**Internal variables (set automatically):**
- `DEVELOPER_DIR`: Xcode developer directory (used by xcrun, xcodebuild)
- `CC`: C compiler path (/usr/bin/clang)
- `CXX`: C++ compiler path (/usr/bin/clang++)
- `IOS_SIM_UDID`: UUID of running simulator
- `IOS_SIM_NAME`: Name of running simulator

## Xcode Discovery

Auto-detection strategy:
1. Check `IOS_DEVELOPER_DIR` env var
2. Find latest Xcode in `/Applications/Xcode*.app` by version
3. Use `xcode-select -p` output
4. Fallback to `/Applications/Xcode.app/Contents/Developer`

Override:
```json
{
  "env": {
    "IOS_DEVELOPER_DIR": "/Applications/Xcode-15.4.app/Contents/Developer"
  }
}
```

Xcode path cached in `.xcode_dev_dir.cache` (1-hour TTL).

## Runtime Management

List available runtimes:
```bash
xcrun simctl list runtimes
```

Download runtime manually:
```bash
xcodebuild -downloadPlatform iOS
```

Enable auto-download:
```json
{
  "env": {
    "IOS_DOWNLOAD_RUNTIME": "1"
  }
}
```

WARNING: First runtime download can be large (several GB). Subsequent simulator operations may fail until download completes.

## Common Workflows

### Initial Setup

```bash
# 1. Include plugin in devbox.json
# 2. Create device definitions
mkdir -p devbox.d/ios/devices

cat > devbox.d/ios/devices/min.json <<EOF
{
  "name": "iPhone 13",
  "runtime": "15.4"
}
EOF

cat > devbox.d/ios/devices/max.json <<EOF
{
  "name": "iPhone 15 Pro",
  "runtime": "17.5"
}
EOF

# 3. Generate lock file
devbox run --pure ios.sh devices eval

# 4. Configure defaults in devbox.json
{
  "env": {
    "IOS_DEFAULT_DEVICE": "max",
    "IOS_DEVICES": "min,max"
  }
}

# 5. Initialize environment
devbox shell

# 6. Verify setup
devbox run verify:setup
```

### Development Workflow

```bash
# Start simulator (reuse if running)
devbox run start:sim

# Build and deploy
devbox run build
ios.sh deploy

# Or build + deploy in one step
ios.sh run

# Check app status
ios.sh app status

# Stop app
ios.sh app stop

# Stop simulator when done
devbox run stop:sim
```

### Testing Workflow (Pure Mode)

```bash
# Start fresh simulator with clean state
devbox run --pure ios.sh simulator start --pure

# Wait for boot
devbox run --pure ios.sh simulator ready

# Build and deploy
devbox run --pure build
ios.sh deploy

# Run tests
devbox run test

# Stop simulator (deletes test simulator)
devbox run --pure ios.sh simulator stop
```

### Parallel Test Suites

Use `SUITE_NAME` for state isolation:

In process-compose YAML:
```yaml
test-suite-1:
  command: |
    export SUITE_NAME=suite1
    devbox run --pure ios.sh simulator start --pure
    devbox run test
    devbox run stop:sim
  environment:
    - SUITE_NAME=suite1

test-suite-2:
  command: |
    export SUITE_NAME=suite2
    devbox run --pure ios.sh simulator start --pure
    devbox run test
    devbox run stop:sim
  environment:
    - SUITE_NAME=suite2
```

Each suite tracks simulator UDID and bundle ID independently.

### Switching Devices

```bash
# Temporarily use different device
IOS_DEVICE_NAME=min devbox run start:sim
IOS_DEVICE_NAME=min ios.sh run

# Change default device
{
  "env": {
    "IOS_DEFAULT_DEVICE": "min"
  }
}
```

### CI Optimization

Limit evaluated devices to speed up CI:

```json
{
  "env": {
    "IOS_DEVICES": "max"
  }
}
```

Only evaluates selected devices in lock file generation.

## File Structure

```
.
├── devbox.json                                         # Plugin include, config
├── devbox.d/
│   └── ios/
│       └── devices/                                    # Device definitions
│           ├── min.json
│           ├── max.json
│           └── devices.lock                            # Generated lock file
└── .devbox/
    └── virtenv/
        └── ios/
            ├── scripts/                                # Runtime scripts (in PATH)
            │   ├── lib/                                # Layer 1: Utilities
            │   ├── platform/                           # Layer 2: Xcode/device config
            │   ├── domain/                             # Layer 3: Operations
            │   ├── user/                               # Layer 4: CLI
            │   └── init/                               # Layer 5: Init hooks
            ├── DerivedData/                            # Build artifacts
            ├── runtime/                                # Runtime state
            │   └── default/                            # Default suite state
            │       ├── simulator-udid.txt
            │       ├── test-simulator-udid.txt         # Pure mode only
            │       └── bundle-id.txt
            └── .xcode_dev_dir.cache                    # Xcode path cache (1h TTL)
```

WARNING: Never edit `.devbox/virtenv/` directly. Files are regenerated. Edit `devbox.json` or device definitions instead.

## Diagnostics

### Run Diagnostics

```bash
devbox run --pure doctor
```

Checks:
- Xcode installation
- Command-line tools
- xcrun and simctl availability
- Device definitions
- Lock file status

### Verify Setup

```bash
devbox run verify:setup
```

Quick check that iOS environment is functional. Exits 1 on failure.

## Troubleshooting

### Xcode Not Found

Check Xcode installation:
```bash
# Install Xcode from App Store, then:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Or install command-line tools only:
xcode-select --install
```

### Runtime Not Available

List and download runtimes:
```bash
# List available runtimes
xcrun simctl list runtimes

# Download runtime
xcodebuild -downloadPlatform iOS

# Or enable auto-download
{
  "env": {
    "IOS_DOWNLOAD_RUNTIME": "1"
  }
}
```

### CoreSimulatorService Issues

Restart simulator service:
```bash
killall -9 com.apple.CoreSimulatorService 2>/dev/null
launchctl kickstart -k gui/$UID/com.apple.CoreSimulatorService
open -a Simulator
```

### Lock File Out of Sync

Regenerate lock file:
```bash
devbox run --pure ios.sh devices eval
```

### Build Failures

Checklist:
1. Verify `.xcodeproj` or `.xcworkspace` exists in project root
2. Check `build:ios` or `build` script in devbox.json
3. Ensure derived data directory is writable
4. Clean build: `rm -rf .devbox/virtenv/ios/DerivedData`
5. Verify using `ios.sh xcodebuild` not bare `xcodebuild`

### .app Not Found

Check resolution:
1. Set `IOS_APP_ARTIFACT` in devbox.json
2. Verify build succeeded: `devbox run build`
3. Check DerivedData: `ls .devbox/virtenv/ios/DerivedData/Build/Products/Debug-iphonesimulator/`

## Quick Reference

| Task | Command |
|------|---------|
| List devices | `devbox run --pure ios.sh devices list` |
| Create device | `devbox run --pure ios.sh devices create <name> --runtime <ver>` |
| Regenerate lock | `devbox run --pure ios.sh devices eval` |
| Sync simulators | `devbox run --pure ios.sh devices sync` |
| Start simulator | `devbox run start:sim [device]` |
| Start simulator (pure) | `devbox run --pure ios.sh simulator start --pure [device]` |
| Stop simulator | `devbox run stop:sim` |
| Check ready | `devbox run --pure ios.sh simulator ready` |
| Build app | `devbox run build` |
| Deploy .app | `ios.sh deploy [app_path]` |
| Run app | `ios.sh run [app_path] [device]` |
| App status | `ios.sh app status` |
| Stop app | `ios.sh app stop` |
| Show config | `devbox run --pure ios.sh config show` |
| Show SDK info | `devbox run --pure ios.sh info` |
| Diagnostics | `devbox run --pure doctor` |
| Verify setup | `devbox run verify:setup` |

## Key Differences from Standard iOS Development

**Standard iOS:**
- Global Xcode configuration
- Manual simulator management via Xcode
- Manual xcodebuild commands
- No state tracking
- Developer-specific environment

**Devbox iOS:**
- Project-local configuration
- Scripted simulator lifecycle
- `ios.sh xcodebuild` wrapper (strips Nix flags)
- State-tracked deployments (UDID, bundle ID)
- Reproducible across machines

All iOS state is project-local. No global pollution. Uses system Xcode but isolates configuration.

## Platform Requirements

- macOS only (plugin exits silently on other platforms)
- Xcode installed (from App Store or command-line tools)
- iOS Simulator (included with Xcode)
- Devbox for plugin system

Non-Darwin platforms: Plugin init hooks exit immediately without errors, allowing cross-platform devbox.json files with both Android and iOS plugins.
