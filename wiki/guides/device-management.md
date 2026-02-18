# Device Management Guide

This guide covers how to manage virtual devices (Android emulators and iOS simulators) across all platforms in the Devbox mobile development plugins.

## Overview

Device management in Devbox plugins follows a declarative approach. You define devices in JSON files, and the plugins handle creating, updating, and managing the actual virtual devices.

**Key concepts:**

- **Device definitions** - JSON files describing device configurations
- **Lock files** - Generated files tracking which devices to evaluate/create
- **Device filtering** - Control which devices are used for testing or CI
- **Min/max convention** - Standard naming for minimum and maximum platform versions

## Device Definitions

### Android Device Definitions

Android device definitions specify AVD (Android Virtual Device) configurations. Each file in `devbox.d/android/devices/*.json` defines one device.

**Schema:**
```json
{
  "name": "pixel_api30",
  "api": 30,
  "device": "pixel",
  "tag": "google_apis",
  "preferred_abi": "x86_64"
}
```

**Fields:**
- `name` (required) - Device identifier, used in commands
- `api` (required) - Android API level (21-36)
- `device` (required) - AVD device profile (pixel, medium_phone, tablet, etc.)
- `tag` (optional) - System image tag
  - `google_apis` - Google APIs (recommended)
  - `google_apis_playstore` - Google APIs + Play Store
  - `play_store` - AOSP + Play Store
  - `aosp_atd` - AOSP Automated Test Device
  - `google_atd` - Google ATD (fastest boot, minimal apps)
- `preferred_abi` (optional) - CPU architecture
  - `x86_64` - Intel 64-bit (fastest on x86 hosts)
  - `arm64-v8a` - ARM 64-bit (required for Apple Silicon Macs)
  - `x86` - Intel 32-bit (legacy)

