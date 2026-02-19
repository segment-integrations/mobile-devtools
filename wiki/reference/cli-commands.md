# CLI Commands Reference

Comprehensive reference for all CLI commands across Android, iOS, and React Native plugins.

## Command Syntax

All commands follow the pattern:
```bash
devbox run [--pure] <command> [arguments]
```

The `--pure` flag runs commands in an isolated environment without environment variable inheritance.

## Android Plugin Commands

### Main CLI: android.sh

The main Android CLI provides device and emulator management.

#### Build

**Build project:**
```bash
android.sh build [--config Debug|Release] [--task gradle_task] [--quiet] [-- extra_args...]
```
- Auto-detects Gradle project (`build.gradle`, `build.gradle.kts`, or `settings.gradle`)
- Default: runs `assembleDebug` (or `assembleRelease` with `--config Release`)
- Uses `gradlew` if present, otherwise system `gradle`

**Examples:**
```bash
# Build with defaults
android.sh build

# Build Release
android.sh build --config Release

# Custom task with extra flags
android.sh build --task bundleRelease -- --info
```

#### Emulator Management

**Start emulator:**
```bash
devbox run --pure android.sh emulator start [--pure] [device]
```
- `--pure`: Start fresh emulator with wiped data (clean Android OS state)
- `device`: Device name (optional, defaults to `ANDROID_DEFAULT_DEVICE`)
- Without `--pure`: Reuses existing emulator if running (faster, preserves data)
- With `--pure`: Always starts new instance with `-wipe-data` flag

**Examples:**
```bash
# Start default device, reuse if running
devbox run --pure android.sh emulator start

# Start specific device with fresh state
devbox run --pure android.sh emulator start --pure pixel_api30

# Start max device
devbox run --pure android.sh emulator start max
```

**Stop emulator:**
```bash
devbox run --pure android.sh emulator stop
```
- Stops all running emulators

**Reset emulator:**
```bash
devbox run --pure android.sh emulator reset [device]
```
- Wipes emulator data for specified device
- If no device specified, uses `ANDROID_DEFAULT_DEVICE`

**Convenience aliases:**
```bash
# Start emulator (without --pure flag)
devbox run --pure start:emu [device]

# Stop emulator
devbox run --pure stop:emu
```

#### Device Management

**List devices:**
```bash
devbox run --pure android.sh devices list
```
- Shows all device definitions in `devbox.d/android/devices/`
- Displays: name, API level, device profile, tag, ABI

**Show specific device:**
```bash
devbox run --pure android.sh devices show <name>
```
- Displays JSON configuration for specified device
- Example: `android.sh devices show pixel_api30`

**Create device:**
```bash
devbox run --pure android.sh devices create <name> --api <n> --device <id> [--tag <tag>] [--abi <abi>]
```
- `name`: Device name (used as filename)
- `--api`: Android API level (required, e.g., 30, 33, 36)
- `--device`: AVD device profile (required, e.g., pixel, pixel_7, tablet)
- `--tag`: System image tag (optional, e.g., google_apis, google_apis_playstore, aosp_atd)
- `--abi`: Preferred ABI (optional, e.g., x86_64, arm64-v8a, x86)

**Examples:**
```bash
# Create Pixel device with API 30
devbox run --pure android.sh devices create pixel_api30 \
  --api 30 \
  --device pixel \
  --tag google_apis \
  --abi x86_64

# Create tablet device
devbox run --pure android.sh devices create tablet_api33 \
  --api 33 \
  --device tablet \
  --tag google_apis_playstore
```

**Update device:**
```bash
devbox run --pure android.sh devices update <name> [--name <new>] [--api <n>] [--device <id>] [--tag <tag>] [--abi <abi>]
```
- All flags are optional
- `--name`: Rename device
- Other flags update respective properties

**Examples:**
```bash
# Update API level
devbox run --pure android.sh devices update pixel_api30 --api 31

# Rename and update
devbox run --pure android.sh devices update pixel_api30 \
  --name pixel_api31 \
  --api 31
```

**Delete device:**
```bash
devbox run --pure android.sh devices delete <name>
```
- Removes device definition file
- Example: `android.sh devices delete pixel_api30`

