# iOS Devbox Plugin Reference

## Files

- `devbox.d/ios/devices/*.json` — simulator definitions
- `devbox.d/ios/devices/devices.lock` — generated lock file (tracks evaluated devices)
- `.devbox/virtenv/ios/scripts/` — runtime scripts (organized by layer)
  - `lib/` — utility functions
  - `platform/` — Xcode discovery and device config
  - `domain/` — device management, simulator, deployment operations
  - `user/` — user-facing CLI scripts (ios.sh, devices.sh, config.sh)
  - `init/` — initialization hooks

## Device Definition Schema

Each device file is JSON with:
- `name` (string, required) — simulator display name
- `runtime` (string, required) — iOS version (e.g., "17.5", "18.0", "15.4")

Example:
```json
{
  "name": "iPhone 15 Pro",
  "runtime": "17.5"
}
```

## Configuration (Environment Variables)

Configure the plugin by setting environment variables in `devbox.json` or `plugin.json`:

### Core Settings
- `IOS_CONFIG_DIR` — Configuration directory (default: `devbox.d/ios`)
- `IOS_DEVICES_DIR` — Device definitions directory (default: `devbox.d/ios/devices`)
- `IOS_SCRIPTS_DIR` — Scripts directory (default: `.devbox/virtenv/ios/scripts`)
- `IOS_DEVICES` — Comma-separated device names to evaluate (empty = all devices)
- `IOS_DEFAULT_DEVICE` — Default device name when none specified (default: "max")
- `IOS_DEFAULT_RUNTIME` — Default iOS runtime version (empty = latest available)

### Xcode Settings
- `IOS_DEVELOPER_DIR` — Xcode developer directory path (empty = auto-detect)
- `IOS_XCODE_ENV_PATH` — Additional PATH entries for Xcode tools
- `IOS_DOWNLOAD_RUNTIME` — Auto-download missing runtimes (1=yes, 0=no; default: 1)

### App Settings
- `IOS_APP_ARTIFACT` — Path or glob pattern for .app bundle (relative to project root; empty = auto-detect)
- `IOS_APP_SCHEME` — Xcode scheme override (empty = auto-detect from project filename)
- `IOS_APP_PROJECT` — Explicit .xcworkspace or .xcodeproj path (empty = auto-detect)
- `IOS_BUILD_CONFIG` — Build configuration: Debug or Release (default: "Debug")
- `IOS_DERIVED_DATA_PATH` — DerivedData directory path (default: `.devbox/virtenv/ios/DerivedData`)

### Performance Settings
- `IOS_SKIP_SETUP` — Skip iOS environment setup during shell initialization (1=skip, 0=setup; default: 0)
  - Useful for Android-only contexts in React Native projects to speed up initialization
  - When set to 1, skips Xcode path detection, device lock generation, and environment configuration

## Commands

### Simulator Management

Start simulator:
```bash
ios.sh simulator start [--pure] [device]
```
- If `device` is specified, uses that device name
- Otherwise uses `IOS_DEFAULT_DEVICE`
- Boots simulator if not already running
- `--pure`: Creates a fresh, isolated test simulator with clean state (for deterministic tests)
- Auto-detects pure mode when `DEVBOX_PURE_SHELL=1` (set by `devbox run --pure`)
- `REUSE_SIM=1`: Override pure mode to reuse existing simulator (e.g., `devbox run --pure -e REUSE_SIM=1`)
- Saves simulator UDID to `$IOS_RUNTIME_DIR/${SUITE_NAME:-default}/simulator-udid.txt`
- In pure mode, test simulator name includes suite label for isolation (e.g., `"iPhone 17 (iOS 26.2) Test-ios-e2e"`)

**Convenience aliases:**
- `devbox run --pure start:sim [device]` (equivalent to `ios.sh simulator start` without `--pure`)
- `devbox run --pure stop:sim` (equivalent to `ios.sh simulator stop`)

Stop simulator:
```bash
ios.sh simulator stop
```
- In pure mode (test simulator exists): shuts down and deletes the test simulator, cleans up state files
- In normal mode: shuts down the simulator via `ios_stop()`

Check simulator readiness:
```bash
ios.sh simulator ready
```
- Silent readiness probe: exit 0 if simulator is booted, exit 1 if not
- Reads UDID from suite-namespaced state file, falls back to finding any booted simulator
- Designed for use as a process-compose readiness probe

Reset simulators:
```bash
ios.sh simulator reset
```
- Stops all running simulators
- Deletes simulators matching device definitions

### Deploy

```bash
ios.sh deploy [app_path]
```
- Installs and launches an app on an already-running simulator (no build, no simulator start)
- If `app_path` is provided, installs the specified .app bundle
- If no arguments, auto-detects .app using `ios_find_app()` (same resolution as `run`)
- Reads simulator UDID from suite-namespaced state file
- Extracts bundle ID from the app's `Info.plist`
- Saves bundle ID to `$IOS_RUNTIME_DIR/${SUITE_NAME:-default}/bundle-id.txt`

