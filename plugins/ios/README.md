# iOS Devbox Plugin

This plugin configures iOS development tools inside Devbox, automatically discovering Xcode and managing iOS simulators project-locally without touching global state.

Runtime scripts live in the virtenv (`.devbox/virtenv/ios/scripts`) and are added to PATH when the plugin activates.

Configuration is managed via environment variables in `plugin.json`. The plugin automatically discovers Xcode installations and caches the path for performance.

## Quickstart

```sh
# List device definitions
devbox run ios.sh devices list

# Start simulator
devbox run start:sim

# Build iOS app (define build:ios in devbox.json)
devbox run build:ios

# Build, install, and launch app on simulator
ios.sh run

# Stop simulator
devbox run stop:sim
```

## Device Definitions

Device definitions live in `devbox.d/ios/devices/*.json`. Each file includes:
- `name` (string, required) - iOS device type (e.g., "iPhone 17", "iPhone 13")
- `runtime` (string, required) - iOS version (e.g., "26.2", "15.4")

Default devices are `min.json` and `max.json`.

To see available device types and runtimes:
```sh
xcrun simctl list devicetypes    # Available device types
xcrun simctl list runtimes       # Available iOS runtimes
```

## Selecting Devices for Evaluation

The plugin evaluates all devices by default. To restrict to specific devices, set:
```json
{
  "env": {
    "IOS_DEVICES": "min,max"
  }
}
```

After changing device definitions, regenerate the lock file:
```sh
devbox run ios.sh devices eval
```

## Commands

### Simulator Commands
```sh
devbox run start:sim [device]    # Start iOS simulator (defaults to IOS_DEFAULT_DEVICE)
devbox run stop:sim              # Stop all running simulators
ios.sh run [app_path] [device]   # Build, install, and launch app on simulator
```

### Device Management
```sh
devbox run ios.sh devices list
devbox run ios.sh devices create iphone15 --runtime 17.5
devbox run ios.sh devices update iphone15 --runtime 18.0
devbox run ios.sh devices delete iphone15
devbox run ios.sh devices eval   # Generate devices.lock
devbox run ios.sh devices sync   # Ensure simulators match device definitions
```

### Build Commands
```sh
# Define build scripts in devbox.json using native xcodebuild:
#   "build:ios": ["ios.sh xcodebuild -scheme MyApp build"]
devbox run build:ios             # Build iOS app
ios.sh xcodebuild <args>         # Run xcodebuild with Nix flags stripped
devbox run test:e2e              # Run E2E tests with simulator
```

### Configuration
```sh
devbox run ios.sh config show    # Show current configuration
devbox run ios.sh info           # Show Xcode and SDK info
```

## Environment Variables

- `IOS_CONFIG_DIR` — project config directory (`devbox.d/ios`)
- `IOS_DEVICES_DIR` — device definitions directory
- `IOS_SCRIPTS_DIR` — runtime scripts directory (`.devbox/virtenv/ios/scripts`)
- `IOS_DEFAULT_DEVICE` — used when no device name is provided (default: `max`)
- `IOS_DEVICES` — comma-separated device names to evaluate (empty means all)
- `IOS_APP_ARTIFACT` — path or glob for .app bundle (empty = auto-detect via xcodebuild + search)
- `IOS_APP_SCHEME` — Xcode scheme override (empty = auto-detect from project name)
- `IOS_APP_PROJECT` — explicit .xcworkspace or .xcodeproj path (empty = auto-detect)
- `IOS_BUILD_CONFIG` — build configuration: Debug or Release (default: Debug)
- `IOS_DERIVED_DATA_PATH` — DerivedData directory (default: .devbox/virtenv/ios/DerivedData)
- `IOS_DEVELOPER_DIR` — path to Xcode developer directory (auto-detected if not set)
- `IOS_DOWNLOAD_RUNTIME` — auto-download missing iOS runtimes (0/1, default: 1)

## Pure Mode Testing

The plugin supports deterministic testing via `devbox run --pure`:

```sh
# Normal mode (developer workflow) - reuses existing simulators
devbox run test:e2e

# Pure mode (CI workflow) - creates fresh test simulator
devbox run --pure test:e2e
```

When running with `--pure`, the plugin:
- Creates test-specific simulators (with " Test" suffix)
- Isolates tests from existing simulators
- Cleans up test simulators after completion
- Ensures reproducible CI environment

The `DEVBOX_PURE_SHELL` environment variable is automatically set by devbox when using the `--pure` flag. Scripts auto-detect this to determine whether to create fresh, isolated simulators.

## Xcode Discovery

The plugin automatically discovers Xcode with multiple fallback strategies:

1. Check `IOS_DEVELOPER_DIR` environment variable
2. Check cache file (`.devbox/virtenv/ios/.xcode_dev_dir.cache`, 1-hour TTL)
3. Find latest Xcode in `/Applications/Xcode*.app` by version
4. Use `xcode-select -p` output
5. Fallback to `/Applications/Xcode.app/Contents/Developer`

The discovered path is cached for 1 hour to improve shell startup performance.

## Troubleshooting

### Xcode Not Found
```sh
# Check Xcode installation
xcode-select -p

# Set explicit path if needed
export IOS_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
devbox shell
```

### Simulator Runtime Missing
```sh
# List available runtimes
xcrun simctl list runtimes

# Enable auto-download in devbox.json
{
  "env": {
    "IOS_DOWNLOAD_RUNTIME": "1"
  }
}

# Or manually download via Xcode Settings > Platforms
```

### CoreSimulatorService Issues
```sh
# Restart the service
killall -9 CoreSimulatorService

# Check service status
launchctl list | grep CoreSimulator
```

### Build Failures with Nix Flags
The iOS init hook strips Nix compilation variables (`LD`, `LDFLAGS`, `NIX_LDFLAGS`, `NIX_CFLAGS_COMPILE`, `NIX_CFLAGS_LINK`) at shell startup, so `xcodebuild` works natively in devbox shell. If you encounter issues outside devbox shell, use the `ios.sh xcodebuild` wrapper:
```sh
ios.sh xcodebuild -project MyApp.xcodeproj -scheme MyApp build
```

## Reference

- **Complete API reference**: `plugins/ios/REFERENCE.md`
- **Architecture**: `wiki/project/ARCHITECTURE.md`