**Select devices for evaluation:**
```bash
devbox run --pure android.sh devices select <name...>
```
- Sets which devices to evaluate in Nix flake
- Multiple device names space-separated
- Example: `android.sh devices select min max`

**Reset device selection:**
```bash
devbox run --pure android.sh devices reset
```
- Resets to evaluate all devices

**Generate lock file:**
```bash
devbox run --pure android.sh devices eval
```
- Generates `devices.lock` from device definitions
- Respects `ANDROID_DEVICES` filter (empty = all devices)
- Run after creating/updating/deleting devices
- Optimizes CI by limiting SDK versions evaluated

**Related:** `devbox run android:devices:eval` (convenience script)

**Sync AVDs:**
```bash
devbox run --pure android.sh devices sync
```
- Creates/updates AVDs to match device definitions
- Reads from `devices.lock`
- Reports: matched, recreated, created, skipped

#### Configuration Management

**Show configuration:**
```bash
devbox run --pure android.sh config show
```
- Displays current environment variable configuration

**Set configuration:**
```bash
devbox run --pure android.sh config set KEY=VALUE [KEY=VALUE...]
```
- Updates configuration values
- Multiple key-value pairs supported
- Example: `android.sh config set ANDROID_DEFAULT_DEVICE=pixel_api30`

**Reset configuration:**
```bash
devbox run --pure android.sh config reset
```
- Resets configuration to defaults

#### Application Deployment

**Run app (plugin-provided):**
```bash
devbox run --pure android.sh run [apk_path] [device]
```
- Installs and launches app on emulator
- `apk_path`: Path to APK (optional, uses `ANDROID_APP_APK` glob if not provided)
- `device`: Device name (optional, defaults to `ANDROID_DEFAULT_DEVICE`)

**Examples:**
```bash
# Install and run APK matched by ANDROID_APP_APK on default device
devbox run --pure android.sh run

# Install specific APK on default device
devbox run --pure android.sh run app/build/outputs/apk/debug/app-debug.apk

# Install APK on specific device
devbox run --pure android.sh run app/build/outputs/apk/debug/app-debug.apk pixel_api30
```

**Note:** `start:app` is not a plugin command. If your project defines a `start:app` script in `devbox.json`, it is a user-defined convenience script that may wrap `android.sh run` with additional build steps.

#### Diagnostics

**Environment check:**
```bash
devbox run doctor
```
- Checks Android SDK configuration
- Verifies tools in PATH (adb, emulator, avdmanager)
- Shows device definitions and lock file status
- Displays environment variables

**Verify setup:**
```bash
devbox run verify:setup
```
- Quick check that Android environment is functional
- Exits 1 on failure, 0 on success
- Checks: ANDROID_SDK_ROOT, directory exists, adb available

## iOS Plugin Commands

### Main CLI: ios.sh

The main iOS CLI provides device and simulator management.

#### Build

**Build project:**
```bash
ios.sh build [--config Debug|Release] [--scheme name] [--workspace path]
             [--project path] [--derived-data path] [--quiet] [--action build|test]
             [-- extra_xcodebuild_args...]
```
- Auto-detects Xcode project (`.xcworkspace` preferred over `.xcodeproj`)
- Default action: `build`. Use `--action test` for xcodebuild tests.
- Nix compilation vars are stripped at init time, so `xcodebuild` works natively.

**Examples:**
```bash
# Build with defaults (Debug, auto-detect)
ios.sh build

# Build Release
ios.sh build --config Release

# Run tests
ios.sh build --action test

# Quiet mode with explicit workspace
ios.sh build --workspace ios/MyApp.xcworkspace --scheme MyApp --quiet
```

#### Simulator Management

**Start simulator:**
```bash
devbox run --pure start:sim [device]
```
- `device`: Device name (optional, defaults to `IOS_DEFAULT_DEVICE`)
- Boots simulator if not already running
- Example: `devbox run --pure start:sim iphone15`

**Stop simulator:**
```bash
devbox run --pure stop:sim
```
- Shuts down all running simulators

#### Device Management

**List devices:**
```bash
devbox run --pure ios.sh devices list
```
- Shows all device definitions in `devbox.d/ios/devices/`
- Displays: name, iOS runtime version

