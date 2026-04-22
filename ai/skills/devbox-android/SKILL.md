---
name: devbox-android
description: Android Devbox plugin for reproducible Android development with Nix-managed SDK, emulators, and device management. No global ~/.android pollution.
argument-hint: [command or workflow]
disable-model-invocation: false
allowed-tools: Bash(devbox *) Bash(android.sh *) Read Edit Write
---

# Devbox Android Plugin

## Overview

Android Devbox plugin provides reproducible Android development environments via Nix. SDK and emulators are project-local, not global (~/.android never touched).

Key features:
- Nix-managed Android SDK (no manual downloads)
- Device definitions as JSON files
- Emulator management with state isolation
- APK deployment and app lifecycle control

## Setup

### Include Plugin

In `devbox.json`:
```json
{
  "include": ["github:segment-integrations/mobile-devtools?dir=plugins/android&ref=main"],
  "packages": {
    "jdk17": "latest",
    "gradle": "latest"
  }
}
```

### Initialize

```bash
devbox shell                # Downloads SDK, sets up environment
```

First run downloads Android SDK components based on device definitions. Subsequent runs are fast (Nix caching).

## Device Management

### Device Definitions

Devices defined in JSON files at `devbox.d/android/devices/*.json`.

Schema:
```json
{
  "name": "pixel_api24",
  "api": 24,
  "device": "pixel",
  "tag": "google_apis",
  "preferred_abi": "x86_64"
}
```

Fields:
- `name` (required): Device identifier
- `api` (required): Android API level
- `device` (required): AVD device ID (pixel, Nexus5, etc.)
- `tag` (optional): System image tag (google_apis, google_apis_playstore, aosp_atd)
- `preferred_abi` (optional): CPU architecture (arm64-v8a, x86_64, x86)

### Device Commands

List devices:
```bash
devbox run --pure android.sh devices list
```

Show device details:
```bash
devbox run --pure android.sh devices show <name>
```

Create device:
```bash
devbox run --pure android.sh devices create <name> --api <n> --device <id>
devbox run --pure android.sh devices create <name> --api <n> --device <id> --tag <tag> --abi <abi>
```

Example:
```bash
devbox run --pure android.sh devices create pixel_api30 --api 30 --device pixel --tag google_apis --abi x86_64
```

Update device:
```bash
devbox run --pure android.sh devices update <name> [--name <new>] [--api <n>] [--device <id>] [--tag <tag>] [--abi <abi>]
```

Delete device:
```bash
devbox run --pure android.sh devices delete <name>
```

Select devices for evaluation:
```bash
devbox run --pure android.sh devices select <name1> <name2>
```

Sets `ANDROID_DEVICES` to comma-separated list. Affects which SDK components are downloaded.

Reset device selection:
```bash
devbox run --pure android.sh devices reset
```

Clears `ANDROID_DEVICES` (evaluates all devices).

Regenerate lock file:
```bash
devbox run --pure android.sh devices eval
```

After creating/updating/deleting devices, regenerate `devices.lock` to update SDK dependencies. Commit lock file to optimize CI.

WARNING: Always run `devices eval` after modifying device definitions. Lock file determines which SDK components are installed.

## Emulator Operations

### Start Emulator

```bash
devbox run --pure android.sh emulator start [device]
devbox run --pure android.sh emulator start --pure [device]
devbox run start:emu [device]                           # Alias
```

Behavior:
- Without `--pure`: Reuses running emulator if exists (fast, preserves data)
- With `--pure`: Wipes data and starts fresh (clean state for tests)
- Auto-detects pure mode when `DEVBOX_PURE_SHELL=1` (set by `devbox run --pure`)

Override pure mode:
```bash
devbox run --pure -e REUSE_EMU=1 android.sh emulator start [device]
```

Device selection:
- Argument: `devbox run start:emu min`
- Default: Uses `ANDROID_DEFAULT_DEVICE` from devbox.json
- Override: `ANDROID_DEVICE_NAME=max devbox run start:emu`

Emulator serial saved to `$ANDROID_RUNTIME_DIR/${SUITE_NAME:-default}/emulator-serial.txt`.

### Stop Emulator

```bash
devbox run --pure android.sh emulator stop
devbox run stop:emu                                     # Alias
```

Stops emulator tracked in current suite.

### Check Emulator Ready

```bash
devbox run --pure android.sh emulator ready
```

Silent probe. Exit 0 if booted, exit 1 if not. Uses `adb shell getprop sys.boot_completed`.

### Reset Emulator

```bash
devbox run --pure android.sh emulator reset [device]
```

Stops and wipes emulator data.

## App Building & Deployment

### Build App

Define build script in `devbox.json`:
```json
{
  "shell": {
    "scripts": {
      "build": ["gradle assembleDebug"],
      "build:release": ["gradle assembleRelease"]
    }
  }
}
```

Run:
```bash
devbox run build
devbox run build:release
```

### Deploy APK

```bash
android.sh deploy [apk_path]
```

Installs and launches APK on running emulator. No build, no emulator start.

