# iOS Cheatsheet

Quick reference for common iOS plugin operations.

## Setup

```bash
# Add plugin to devbox.json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/ios"],
  "env": {
    "IOS_DEFAULT_DEVICE": "max",
    "IOS_DEVICES": "min,max"
  }
}

# Enter shell
devbox shell
```

## Device Management

```bash
# List devices
devbox run ios.sh devices list

# Create device
devbox run ios.sh devices create iphone15 --runtime 17.5

# Update device
devbox run ios.sh devices update iphone15 --runtime 18.0

# Delete device
devbox run ios.sh devices delete iphone15

# Regenerate lock file
devbox run ios.sh devices eval

# Sync simulators to match definitions
devbox run ios.sh devices sync
```

## Simulator Operations

```bash
# Start simulator (default device)
devbox run start:sim

# Start specific device
devbox run start:sim min

# Stop simulator
devbox run stop:sim
```

## Build and Deploy

```bash
# Build (auto-detects project)
ios.sh build

# Build Release
ios.sh build --config Release

# Run xcodebuild tests
ios.sh build --action test

# Run app (starts simulator, builds, installs, launches)
ios.sh run

# Run on specific device
ios.sh run max

# Run pre-built app
ios.sh run /path/to/MyApp.app
```

Build scripts in `devbox.json`:

```bash
# "build": ["ios.sh build"]
# "build:release": ["ios.sh build --config Release"]
# "test": ["ios.sh build --action test"]
# "start:app": ["ios.sh run ${1:-}"]
```

## Configuration

```bash
# Show current configuration
devbox run ios.sh config show

# View SDK info
devbox run ios.sh info
```

## Diagnostics

```bash
# Run health check
devbox run doctor

# Quick verification
devbox run verify:setup
```

## Common Environment Variables

```bash
IOS_DEFAULT_DEVICE="max"              # Default device
IOS_DEVICES="min,max"                 # Devices to evaluate (comma-separated)
IOS_DEFAULT_RUNTIME=""                # Default runtime (empty = latest)
IOS_DEVELOPER_DIR=""                  # Xcode path (empty = auto-detect)
IOS_DOWNLOAD_RUNTIME="1"              # Auto-download runtimes (1=yes, 0=no)
IOS_SKIP_SETUP="0"                    # Skip setup during init (1=yes, 0=no)
IOS_APP_ARTIFACT=""                   # .app path/glob (empty = auto-detect)
IOS_APP_SCHEME=""                     # Xcode scheme (empty = auto-detect)
IOS_BUILD_CONFIG="Debug"              # Build configuration (Debug/Release)
IOS_DERIVED_DATA_PATH=""              # DerivedData path (default: .devbox/virtenv/ios/DerivedData)
```

## Device Definition Format

```json
{
  "name": "iPhone 15 Pro",
  "runtime": "17.5"
}
```

## Troubleshooting

```bash
# Enable debug logging
IOS_DEBUG=1 devbox shell

# List available runtimes
xcrun simctl list runtimes

# List all simulators
xcrun simctl list devices

# Check Xcode path
xcode-select -p

# Switch Xcode version
sudo xcode-select --switch /Applications/Xcode-15.4.app/Contents/Developer

# Restart CoreSimulator
killall -9 com.apple.CoreSimulatorService
launchctl kickstart -k gui/$UID/com.apple.CoreSimulatorService
```

## Testing

Test scripts are project-specific. Define them in your `devbox.json`.

```bash
# User-defined scripts (add to your devbox.json shell.scripts):
# "test": ["xcodebuild ... test"]
# "test:e2e": ["process-compose -f tests/test-suite.yaml --no-server"]
```

## Files and Directories

```
devbox.d/ios/
└── devices/           # Device definitions
    ├── min.json
    ├── max.json
    └── devices.lock   # Generated lock file

.devbox/virtenv/ios/   # Runtime directory (auto-regenerated, never edit)
├── scripts/           # Plugin scripts
└── DerivedData/       # Build output (if configured)

reports/
├── logs/             # Test logs
└── results/          # Test results
```

## Common Xcode Commands

```bash
# Build project (preferred)
ios.sh build

# Build project (direct xcodebuild - works natively, Nix vars stripped at init)
xcodebuild -project ios.xcodeproj -scheme ios -configuration Debug \
  -destination 'generic/platform=iOS Simulator' build

# Install app to simulator
xcrun simctl install booted path/to/app.app

# Launch app on simulator
xcrun simctl launch booted com.example.ios

# Download iOS runtime
xcodebuild -downloadPlatform iOS

# Clean build
xcodebuild clean -project ios.xcodeproj -scheme ios
```

## See Also

- [iOS Guide](../ios-guide.md) - Complete iOS workflow
- [iOS Reference](../../reference/ios.md) - Full API documentation
- [Device Management](../device-management.md) - Multi-device workflows