**Show specific device:**
```bash
devbox run --pure ios.sh devices show <name>
```
- Displays JSON configuration for specified device
- Example: `ios.sh devices show iphone15`

**Create device:**
```bash
devbox run --pure ios.sh devices create <name> --runtime <version>
```
- `name`: Device name (used as filename and display name)
- `--runtime`: iOS version (required, e.g., "17.5", "18.0", "15.4")

**Examples:**
```bash
# Create iPhone 15 simulator with iOS 17.5
devbox run --pure ios.sh devices create iphone15 --runtime 17.5

# Create iPad simulator
devbox run --pure ios.sh devices create ipad_pro --runtime 18.0
```

**Update device:**
```bash
devbox run --pure ios.sh devices update <name> [--name <new>] [--runtime <version>]
```
- `--name`: Rename device (optional)
- `--runtime`: Change iOS version (optional)

**Examples:**
```bash
# Update runtime version
devbox run --pure ios.sh devices update iphone15 --runtime 18.0

# Rename device
devbox run --pure ios.sh devices update iphone15 --name iphone15_pro
```

**Delete device:**
```bash
devbox run --pure ios.sh devices delete <name>
```
- Removes device definition file
- Example: `ios.sh devices delete iphone15`

**Generate lock file:**
```bash
devbox run --pure ios.sh devices eval
```
- Generates `devices.lock` from device definitions
- Respects `IOS_DEVICES` filter (empty = all devices)
- Run after creating/updating/deleting devices
- Includes checksum for validation

**Related:** `devbox run ios:devices:eval` (convenience script)

**Sync simulators:**
```bash
devbox run --pure ios.sh devices sync
```
- Creates/updates simulators to match device definitions
- Reads from `devices.lock`
- Reports: matched, recreated, created, skipped

#### Application Deployment

**Plugin-provided:**
```bash
ios.sh build [flags]                   # Auto-detect and build Xcode project
ios.sh run [app_path] [device]         # Build, install, and launch app on simulator
```

**Example devbox.json scripts:**
```json
{
  "shell": {
    "scripts": {
      "build": ["ios.sh build"],
      "build:release": ["ios.sh build --config Release"],
      "test": ["ios.sh build --action test"],
      "start:app": ["ios.sh run ${1:-}"]
    }
  }
}
```

The `ios.sh run` command auto-detects the .app bundle (via `IOS_APP_ARTIFACT` env var, xcodebuild settings, or recursive search) and extracts the bundle ID from `Info.plist`.

#### Configuration Management

**Show configuration:**
```bash
devbox run --pure ios.sh config show
```
- Displays current environment variable configuration

**Show SDK info:**
```bash
devbox run --pure ios.sh info
```
- Shows Xcode developer directory
- Displays iOS SDK version
- Lists available runtimes
- Shows device configuration

#### Diagnostics

**Environment check:**
```bash
devbox run doctor
```
- Checks Xcode installation and command-line tools
- Verifies xcrun and simctl availability
- Shows device definitions and lock file status
- Displays environment variables

**Verify setup:**
```bash
devbox run verify:setup
```
- Quick check that iOS environment is functional
- Exits 1 on failure, 0 on success
- Checks: Xcode tools, simctl availability

## React Native Plugin Commands

The React Native plugin composes Android and iOS plugins and adds Metro bundler management.

### Platform Commands

**Plugin-provided:**
- `devbox run --pure start:emu [device]` - Start Android emulator
- `devbox run --pure stop:emu` - Stop Android emulator
- `devbox run --pure start:sim [device]` - Start iOS simulator
- `devbox run --pure stop:sim` - Stop iOS simulator

**User-defined (define in your devbox.json):**
- `devbox run --pure start-android [device]` - Build and run Android app
- `devbox run --pure start-ios [device]` - Build and run iOS app
- `devbox run --pure start-web` - Start web development server

### Metro Bundler Management

**Get Metro port:**
```bash
devbox run rn:metro:port [suite]
```
- Returns the port assigned to Metro bundler for specified suite
- `suite`: Test suite name (optional, defaults to "default")
- Used for test isolation with multiple Metro instances