### App Lifecycle

```bash
ios.sh app status
```
- Checks if the deployed app is running on the simulator
- Exit 0 if running, exit 1 if not
- Reads bundle ID and simulator UDID from suite-namespaced state files

```bash
ios.sh app stop
```
- Terminates the deployed app via `xcrun simctl terminate`
- Reads bundle ID and simulator UDID from suite-namespaced state files

### Build

```bash
ios.sh build [--config Debug|Release] [--scheme name] [--workspace path]
             [--project path] [--derived-data path] [--quiet] [--action build|test]
             [-- extra_xcodebuild_args...]
```
- Auto-detects Xcode project (.xcworkspace preferred over .xcodeproj)
- Default action: `build`. Use `--action test` for xcodebuild tests.
- Calls `xcodebuild` directly (Nix vars are stripped at init time)

**Project detection order:**
1. Current working directory
2. `$DEVBOX_PROJECT_ROOT` (if different)
3. `$PWD/ios/` (React Native convention)
4. `$DEVBOX_PROJECT_ROOT/ios/` (if different)

Within each directory, prefers `.xcworkspace` over `.xcodeproj`. Scheme is derived from the project filename (e.g., `MyApp.xcodeproj` → `MyApp`), overridable via `--scheme` or `IOS_APP_SCHEME`.

**Examples:**
```bash
# Build with defaults (Debug, auto-detect project)
ios.sh build

# Build Release
ios.sh build --config Release

# Run xcodebuild tests
ios.sh build --action test

# Explicit workspace and scheme
ios.sh build --workspace ios/MyApp.xcworkspace --scheme MyApp

# Pass extra flags to xcodebuild
ios.sh build --quiet -- -allowProvisioningUpdates
```

Use in `devbox.json`:
```json
{
  "shell": {
    "scripts": {
      "build": ["ios.sh build"],
      "build:release": ["ios.sh build --config Release"],
      "test": ["ios.sh build --action test"]
    }
  }
}
```

### Xcode Build Wrapper

```bash
ios.sh xcodebuild [args...]
```
- Runs `xcodebuild` with Nix-incompatible environment variables removed
- Unsets `LD`, `LDFLAGS`, `NIX_LDFLAGS`, `NIX_CFLAGS_COMPILE`, and `NIX_CFLAGS_LINK` in a subshell
- All arguments are forwarded directly to `xcodebuild`
- The caller's environment is not affected (stripping happens in a subshell)

Use this in `devbox.json` build scripts instead of manually stripping Nix flags:
```json
{
  "shell": {
    "scripts": {
      "build:ios": [
        "ios.sh xcodebuild -project MyApp.xcodeproj -scheme MyApp -configuration Debug -destination 'generic/platform=iOS Simulator' build"
      ]
    }
  }
}
```

The iOS init hook (`devbox_omit_nix_env()`) strips Nix compilation variables at shell startup, so `xcodebuild` works natively in devbox shell. The `ios.sh xcodebuild` subcommand forwards directly to `xcodebuild`.

### Run App

```bash
ios.sh run [app_path] [device]
```
- Starts simulator, builds, resolves, installs, and launches the app
- If `app_path` is provided, skips build step and installs the provided .app bundle
- If no arguments, builds project and auto-detects the .app bundle

**.app resolution precedence (when no explicit path):**

1. `IOS_APP_ARTIFACT` env var — glob resolved relative to project root
2. `xcodebuild -showBuildSettings` — queries BUILT_PRODUCTS_DIR + FULL_PRODUCT_NAME from the Xcode project
3. Recursive search of project root for `*.app` directories (excludes Pods/, .build/, SourcePackages/, node_modules/, .devbox/, DerivedData/ModuleCache/)
4. Recursive search of `$PWD` if different from project root (same exclusions)

Bundle ID is auto-extracted from the .app's `Info.plist` via PlistBuddy, or from `xcodebuild -showBuildSettings` if available.

**Build script detection:** The `run` command tries `build:ios` first, then falls back to `build`. If neither script exists, it runs `ios.sh build` to auto-detect and build the Xcode project.

### Device Management

List devices:
```bash
devbox run --pure ios.sh devices list
```
Shows all device definitions in `devbox.d/ios/devices/`

Show specific device:
```bash
devbox run --pure ios.sh devices show <name>
```
Displays device JSON configuration

Create device:
```bash
devbox run --pure ios.sh devices create <name> --runtime <version>
```
- `name`: Device name (used as filename and display name)
- `runtime`: iOS version (e.g., "17.5", "18.0")
- Example: `ios.sh devices create iphone15 --runtime 17.5`