**Common profiles:**
- `pixel` - Pixel phone (5.0", 1080x1920, 420dpi)
- `pixel_xl` - Pixel XL (5.5", 1440x2560, 560dpi)
- `pixel_3a` - Pixel 3a (5.6", 1080x2220, 440dpi)
- `medium_phone` - Generic medium phone (6.3", 1080x2400, 420dpi)
- `tablet` - Generic tablet (10.1", 1920x1200, 240dpi)

**Example: minimum supported device**
```json
{
  "name": "pixel_api21",
  "api": 21,
  "device": "pixel",
  "tag": "google_apis"
}
```

**Example: maximum/latest device**
```json
{
  "name": "medium_phone_api36",
  "api": 36,
  "device": "medium_phone",
  "tag": "google_apis"
}
```

### iOS Device Definitions

iOS device definitions specify simulator configurations. Each file in `devbox.d/ios/devices/*.json` defines one simulator.

**Schema:**
```json
{
  "name": "iPhone 15 Pro",
  "runtime": "17.5"
}
```

**Fields:**
- `name` (required) - iOS device type (e.g., "iPhone 15", "iPad Pro")
- `runtime` (required) - iOS version (e.g., "17.5", "18.0", "15.4")

**Common device names:**
- `iPhone 13`, `iPhone 14`, `iPhone 15`, `iPhone 16`, `iPhone 17`
- `iPhone 13 Pro`, `iPhone 14 Pro`, `iPhone 15 Pro`
- `iPhone SE (3rd generation)`
- `iPad Pro (11-inch)`, `iPad Pro (12.9-inch)`
- `iPad Air`, `iPad mini`

**Example: minimum supported device**
```json
{
  "name": "iPhone 13",
  "runtime": "15.4"
}
```

**Example: maximum/latest device**
```json
{
  "name": "iPhone 17",
  "runtime": "26.2"
}
```

To see all available device types and runtimes on your system:
```bash
xcrun simctl list devicetypes
xcrun simctl list runtimes
```

### Min/Max Convention

Use `min.json` and `max.json` as standard device names for testing minimum and maximum platform versions.

**Benefits:**
- Clear semantic meaning for version boundaries
- Easy to reference in CI configuration
- Standardized across projects

**Example directory structure:**
```
devbox.d/android/devices/
├── min.json          # API 21 - minimum supported
├── max.json          # API 36 - latest available
└── pixel_api28.json  # Custom device for specific testing

devbox.d/ios/devices/
├── min.json          # iOS 15.4 - minimum supported
├── max.json          # iOS 26.2 - latest available
└── ipad_pro.json     # Custom device for tablet testing
```

**CI usage:**
```json
{
  "env": {
    "ANDROID_DEVICES": "min,max",
    "IOS_DEVICES": "min,max",
    "ANDROID_DEFAULT_DEVICE": "max",
    "IOS_DEFAULT_DEVICE": "max"
  }
}
```

## Managing Android Devices

### Listing Devices

View all device definitions:
```bash
devbox run android.sh devices list
```

Output shows:
- Device name
- API level
- Device profile
- System image tag
- Preferred ABI (if specified)

### Creating Devices

Create a new device definition:
```bash
devbox run android.sh devices create <name> --api <level> --device <profile> [options]
```

**Examples:**

Basic device:
```bash
devbox run android.sh devices create pixel_api30 \
  --api 30 \
  --device pixel \
  --tag google_apis
```

With specific ABI:
```bash
devbox run android.sh devices create tablet_api35 \
  --api 35 \
  --device tablet \
  --tag google_apis_playstore \
  --abi x86_64
```

High-performance testing device:
```bash
devbox run android.sh devices create test_api34 \
  --api 34 \
  --device medium_phone \
  --tag google_atd \
  --abi x86_64
```

### Updating Devices

Modify existing device definitions:
```bash
devbox run android.sh devices update <name> [options]
```

**Examples:**

Change API level:
```bash
devbox run android.sh devices update pixel_api30 --api 31
```

Change device profile:
```bash
devbox run android.sh devices update pixel_api30 --device pixel_xl
```

Rename device:
```bash
devbox run android.sh devices update pixel_api30 --name pixel_api31
```

Multiple changes:
```bash
devbox run android.sh devices update old_device \
  --name new_device \
  --api 35 \
  --device medium_phone \
  --tag google_apis
```

### Deleting Devices

Remove a device definition:
```bash
devbox run android.sh devices delete <name>
```

Example:
```bash
devbox run android.sh devices delete pixel_api30
```

### Showing Device Details

View a specific device configuration:
```bash
devbox run android.sh devices show <name>
```

Example:
```bash
devbox run android.sh devices show max
```

## Managing iOS Devices

### Listing Devices

View all device definitions:
```bash
devbox run ios.sh devices list
```

Output shows:
- Device name
- iOS runtime version

### Creating Devices

Create a new device definition:
```bash
devbox run ios.sh devices create <name> --runtime <version>
```

**Examples:**

iPhone device:
```bash
devbox run ios.sh devices create iphone15 --runtime 17.5
```

iPad device:
```bash
devbox run ios.sh devices create ipad_pro --runtime 18.0
```

Older device for compatibility testing:
```bash
devbox run ios.sh devices create iphone13 --runtime 15.4
```

### Updating Devices

Modify existing device definitions:
```bash
devbox run ios.sh devices update <name> [options]
```

**Examples:**

Change runtime version:
```bash
devbox run ios.sh devices update iphone15 --runtime 18.0
```

Rename device:
```bash
devbox run ios.sh devices update iphone15 --name iphone15_pro
```

Both changes:
```bash
devbox run ios.sh devices update iphone15 \
  --name iphone16 \
  --runtime 18.0
```

### Deleting Devices

Remove a device definition:
```bash
devbox run ios.sh devices delete <name>
```

Example:
```bash
devbox run ios.sh devices delete iphone15
```

### Showing Device Details

View a specific device configuration:
```bash
devbox run ios.sh devices show <name>
```

Example:
```bash
devbox run ios.sh devices show max
```

### Syncing Simulators

Ensure actual simulators match device definitions:
```bash
devbox run ios.sh devices sync
```

This command:
- Reads the lock file
- Creates missing simulators
- Recreates simulators with mismatched configurations
- Reports matched, recreated, created, and skipped simulators

## Lock Files and SDK Optimization

Lock files optimize CI builds by limiting which SDK versions and system images are evaluated.

### Why Lock Files Matter

Without lock files:
- Nix evaluates all possible device configurations
- Downloads system images for all API levels
- Slow CI builds (can add 10+ minutes)

With lock files:
- Only evaluates specified devices
- Downloads only required system images
- Fast CI builds (evaluates in seconds)

### Android Lock File

**Location:** `devbox.d/android/devices/devices.lock`

**Format:**
```json
{
  "devices": [
    {
      "name": "medium_phone_api36",
      "api": 36,
      "device": "medium_phone",
      "tag": "google_apis"
    },
    {
      "name": "pixel_api21",
      "api": 21,
      "device": "pixel",
      "tag": "google_apis"
    }
  ],
  "checksum": "2f3ab0e3cefd3e9909185c0717dc9d63038da1e81625eb6fce585e3af446bfef",
  "generated_at": "2026-02-12T06:54:22Z"
}
```

**Fields:**
- `devices` - Array of device configurations to evaluate
- `checksum` - SHA-256 hash of all device definition files
- `generated_at` - ISO 8601 timestamp

### iOS Lock File

**Location:** `devbox.d/ios/devices/devices.lock`

**Format:**
```json
{
  "devices": [
    {
      "name": "iPhone 17",
      "runtime": "26.2"
    },
    {
      "name": "iPhone 13",
      "runtime": "15.4"
    }
  ],
  "checksum": "dd575d31a5adf2f471655389df301215f6ef7130ca284d433929b08b68e42890",
  "generated_at": "2026-02-12T06:55:59Z"
}
```

### Generating Lock Files

Always regenerate lock files after creating, updating, or deleting devices.

**Android:**
```bash
devbox run android.sh devices eval
```

**iOS:**
```bash
devbox run ios.sh devices eval
```

Lock files should be committed to version control.

### Lock File Validation

The plugins automatically validate lock file checksums against device definitions.

**If checksums mismatch:**
```
[WARN] Lock file checksum mismatch
       Expected: abc123...
       Got:      def456...
       Run: devbox run android.sh devices eval
```

This is a warning, not an error. Execution continues, but you should regenerate the lock file.

## Device Filtering

Control which devices are evaluated using environment variables.

### Android Device Filtering

**Evaluate all devices (default):**
```json
{
  "env": {
    "ANDROID_DEVICES": ""
  }
}
```

**Evaluate specific devices:**
```json
{
  "env": {
    "ANDROID_DEVICES": "min,max"
  }
}
```

**Evaluate single device:**
```json
{
  "env": {
    "ANDROID_DEVICES": "max"
  }
}
```

### iOS Device Filtering

**Evaluate all devices (default):**
```json
{
  "env": {
    "IOS_DEVICES": ""
  }
}
```

**Evaluate specific devices:**
```json
{
  "env": {
    "IOS_DEVICES": "min,max"
  }
}
```

**Evaluate single device:**
```json
{
  "env": {
    "IOS_DEVICES": "max"
  }
}
```

### When to Use Filtering

**Development (evaluate all):**
```json
{
  "env": {
    "ANDROID_DEVICES": "",
    "IOS_DEVICES": ""
  }
}
```

**CI (min/max only):**
```json
{
  "env": {
    "ANDROID_DEVICES": "min,max",
    "IOS_DEVICES": "min,max"
  }
}
```

**Feature testing (specific device):**
```json
{
  "env": {
    "ANDROID_DEVICES": "tablet_api35",
    "IOS_DEVICES": "ipad_pro"
  }
}
```

After changing device filtering, regenerate lock files:
```bash
devbox run android.sh devices eval
devbox run ios.sh devices eval
```

## Multi-Device Testing Patterns

### Testing Across Min/Max Versions

Test compatibility on minimum and maximum supported versions.

**Setup:**
```json
{
  "env": {
    "ANDROID_DEVICES": "min,max",
    "IOS_DEVICES": "min,max"
  }
}
```

**Android test script:**
```bash
#!/bin/bash
set -euo pipefail

for device in min max; do
  echo "Testing on $device"
  devbox run android.sh emulator start "$device"
  devbox run test:android
  devbox run android.sh emulator stop
done
```

**iOS test script:**
```bash
#!/bin/bash
set -euo pipefail

for device in min max; do
  echo "Testing on $device"
  devbox run ios.sh simulator start "$device"
  devbox run test:ios
  devbox run ios.sh simulator stop
done
```

### Parallel Testing with Process-Compose

Run tests on multiple devices simultaneously using process-compose.

**process-compose.yaml:**
```yaml
version: "0.5"

processes:
  test-android-min:
    command: |
      devbox run android.sh emulator start min
      devbox run test:android
    depends_on:
      setup:
        condition: process_completed

  test-android-max:
    command: |
      devbox run android.sh emulator start max
      devbox run test:android
    depends_on:
      setup:
        condition: process_completed

  test-ios-min:
    command: |
      devbox run ios.sh simulator start min
      devbox run test:ios
    depends_on:
      setup:
        condition: process_completed

  test-ios-max:
    command: |
      devbox run ios.sh simulator start max
      devbox run test:ios
    depends_on:
      setup:
        condition: process_completed

  cleanup:
    command: |
      devbox run android.sh emulator stop
      devbox run ios.sh simulator stop
    depends_on:
      test-android-min:
        condition: process_completed
      test-android-max:
        condition: process_completed
      test-ios-min:
        condition: process_completed
      test-ios-max:
        condition: process_completed
```

**Run parallel tests:**
```bash
devbox run process-compose up
```

### Per-Test Device Selection

Override device selection for individual test runs.

**Android:**
```bash
# Use default device
devbox run test:android

# Override for specific device
ANDROID_DEVICE_NAME=pixel_api28 devbox run test:android

# Legacy override variable
TARGET_DEVICE=pixel_api28 devbox run test:android
```

**iOS:**
```bash
# Use default device
devbox run test:ios

# Override for specific device (via command argument)
devbox run test:ios iphone15

# Or set device in test suite configuration
```

### Matrix Testing

Test all combinations of devices and configurations.

**Matrix configuration:**
```bash
#!/bin/bash
set -euo pipefail

ANDROID_DEVICES=("min" "max" "tablet_api35")
IOS_DEVICES=("min" "max" "ipad_pro")
CONFIGS=("debug" "release")

for device in "${ANDROID_DEVICES[@]}"; do
  for config in "${CONFIGS[@]}"; do
    echo "Testing Android $device with $config"
    devbox run android.sh emulator start "$device"
    devbox run test:android:$config
    devbox run android.sh emulator stop
  done
done

for device in "${IOS_DEVICES[@]}"; do
  for config in "${CONFIGS[@]}"; do
    echo "Testing iOS $device with $config"
    devbox run ios.sh simulator start "$device"
    devbox run test:ios:$config
    devbox run ios.sh simulator stop
  done
done
```

## Device Selection Strategies

### Default Device Selection

Specify a default device used when no device is explicitly provided.

**Android:**
```json
{
  "env": {
    "ANDROID_DEFAULT_DEVICE": "max"
  }
}
```

**iOS:**
```json
{
  "env": {
    "IOS_DEFAULT_DEVICE": "max"
  }
}
```

**Usage:**
```bash
# Uses default device
devbox run start
devbox run start:ios

# Override with specific device
devbox run start min
devbox run start:ios min
```

### CI Device Selection

For CI environments, use min/max filtering for fast, comprehensive testing.

**devbox.json:**
```json
{
  "env": {
    "ANDROID_DEVICES": "min,max",
    "IOS_DEVICES": "min,max",
    "ANDROID_DEFAULT_DEVICE": "max",
    "IOS_DEFAULT_DEVICE": "max"
  }
}
```

**.github/workflows/ci.yml:**
```yaml
jobs:
  test-android:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        device: [min, max]
    steps:
      - uses: actions/checkout@v3
      - run: devbox install
      - run: devbox run android.sh emulator start ${{ matrix.device }}
      - run: devbox run test:android
      - run: devbox run android.sh emulator stop

  test-ios:
    runs-on: macos-latest
    strategy:
      matrix:
        device: [min, max]
    steps:
      - uses: actions/checkout@v3
      - run: devbox install
      - run: devbox run ios.sh simulator start ${{ matrix.device }}
      - run: devbox run test:ios
      - run: devbox run ios.sh simulator stop
```

### Development Device Selection

For development, use all devices or latest device for faster iteration.

**All devices (comprehensive testing):**
```json
{
  "env": {
    "ANDROID_DEVICES": "",
    "IOS_DEVICES": "",
    "ANDROID_DEFAULT_DEVICE": "max",
    "IOS_DEFAULT_DEVICE": "max"
  }
}
```

**Latest device only (fast iteration):**
```json
{
  "env": {
    "ANDROID_DEVICES": "max",
    "IOS_DEVICES": "max",
    "ANDROID_DEFAULT_DEVICE": "max",
    "IOS_DEFAULT_DEVICE": "max"
  }
}
```

### Feature-Specific Device Selection

For feature development targeting specific devices or form factors.

**Tablet testing:**
```json
{
  "env": {
    "ANDROID_DEVICES": "tablet_api35",
    "IOS_DEVICES": "ipad_pro",
    "ANDROID_DEFAULT_DEVICE": "tablet_api35",
    "IOS_DEFAULT_DEVICE": "ipad_pro"
  }
}
```

**Older device compatibility:**
```json
{
  "env": {
    "ANDROID_DEVICES": "min",
    "IOS_DEVICES": "min",
    "ANDROID_DEFAULT_DEVICE": "min",
    "IOS_DEFAULT_DEVICE": "min"
  }
}
```

## Best Practices

### Naming Conventions

Use clear, descriptive names for devices.

**Good names:**
- `min.json`, `max.json` - Semantic version boundaries
- `pixel_api30.json` - Descriptive with API level
- `iphone15_pro.json` - Specific device model
- `tablet_api35.json` - Form factor and API level

**Avoid:**
- `device1.json`, `device2.json` - No context
- `test.json`, `temp.json` - Unclear purpose
- `d30.json`, `i15.json` - Cryptic abbreviations

### Version Control

Commit device definitions and lock files.

**What to commit:**
- `devbox.d/*/devices/*.json` - Device definitions
- `devbox.d/*/devices/devices.lock` - Lock files

**What to ignore:**
- `.devbox/virtenv/` - Generated runtime files
- `reports/` - Test outputs
- `DerivedData/` - Build artifacts

**.gitignore:**
```
.devbox/virtenv/
reports/
DerivedData/
*.log
```

### Lock File Workflow

Regenerate lock files after any device changes.

**Workflow:**
1. Modify device definitions (create/update/delete)
2. Regenerate lock file: `devbox run {platform}.sh devices eval`
3. Commit both device definitions and lock files
4. CI uses lock files for fast, deterministic builds

**Example:**
```bash
# Create new device
devbox run android.sh devices create pixel_api35 \
  --api 35 \
  --device pixel \
  --tag google_apis

# Regenerate lock file
devbox run android.sh devices eval

# Commit both
git add devbox.d/android/devices/
git commit -m "feat(android): add pixel_api35 device"
```

### Device Lifecycle Management

Keep device definitions aligned with project requirements.

**Regular maintenance:**
- Update max devices when new OS versions release
- Remove obsolete device configurations
- Keep min devices aligned with minimum supported versions
- Test min/max periodically to catch compatibility issues

**Example: updating to new Android API:**
```bash
# Update max device
devbox run android.sh devices update max --api 36

# Regenerate lock
devbox run android.sh devices eval

# Test compatibility
devbox run test:android max
```

### Performance Optimization

**For CI:**
- Use `min,max` device filtering
- Commit lock files (avoid regenerating on every build)
- Use `google_atd` tag for faster Android emulator boots
- Enable `IOS_DOWNLOAD_RUNTIME=0` if runtimes are pre-installed

**For development:**
- Evaluate only devices you're actively testing
- Use default device for quick iterations
- Evaluate all devices before committing

**Example CI optimization:**
```json
{
  "env": {
    "ANDROID_DEVICES": "min,max",
    "IOS_DEVICES": "min,max",
    "ANDROID_DEFAULT_DEVICE": "max",
    "IOS_DEFAULT_DEVICE": "max",
    "IOS_DOWNLOAD_RUNTIME": "0"
  }
}
```

### Error Handling

Device commands include validation warnings but never block execution.

**Lock file mismatch (warning):**
```
[WARN] Lock file checksum mismatch
       Run: devbox run android.sh devices eval
```
Execution continues. Regenerate lock file when convenient.

**Missing device definition (error):**
```
[ERROR] Device 'pixel_api30' not found in devbox.d/android/devices/
        Available devices: min, max
```
Execution stops. Create device or use an available device name.

**Missing runtime (warning):**
```
[WARN] Runtime iOS 17.5 not available
       Run: xcodebuild -downloadPlatform iOS
       Or set IOS_DOWNLOAD_RUNTIME=1 for automatic downloads
```
Execution continues if auto-download is enabled. Otherwise, manually download runtime.

### Multi-Platform Projects

For React Native or hybrid apps, manage both Android and iOS devices.

**Setup:**
```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/react-native"],
  "env": {
    "ANDROID_DEVICES": "min,max",
    "IOS_DEVICES": "min,max",
    "ANDROID_DEFAULT_DEVICE": "max",
    "IOS_DEFAULT_DEVICE": "max"
  }
}
```

**Directory structure:**
```
devbox.d/
├── android/
│   └── devices/
│       ├── min.json
│       ├── max.json
│       └── devices.lock
└── ios/
    └── devices/
        ├── min.json
        ├── max.json
        └── devices.lock
```

**Testing workflow:**
```bash
# Android testing
devbox run android.sh devices list
devbox run android.sh devices eval
devbox run start min
devbox run start max

# iOS testing
devbox run ios.sh devices list
devbox run ios.sh devices eval
devbox run start:ios min
devbox run start:ios max
```

## Troubleshooting

### Device Definition Not Found

**Symptom:** "Device 'device-name' not found"

**Solution:**
```bash
# List available devices
devbox run {platform}.sh devices list

# Check file exists
ls devbox.d/{platform}/devices/

# Ensure filename matches (case-sensitive)
# device-name.json should match exactly
```

### Lock File Out of Sync

**Symptom:** "Lock file checksum mismatch" warning

**Solution:**
```bash
# Regenerate lock file
devbox run android.sh devices eval
devbox run ios.sh devices eval

# Commit updated lock file
git add devbox.d/*/devices/devices.lock
git commit -m "chore: update device lock files"
```

### Android System Image Not Found

**Symptom:** "System image not available for API X"

**Solution:**
```bash
# Check available system images
sdkmanager --list

# Verify tag is valid for API level
# Some tags (like google_apis_playstore) are not available for all API levels

# Update device to use compatible tag
devbox run android.sh devices update device-name --tag google_apis
devbox run android.sh devices eval
```

### iOS Runtime Not Available

**Symptom:** "Runtime iOS X.X not found"

**Solution:**
```bash
# List available runtimes
xcrun simctl list runtimes

# Download runtime manually
xcodebuild -downloadPlatform iOS

# Or enable auto-download
# In devbox.json:
{
  "env": {
    "IOS_DOWNLOAD_RUNTIME": "1"
  }
}
```

### Simulator Already Exists

**Symptom:** iOS simulator creation fails with "already exists"

**Solution:**
```bash
# Sync simulators to match definitions
devbox run ios.sh devices sync

# Or manually delete duplicate simulator
xcrun simctl delete <udid>

# Then recreate from definition
devbox run ios.sh devices sync
```

### Device Filtering Not Applied

**Symptom:** Lock file includes devices not in filter list

**Solution:**
```bash
# Verify environment variable is set
devbox run {platform}.sh config show

# Set in devbox.json, not shell environment
{
  "env": {
    "ANDROID_DEVICES": "min,max",
    "IOS_DEVICES": "min,max"
  }
}

# Regenerate lock file after changing filter
devbox run android.sh devices eval
devbox run ios.sh devices eval
```

## Next Steps

- [Android Guide](android-guide.md) - Platform-specific Android development
- [iOS Guide](ios-guide.md) - Platform-specific iOS development
- [React Native Guide](react-native-guide.md) - Cross-platform React Native development
- [Testing Guide](testing.md) - Comprehensive testing strategies
- [Troubleshooting Guide](troubleshooting.md) - Common issues and solutions
- [Android Reference](../reference/android.md) - Complete Android API reference
- [iOS Reference](../reference/ios.md) - Complete iOS API reference