**Clean Metro cache:**
```bash
devbox run rn:metro:clean [suite]
```
- Removes Metro cache and port tracking for specified suite
- `suite`: Test suite name (optional, defaults to "default")
- Cleans: port files, environment files, cache directory

### Testing

**Test Metro functionality:**
```bash
devbox run test:metro
```
- Runs Metro port management unit tests

**Test Metro shutdown:**
```bash
devbox run test:metro:shutdown
```
- Runs Metro shutdown process-compose tests

### Diagnostics

**Environment check:**
```bash
devbox run doctor
```
- Checks Node.js, npm, and Watchman availability
- Verifies Android environment (SDK, tools, devices)
- Verifies iOS environment (Xcode, simctl, devices)
- Shows device counts for both platforms

**Verify setup:**
```bash
devbox run verify:setup
```
- Quick check that React Native environment is functional
- Exits 1 on failure, 0 on success
- Checks: Node.js/npm, Android SDK, iOS tools

## Device Management Commands

Available for both Android and iOS plugins.

### Common Operations

**Workflow after device changes:**
```bash
# 1. Create/update/delete devices
devbox run --pure {platform}.sh devices create <name> <options>

# 2. Regenerate lock file
devbox run --pure {platform}.sh devices eval

# 3. Sync simulators/AVDs (optional, creates actual devices)
devbox run --pure {platform}.sh devices sync
```

**Platform-specific examples:**
```bash
# Android workflow
devbox run --pure android.sh devices create pixel_api35 --api 35 --device pixel
devbox run --pure android.sh devices eval
devbox run --pure android.sh devices sync

# iOS workflow
devbox run --pure ios.sh devices create iphone16 --runtime 18.0
devbox run --pure ios.sh devices eval
devbox run --pure ios.sh devices sync
```

## Diagnostic Commands

All plugins provide diagnostic commands for troubleshooting.

### doctor

**Purpose:** Comprehensive environment check

**Android output includes:**
- ANDROID_SDK_ROOT configuration
- Tool availability (adb, emulator, avdmanager)
- Device definitions count and filter settings
- Lock file status

**iOS output includes:**
- Xcode developer directory
- Command-line tools availability
- xcrun and simctl status
- Device definitions count and filter settings
- Lock file status

**React Native output includes:**
- Node.js, npm, Watchman availability
- Android environment summary
- iOS environment summary
- Device counts for both platforms

### verify:setup

**Purpose:** Quick pass/fail environment check

**Behavior:**
- Exits 0 if environment is functional
- Exits 1 if environment check fails
- Useful for CI/CD pipelines

**Platform checks:**
- Android: SDK root, directory exists, adb available
- iOS: Xcode tools, simctl working
- React Native: Node.js/npm, Android SDK, iOS tools

## Configuration Commands

### config show

**Available for:** Android, iOS

**Purpose:** Display current environment variable configuration

**Output includes:**
- All plugin-specific environment variables
- Directory paths
- Device selection settings
- Build configuration

### config set

**Available for:** Android

**Purpose:** Update configuration values

**Syntax:**
```bash
devbox run --pure android.sh config set KEY=VALUE [KEY=VALUE...]
```

**Examples:**
```bash
# Set default device
devbox run --pure android.sh config set ANDROID_DEFAULT_DEVICE=pixel_api35

# Set multiple values
devbox run --pure android.sh config set \
  ANDROID_DEFAULT_DEVICE=pixel_api35 \
  ANDROID_COMPILE_SDK=35
```

### config reset

**Available for:** Android

**Purpose:** Reset configuration to defaults

## Script Naming Conventions

### Main CLI Scripts

- `android.sh` - Android main CLI (device and emulator management)
- `ios.sh` - iOS main CLI (device and simulator management)
- `rn.sh` - React Native utilities (Metro management)
- `metro.sh` - Metro bundler operations

### Convenience Scripts (Plugin-Provided)

- `start:emu` - Start Android emulator (alias for `android.sh emulator start`)
- `stop:emu` - Stop Android emulator
- `start:sim` - Start iOS simulator
- `stop:sim` - Stop iOS simulator
- `doctor` - Comprehensive environment check
- `verify:setup` - Quick pass/fail check

