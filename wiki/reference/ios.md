# iOS Devbox Plugin Reference

## Files

- Device definitions in your devbox.d directory (e.g., `devbox.d/ios/devices/*.json`)
- `devices/devices.lock` in your devbox.d directory — generated lock file (tracks evaluated devices)
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
- Auto-detects pure mode when `IN_NIX_SHELL=pure` or `DEVBOX_PURE_SHELL=1`
- Saves simulator UDID to `$IOS_RUNTIME_DIR/${SUITE_NAME:-default}/simulator-udid.txt`

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
- Saves bundle ID to `$IOS_RUNTIME_DIR/${SUITE_NAME:-default}/bundle-id.txt`

### App Lifecycle

```bash
ios.sh app status
```
- Checks if the deployed app is running on the simulator
- Exit 0 if running, exit 1 if not

```bash
ios.sh app stop
```
- Terminates the deployed app via `xcrun simctl terminate`

### Run App

```bash
ios.sh run [app_path] [device]
```
- Starts simulator, builds, installs, and launches the app
- If `app_path` is provided, skips build and installs the provided .app bundle directly
- If no arguments, builds project (via `build:ios` or `build` scripts) and auto-detects the .app bundle
- Auto-detection precedence: `IOS_APP_ARTIFACT` env var → xcodebuild settings → recursive search
- Bundle ID is auto-extracted from `Info.plist`

### Device Management

List devices:
```bash
devbox run --pure ios.sh devices list
```
Shows all device definitions in your devbox.d directory

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
#   "include": ["github:segment-integrations/devbox-plugins?dir=plugins/ios"],
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

# Start simulator (plugin-provided)
devbox run start:sim

# Build and run app (user-defined script in devbox.json)
# devbox run start:app
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

- [Architecture](../project/ARCHITECTURE.md) — Script architecture and layer dependencies
- [Plugin Conventions](../project/CONVENTIONS.md) — Plugin development patterns
- `examples/ios/` — Example iOS project
- `examples/react-native/` — React Native with iOS
