# Android Cheatsheet

Quick reference for common Android plugin operations.

## Setup

```bash
# Add plugin to devbox.json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/android"],
  "env": {
    "ANDROID_DEFAULT_DEVICE": "max",
    "ANDROID_DEVICES": "min,max"
  }
}

# Enter shell
devbox shell
```

## Device Management

```bash
# List devices
devbox run android.sh devices list

# Create device
devbox run android.sh devices create pixel_api30 --api 30 --device pixel

# Update device
devbox run android.sh devices update pixel_api30 --api 31

# Delete device
devbox run android.sh devices delete pixel_api30

# Regenerate lock file
devbox run android.sh devices eval

# Sync AVDs to match definitions
devbox run android.sh devices sync
```

## Emulator Operations

```bash
# Start emulator (default device)
devbox run start:emu

# Start specific device
devbox run start:emu min

# Stop emulator
devbox run stop:emu
```

## Build and Deploy

Build and deploy scripts are project-specific. Define them in your `devbox.json`.

```bash
# Plugin-provided: run app on emulator (builds, installs, launches)
devbox run android.sh run
devbox run android.sh run pixel_api30

# User-defined scripts (add to your devbox.json shell.scripts):
# "build": ["gradle assembleDebug --info"]
# "start:app": ["android.sh run ${1:-}"]   # ${1:-} passes optional device arg
```

## Configuration

```bash
# Show current configuration
devbox run android.sh config show

# View SDK info
devbox run android.sh info
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
ANDROID_DEFAULT_DEVICE="max"           # Default device
ANDROID_DEVICES="min,max"              # Devices to evaluate (comma-separated)
ANDROID_APP_APK="app/build/outputs/apk/debug/app-debug.apk"  # APK path
ANDROID_COMPILE_SDK="36"               # Compile SDK version
ANDROID_TARGET_SDK="36"                # Target SDK version
ANDROID_LOCAL_SDK="0"                  # Use local SDK (1=yes, 0=no)
EMU_HEADLESS="0"                       # Run headless (1=yes, 0=no)
ANDROID_DISABLE_SNAPSHOTS="0"          # Disable snapshots (1=yes, 0=no)
ANDROID_SKIP_SETUP="0"             # Skip SDK downloads (1=yes, 0=no)
```

## Device Definition Format

```json
{
  "name": "pixel_api30",
  "api": 30,
  "device": "pixel",
  "tag": "google_apis",
  "preferred_abi": "x86_64"
}
```

## Troubleshooting

```bash
# Enable debug logging
ANDROID_DEBUG=1 devbox shell

# Check emulator is running
adb devices

# View emulator logs
adb logcat

# Kill stuck emulator
adb emu kill
```

## Testing

Test scripts are project-specific. Define them in your `devbox.json`.

```bash
# User-defined scripts (add to your devbox.json shell.scripts):
# "test": ["gradle test"]
# "test:e2e": ["process-compose -f tests/test-suite.yaml --no-server"]

# Run with headless emulator
EMU_HEADLESS=1 devbox run test:e2e
```

## Files and Directories

```
devbox.d/android/
└── devices/           # Device definitions
    ├── min.json
    ├── max.json
    └── devices.lock   # Generated lock file

.devbox/virtenv/android/  # Runtime directory (auto-regenerated, never edit)
├── scripts/              # Plugin scripts
└── flake.nix             # Nix SDK configuration (auto-generated)

reports/
├── logs/             # Test logs
└── results/          # Test results
```

## See Also

- [Android Guide](../android-guide.md) - Complete Android workflow
- [Android Reference](../../reference/android.md) - Full API documentation
- [Device Management](../device-management.md) - Multi-device workflows