### User-Defined Scripts (Define in Your devbox.json)

The following are NOT provided by the plugins. Define them in your project's `devbox.json` as needed:

- `start-ios` / `start:ios` - Build and run iOS app
- `start-android` / `start:android` - Build and run Android app

### Device Management Scripts

- `{platform}:devices:eval` - Generate lock file (convenience alias)

## Command Categories

### Emulator/Simulator Lifecycle (Plugin-Provided)

**Android:**
- `android.sh emulator start [--pure] [device]`
- `android.sh emulator stop`
- `android.sh emulator reset [device]`
- `start:emu [device]` - Convenience alias for `android.sh emulator start`
- `stop:emu` - Convenience alias for `android.sh emulator stop`

**iOS:**
- `start:sim [device]`
- `stop:sim`

### Device Definition Management (Plugin-Provided)

**Create:**
- `android.sh devices create <name> --api <n> --device <id> [options]`
- `ios.sh devices create <name> --runtime <version>`

**Read:**
- `{platform}.sh devices list`
- `{platform}.sh devices show <name>`

**Update:**
- `android.sh devices update <name> [options]`
- `ios.sh devices update <name> [options]`

**Delete:**
- `{platform}.sh devices delete <name>`

**Sync:**
- `{platform}.sh devices eval` - Generate lock file
- `{platform}.sh devices sync` - Create/update simulators/AVDs

### Application Deployment

**Plugin-provided:**
- `android.sh build [flags]` - Auto-detect and build Gradle project
- `android.sh run [apk_path] [device]` - Install and launch Android app
- `ios.sh build [flags]` - Auto-detect and build Xcode project
- `ios.sh run [app_path] [device]` - Build, install, and launch iOS app

**User-defined (define in your devbox.json):**
- `start-android` / `start:android` - Build and run Android app
- `start-ios` / `start:ios` - Build and run iOS app
- `start-web` - Start web development server

### Configuration (Plugin-Provided)

- `{platform}.sh config show` - Display configuration
- `android.sh config set KEY=VALUE` - Update configuration
- `android.sh config reset` - Reset to defaults
- `ios.sh info` - Show SDK info

### Diagnostics (Plugin-Provided)

- `doctor` - Comprehensive check
- `verify:setup` - Quick pass/fail check

## Usage Tips

### Using --pure flag

The `--pure` flag runs commands in isolated environments:
```bash
# Recommended for reproducibility
devbox run --pure android.sh devices list

# Useful for testing
devbox run --pure start:emu
```

### Device name resolution

When no device specified, uses default:
```bash
# Uses ANDROID_DEFAULT_DEVICE
devbox run start:emu

# Uses IOS_DEFAULT_DEVICE
devbox run start:sim
```

Set defaults in `devbox.json`:
```json
{
  "env": {
    "ANDROID_DEFAULT_DEVICE": "pixel_api35",
    "IOS_DEFAULT_DEVICE": "iphone15"
  }
}
```

### Device filtering

Control which devices are evaluated:
```json
{
  "env": {
    "ANDROID_DEVICES": "min,max",
    "IOS_DEVICES": "min,max"
  }
}
```

After changing filters, regenerate lock files:
```bash
devbox run --pure android.sh devices eval
devbox run --pure ios.sh devices eval
```

### Chaining commands

Use shell operators for workflows:
```bash
# Start emulator and run app
devbox run --pure start:emu && devbox run --pure android.sh run

# Create device and sync
devbox run --pure android.sh devices create pixel_api35 --api 35 --device pixel && \
devbox run --pure android.sh devices eval && \
devbox run --pure android.sh devices sync
```

### Script location

All scripts are in PATH when in devbox shell:
```bash
# Inside devbox shell
devbox shell

# Can run directly
android.sh devices list
ios.sh config show
```

Outside shell, use `devbox run`:
```bash
# Outside shell
devbox run android.sh devices list
```

## Related Documentation

- [Android Plugin Reference](android.md)
- [iOS Plugin Reference](ios.md)
- [React Native Plugin Reference](react-native.md)
- [Environment Variables](environment-variables.md)
- [Plugin Conventions](../project/CONVENTIONS.md)