APK resolution (when no path provided):
1. `ANDROID_APP_APK` env var (glob relative to project root)
2. Recursive search from project root for `*.apk` (excludes .gradle/, node_modules/, .devbox/)
3. Recursive search from `$PWD` if different

State saved:
- App ID → `$ANDROID_RUNTIME_DIR/${SUITE_NAME:-default}/app-id.txt`
- Activity → `$ANDROID_RUNTIME_DIR/${SUITE_NAME:-default}/app-activity.txt`

### Run App (Build + Deploy)

```bash
devbox run start:app [apk_path] [device]
```

Full workflow:
1. Builds project (calls `build:android` or `build` script)
2. Starts emulator if not running
3. Installs APK
4. Launches app

Example:
```bash
devbox run start:app                    # Build, detect APK, use default device
devbox run start:app app.apk min       # Use specific APK and device
```

Define in `devbox.json`:
```json
{
  "shell": {
    "scripts": {
      "start:app": ["android.sh run ${1:-${ANDROID_DEFAULT_DEVICE:-max}}"]
    }
  }
}
```

### App Lifecycle

Check app status:
```bash
android.sh app status
```

Exit 0 if running, exit 1 if not. Reads app ID from state file.

Stop app:
```bash
android.sh app stop
```

Force-stops app via `adb shell am force-stop`.

## Configuration

### View Configuration

```bash
devbox run --pure android.sh config show
```

Shows all Android plugin environment variables.

### Set Configuration

```bash
devbox run --pure android.sh config set KEY=VALUE [KEY=VALUE...]
```

Example:
```bash
devbox run --pure android.sh config set ANDROID_DEFAULT_DEVICE=min ANDROID_BUILD_CONFIG=Release
```

### Reset Configuration

```bash
devbox run --pure android.sh config reset
```

Removes all Android plugin configuration from devbox.json.

### Key Environment Variables

Set in `devbox.json` env section:

**Device selection:**
- `ANDROID_DEFAULT_DEVICE`: Default device name (e.g., "max")
- `ANDROID_DEVICES`: Comma-separated device names for SDK eval (empty = all)

**App configuration:**
- `ANDROID_APP_ID`: App identifier (e.g., "com.example.app")
- `ANDROID_APP_APK`: APK path or glob (e.g., "app/build/outputs/apk/debug/app-debug.apk")
- `ANDROID_BUILD_CONFIG`: Build type (Debug, Release; default: Debug)
- `ANDROID_BUILD_TASK`: Gradle task override (empty = auto-derive)

**SDK configuration:**
- `ANDROID_COMPILE_SDK`: Compile SDK version (e.g., "36")
- `ANDROID_TARGET_SDK`: Target SDK version (e.g., "36")
- `ANDROID_BUILD_TOOLS_VERSION`: Build tools version (e.g., "36.1.0")
- `ANDROID_SYSTEM_IMAGE_TAG`: Default system image tag (google_apis, google_apis_playstore)
- `ANDROID_LOCAL_SDK`: Use local SDK instead of Nix (0/1; default: 0)

**Performance:**
- `ANDROID_SKIP_SETUP`: Skip SDK downloads/evaluation during init (0/1; default: 0)
  - Use in iOS-only contexts to speed up React Native workflows
  - Set before shell init: `devbox run -e ANDROID_SKIP_SETUP=1 build:ios`

**Emulator behavior:**
- `EMU_HEADLESS`: Run emulator without GUI
- `EMU_PORT`: Preferred emulator port (default: 5554)
- `ANDROID_EMULATOR_PURE`: Always start fresh emulator (0/1; default: 0)
- `ANDROID_SKIP_CLEANUP`: Skip offline emulator cleanup (0/1; default: 0)
- `ANDROID_DISABLE_SNAPSHOTS`: Disable snapshot boots, force cold boot (0/1; default: 0)

**Runtime state:**
- `ANDROID_RUNTIME_DIR`: State files directory (default: .devbox/virtenv/android)
- `SUITE_NAME`: Test suite name for state isolation (default: "default")
  - Each suite gets subdirectory: `$ANDROID_RUNTIME_DIR/$SUITE_NAME/`
  - State files: emulator-serial.txt, app-id.txt, app-activity.txt
  - Set in process-compose for parallel tests

**Runtime overrides:**
- `ANDROID_DEVICE_NAME`: Override device at runtime (e.g., `ANDROID_DEVICE_NAME=min devbox run start:emu`)
- `REUSE_EMU`: Force emulator reuse even in pure mode (e.g., `devbox run --pure -e REUSE_EMU=1`)

## Common Workflows

### Initial Setup

```bash
# 1. Include plugin in devbox.json
# 2. Create device definitions
mkdir -p devbox.d/android/devices

cat > devbox.d/android/devices/min.json <<EOF
{
  "name": "pixel_api24",
  "api": 24,
  "device": "pixel",
  "tag": "google_apis"
}
EOF

cat > devbox.d/android/devices/max.json <<EOF
{
  "name": "pixel_api36",
  "api": 36,
  "device": "pixel",
  "tag": "google_apis"
}
EOF

# 3. Generate lock file
devbox run --pure android.sh devices eval

# 4. Configure defaults in devbox.json
devbox run --pure android.sh config set ANDROID_DEFAULT_DEVICE=max

# 5. Initialize environment
devbox shell
```