Update device:
```bash
devbox run --pure ios.sh devices update <name> [--name <new>] [--runtime <version>]
```
- `--name`: Rename device
- `--runtime`: Change iOS version

Delete device:
```bash
devbox run --pure ios.sh devices delete <name>
```
Removes device definition file

Generate lock file:
```bash
devbox run --pure ios.sh devices eval
```
- Generates `devices.lock` from device definitions
- Respects `IOS_DEVICES` filter (empty = all devices)
- Includes checksum for validation

Sync simulators:
```bash
devbox run --pure ios.sh devices sync
```
- Reads `devices.lock`
- Creates/updates simulators to match definitions
- Reports: matched, recreated, created, skipped

### Config Management

Show configuration:
```bash
devbox run --pure ios.sh config show
```
Displays current environment variable configuration

Show SDK info:
```bash
devbox run --pure ios.sh info
```
Shows:
- Xcode developer directory
- iOS SDK version
- Available runtimes
- Device configuration

### Diagnostics

Run diagnostics:
```bash
devbox run --pure doctor
```
Checks:
- Xcode installation
- Command-line tools
- xcrun and simctl availability
- Device definitions
- Lock file status

Verify setup:
```bash
devbox run --pure verify:setup
```
Quick check that iOS environment is functional (exits 1 on failure)

## Device Filtering

Control which devices are evaluated using the `IOS_DEVICES` environment variable in `devbox.json`:

Evaluate all devices (default):
```json
{
  "env": {
    "IOS_DEVICES": ""
  }
}
```

Evaluate specific devices:
```json
{
  "env": {
    "IOS_DEVICES": "min,max"
  }
}
```

After changing `IOS_DEVICES`, regenerate the lock file:
```bash
devbox run --pure ios.sh devices eval
```

## Runtime Management

Available runtimes are managed by Xcode. To list available runtimes:
```bash
xcrun simctl list runtimes
```

Runtimes can be downloaded automatically if `IOS_DOWNLOAD_RUNTIME=1`:
```bash
# Manual download
xcodebuild -downloadPlatform iOS

# Or set in devbox.json for automatic downloads
{
  "env": {
    "IOS_DOWNLOAD_RUNTIME": "1"
  }
}
```

## Xcode Discovery

The plugin auto-detects Xcode using this strategy:

1. Check `IOS_DEVELOPER_DIR` environment variable
2. Find latest Xcode in `/Applications/Xcode*.app` by version number
3. Use `xcode-select -p` output
4. Fallback to `/Applications/Xcode.app/Contents/Developer`

Override discovery by setting `IOS_DEVELOPER_DIR`:
```json
{
  "env": {
    "IOS_DEVELOPER_DIR": "/Applications/Xcode-15.4.app/Contents/Developer"
  }
}
```

## Lock File Format

The `devices.lock` file tracks which devices should be created:

```json
{
  "devices": [
    {
      "name": "iPhone 15 Pro",
      "runtime": "17.5"
    },
    {
      "name": "iPad Pro",
      "runtime": "17.5"
    }
  ],
  "checksum": "abc123...",
  "generated_at": "2026-02-09T12:00:00Z"
}
```

- `devices`: Array of device definitions to create
- `checksum`: SHA-256 hash of all device definition files (for validation)
- `generated_at`: ISO 8601 timestamp

## Script Architecture

Scripts are organized in 5 layers (see `wiki/project/ARCHITECTURE.md` for details):

**Layer 1 - lib/**: Pure utility functions
- `lib/lib.sh` — path resolution, checksums, validation utilities

**Layer 2 - platform/**: Platform setup
- `platform/core.sh` — Xcode discovery, environment setup, debug logging
- `platform/device_config.sh` — Device file management

**Layer 3 - domain/**: Domain operations
- `domain/device_manager.sh` — Runtime resolution, simulator operations
- `domain/simulator.sh` — Simulator lifecycle management
- `domain/build.sh` — Build command (auto-detect and build Xcode project)
- `domain/deploy.sh` — App building and deployment
- `domain/validate.sh` — Non-blocking validation

**Layer 4 - user/**: User-facing CLI
- `user/ios.sh` — Main CLI router
- `user/devices.sh` — Device management CLI
- `user/config.sh` — Configuration management

**Layer 5 - init/**: Initialization
- `init/init-hook.sh` — Pre-shell initialization (lock file generation)
- `init/setup.sh` — Shell environment setup

## Environment Variables Reference

### Internal Variables

These are set automatically by the plugin:

- `DEVELOPER_DIR` — Xcode developer directory (used by xcrun, xcodebuild)
- `CC` — C compiler path (`/usr/bin/clang`)
- `CXX` — C++ compiler path (`/usr/bin/clang++`)
- `PATH` — Updated with Xcode tools and plugin scripts
- `IOS_NODE_BINARY` — Node.js binary path (if available, for React Native)

### Runtime State

- `IOS_RUNTIME_DIR` — Directory for runtime state files (default: `.devbox/virtenv/ios/runtime`)
- `SUITE_NAME` — Test suite name for state isolation (default: "default")
  - Each suite gets its own subdirectory under `$IOS_RUNTIME_DIR/$SUITE_NAME/`
  - State files: `simulator-udid.txt`, `test-simulator-udid.txt` (pure mode only), `bundle-id.txt`
  - Set in process-compose environment blocks for parallel test execution

### Runtime Variables

Set during simulator/app operations:

- `IOS_SIM_UDID` — UUID of running simulator
- `IOS_SIM_NAME` — Name of running simulator

## Troubleshooting

### Xcode Not Found

**Symptom:** "Xcode developer directory not found"

**Solution:**
```bash
# Install Xcode from App Store, then:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Or install command-line tools only:
xcode-select --install
```

### Runtime Not Available

**Symptom:** "Runtime iOS X.X not found"

**Solution:**
```bash
# List available runtimes
xcrun simctl list runtimes

# Download runtime
xcodebuild -downloadPlatform iOS

# Or enable auto-download in devbox.json
{
  "env": {
    "IOS_DOWNLOAD_RUNTIME": "1"
  }
}
```

### CoreSimulatorService Issues

**Symptom:** "CoreSimulatorService connection became invalid"

**Solution:**
```bash
# Restart CoreSimulatorService
killall -9 com.apple.CoreSimulatorService 2>/dev/null
launchctl kickstart -k gui/$UID/com.apple.CoreSimulatorService

# Open Simulator to initialize
open -a Simulator
```

### Lock File Out of Sync

**Symptom:** "Warning: devices.lock may be stale"

**Solution:**
```bash
devbox run --pure ios.sh devices eval
```

### Build Failures

**Symptom:** Xcode build errors

**Checklist:**
1. Check that your `.xcodeproj` or `.xcworkspace` exists in the project root
2. Verify `build:ios` or `build` script in devbox.json is correct
3. Ensure derived data directory is writable
4. Clean build: `rm -rf DerivedData` or the path your build script uses

## Platform Requirements

- **macOS only** — iOS development requires macOS and Xcode
- **Xcode** — Install from App Store or use Xcode Command Line Tools
- **iOS Simulator** — Included with Xcode
- **Devbox** — Required for plugin system
- **Non-Darwin:** On non-macOS platforms, the iOS plugin init hooks exit immediately without errors, allowing cross-platform devbox.json files that include both Android and iOS plugins.

## Best Practices

### Device Management
- Use semantic names: `min.json`, `max.json` for version boundaries
- Use descriptive names: `iphone15_pro.json`, `ipad_air.json`
- Commit device definitions and lock files to version control
- Regenerate lock file after device changes

### Runtime Selection
- Test on minimum and maximum supported iOS versions
- Use `IOS_DEVICES="min,max"` for CI to limit evaluated runtimes
- Keep runtime versions up to date

### Xcode Configuration
- Pin Xcode version in CI using `IOS_DEVELOPER_DIR`
- Use latest stable Xcode for development
- Keep command-line tools updated

### Build Configuration
- Use project-relative paths for `IOS_APP_ARTIFACT` when auto-detect doesn't work
- Commit derived data directories to `.gitignore`
- Auto-detect works best when a single `.xcodeproj` or `.xcworkspace` exists in project root

## Example Workflows

### Initial Setup
```bash
cd my-ios-project

# Add iOS plugin to devbox.json
# {
#   "include": ["plugin:ios"],
#   "env": {
#     "IOS_DEVICES": "min,max",
#     "IOS_DEFAULT_DEVICE": "max"
#   }
# }

# Enter devbox shell
devbox shell

# Verify setup
devbox run verify:setup

# List device definitions
ios.sh devices list

# Generate lock file
ios.sh devices eval

# Start simulator
devbox run start:sim

# Build and run app
ios.sh run
```

### Adding New Device
```bash
# Create device definition
ios.sh devices create iphone14 --runtime 16.4

# Regenerate lock file
ios.sh devices eval

# Sync simulators
ios.sh devices sync

# Verify
ios.sh devices list
```

### CI Configuration
```yaml
# .github/workflows/ios.yml
- name: Setup iOS environment
  run: |
    devbox install
    devbox run verify:setup

- name: Run tests
  run: |
    devbox run test:ios
```

## See Also

- `wiki/project/ARCHITECTURE.md` — Script architecture and layer dependencies
- `plugins/CONVENTIONS.md` — Plugin development patterns
- `examples/ios/` — Example iOS project
- `examples/react-native/` — React Native with iOS