### Development Workflow

```bash
# Start emulator (reuse if running)
devbox run start:emu

# Build and deploy
devbox run build
android.sh deploy

# Or build + deploy in one step
devbox run start:app

# Check app status
android.sh app status

# Stop app
android.sh app stop

# Stop emulator when done
devbox run stop:emu
```

### Testing Workflow (Pure Mode)

```bash
# Start fresh emulator with clean state
devbox run --pure android.sh emulator start --pure

# Wait for boot
devbox run --pure android.sh emulator ready

# Build and deploy
devbox run --pure build
android.sh deploy

# Run tests
devbox run test

# Stop emulator
devbox run --pure android.sh emulator stop
```

### Parallel Test Suites

Use `SUITE_NAME` for state isolation:

In process-compose YAML:
```yaml
test-suite-1:
  command: |
    export SUITE_NAME=suite1
    devbox run --pure android.sh emulator start --pure
    devbox run test
    devbox run stop:emu
  environment:
    - SUITE_NAME=suite1

test-suite-2:
  command: |
    export SUITE_NAME=suite2
    devbox run --pure android.sh emulator start --pure
    devbox run test
    devbox run stop:emu
  environment:
    - SUITE_NAME=suite2
```

Each suite tracks emulator serial and app state independently.

### Switching Devices

```bash
# Temporarily use different device
ANDROID_DEVICE_NAME=min devbox run start:emu
ANDROID_DEVICE_NAME=min devbox run start:app

# Change default device
devbox run --pure android.sh config set ANDROID_DEFAULT_DEVICE=min
```

### CI Optimization

Limit evaluated devices to speed up CI:

```json
{
  "env": {
    "ANDROID_DEVICES": "max"
  }
}
```

Or select at runtime:
```bash
devbox run --pure android.sh devices select max
```

Only downloads SDK components for selected devices.

## File Structure

```
.
├── devbox.json                                         # Plugin include, config
├── devbox.d/
│   └── android/
│       ├── devices/                                    # Device definitions
│       │   ├── min.json
│       │   ├── max.json
│       │   └── devices.lock                            # Generated lock file
│       └── flake.nix                                   # SDK flake (generated)
└── .devbox/
    └── virtenv/
        └── android/
            ├── scripts/                                # Runtime scripts (in PATH)
            │   ├── android.sh
            │   ├── avd.sh
            │   ├── emulator.sh
            │   └── ...
            ├── android.json                            # Generated config (for Nix)
            └── default/                                # Default suite state
                ├── emulator-serial.txt
                ├── app-id.txt
                └── app-activity.txt
```

WARNING: Never edit `.devbox/virtenv/` directly. Files are regenerated. Edit `devbox.json` or device definitions instead.

## Troubleshooting

### Emulator won't start

Check:
1. Device definition exists: `devbox run --pure android.sh devices list`
2. Lock file regenerated: `devbox run --pure android.sh devices eval`
3. Emulator not already running: `devbox run stop:emu`
4. Port not in use: Try different `EMU_PORT`

### APK not found

Check:
1. Build script defined: `devbox run --list`
2. Build succeeded: `devbox run build`
3. APK path correct: Set `ANDROID_APP_APK` in devbox.json
4. APK exists: `ls app/build/outputs/apk/debug/`

### SDK components missing

Run:
```bash
devbox run --pure android.sh devices eval
devbox shell  # Re-initialize to download components
```

### State file errors

Reset state:
```bash
rm -rf .devbox/virtenv/android/default/
```

Or use different suite:
```bash
SUITE_NAME=fresh devbox run start:emu
```

## Quick Reference

| Task | Command |
|------|---------|
| List devices | `devbox run --pure android.sh devices list` |
| Create device | `devbox run --pure android.sh devices create <name> --api <n> --device <id>` |
| Regenerate lock | `devbox run --pure android.sh devices eval` |
| Start emulator | `devbox run start:emu [device]` |
| Start emulator (pure) | `devbox run --pure android.sh emulator start --pure [device]` |
| Stop emulator | `devbox run stop:emu` |
| Check ready | `devbox run --pure android.sh emulator ready` |
| Build app | `devbox run build` |
| Deploy APK | `android.sh deploy [apk_path]` |
| Run app | `devbox run start:app [apk_path] [device]` |
| App status | `android.sh app status` |
| Stop app | `android.sh app stop` |
| Show config | `devbox run --pure android.sh config show` |
| Set config | `devbox run --pure android.sh config set KEY=VALUE` |

## Key Differences from Standard Android Development

**Standard Android:**
- Global SDK in ~/.android
- Manual AVD Manager usage
- Manual emulator start/stop
- Manual adb commands
- Dependency on system Android tools

**Devbox Android:**
- Project-local SDK (Nix-managed)
- Device definitions as JSON
- Scripted emulator lifecycle
- State-tracked deployments
- Reproducible across machines

All Android state is project-local. No global pollution. Delete `.devbox/` and `devbox.d/` to completely remove Android from project.
