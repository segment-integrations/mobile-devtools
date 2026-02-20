# React Native Development Guide

This guide covers React Native development using the Devbox React Native plugin, which composes the Android and iOS plugins to provide a complete cross-platform mobile development environment.

## What the Plugin Provides

The React Native plugin is a composition layer that combines the Android and iOS plugins to deliver:

- **Cross-platform device management** - Inherits Android emulator and iOS simulator management from both platform plugins
- **Metro bundler orchestration** - Manages Metro instances with dynamic port allocation and isolated state
- **Hot reload development** - Fast iteration with Debug builds and instant code updates
- **Automated testing** - E2E test suites with Release builds and cleanup
- **Web bundling support** - Optional web target for React Native Web projects
- **Process isolation** - Multiple Metro instances can run in parallel for testing different platform versions

The plugin does not modify React Native itself. It provides the native platform tooling (Android SDK, Xcode, simulators, emulators) and development workflow automation.

## Setup and Installation

### Prerequisites

A React Native project with `package.json` and platform-specific code in `android/` and `ios/` directories. [Install devbox](https://www.jetify.com/docs/devbox/installing_devbox/) if you have not already -- it handles downloading all required tools (Node.js, Android SDK, build tooling, etc.) automatically.

For iOS development, macOS with Xcode installed is required.

### Adding the Plugin

Devbox plugins are included via URL in the `"include"` field of `devbox.json`, not through `devbox add`. The plugin URL points to this repository and specifies which plugin directory to use.

Include the React Native plugin in your `devbox.json`:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/react-native"],
  "packages": [
    "nodejs@20",
    "watchman@latest",
    "jdk17@latest",
    "gradle@latest"
  ],
  "env": {
    "ANDROID_APP_ID": "com.example.app",
    "ANDROID_APP_APK": "android/app/build/outputs/apk/debug/app-debug.apk",
    "IOS_APP_ARTIFACT": ".devbox/virtenv/ios/DerivedData/Build/Products/Debug-iphonesimulator/MyApp.app"
  }
}
```

### Configuration

The React Native plugin inherits configuration from both Android and iOS plugins. Configure platform-specific settings via environment variables in `devbox.json`.

**Common React Native settings:**

```json
{
  "env": {
    "ANDROID_DEFAULT_DEVICE": "max",
    "IOS_DEFAULT_DEVICE": "max",
    "ANDROID_DEVICES": "min,max",
    "IOS_DEVICES": "min,max",
    "WEB_BUILD_PATH": "web/build"
  }
}
```

**Android configuration** - See [Android Guide](android-guide.md) for details:
- `ANDROID_DEFAULT_DEVICE` - Default emulator (e.g., "max", "min", "pixel_api30")
- `ANDROID_DEVICES` - Comma-separated devices to evaluate (empty = all)
- `ANDROID_APP_ID` - Android package identifier
- `ANDROID_APP_APK` - APK path/glob after build
- `ANDROID_COMPILE_SDK` - Compile SDK version
- `ANDROID_TARGET_SDK` - Target SDK version

**iOS configuration** - See [iOS Guide](ios-guide.md) for details:
- `IOS_DEFAULT_DEVICE` - Default simulator (e.g., "max", "min", "iphone15")
- `IOS_DEVICES` - Comma-separated devices to evaluate (empty = all)
- `IOS_APP_ARTIFACT` - App path/glob after build (empty = auto-detect)
- `IOS_DOWNLOAD_RUNTIME` - Auto-download missing runtimes (1=yes, 0=no)

### Installing Dependencies

Install Node.js dependencies and native CocoaPods:

```bash
# Install npm packages
devbox run install

# iOS: Install CocoaPods (first time only)
cd ios && pod install --repo-update
```

## Development Workflow

React Native development with Devbox supports two primary workflows: interactive development with hot reload and automated E2E testing.

### Development Mode (Interactive)

Development mode prioritizes fast iteration with hot reload enabled. It uses Debug builds for faster compilation and reuses existing emulators/simulators to avoid startup overhead.

The commands below (`start:android`, `start:ios`, `start:web`) are user-defined scripts from the example project. See the [example project's devbox.json](../../examples/react-native/devbox.json) for how they are defined. You will need to add similar scripts to your own `devbox.json`.

**Start development for Android:**

```bash
devbox run start:android
```

**Start development for iOS:**

```bash
devbox run start:ios
```

**Start development for Web:**

```bash
devbox run start:web
```

**What happens:**
1. Allocates a unique Metro port (8091-8199 range)
2. Installs Node.js dependencies
3. Builds the app (Debug configuration)
4. Starts or reuses emulator/simulator
5. Starts Metro bundler with hot reload
6. Deploys the app
7. Leaves Metro and emulator/simulator running

**Hot reload workflow:**
1. Edit code in your editor (e.g., `App.tsx`)
2. Save the file
3. Changes appear automatically in the running app (powered by Fast Refresh)

**Manual reload:**
- Android: Press `R` twice or `Ctrl/Cmd + M` to open Dev Menu
- iOS: Press `R` in simulator
- Both: Shake device to open Dev Menu

**Enable TUI for interactive monitoring:**

```bash
DEVBOX_TUI=true devbox run start:android
DEVBOX_TUI=true devbox run start:ios
```

TUI mode provides a terminal interface to monitor all processes (build, emulator, Metro, deploy) in real-time.

### Building Apps

Build platform-specific artifacts without running them. These build commands are user-defined scripts from the example project -- you will need to define your own build scripts in your `devbox.json` that match your project's build process.

```bash
# Build for Android (Debug)
devbox run build:android

# Build for iOS (Debug)
devbox run build:ios

# Build for Web
devbox run build:web

# Build all platforms
devbox run build
```

Builds are cached. Subsequent builds are incremental and faster.

### Managing Devices

The React Native plugin inherits device management from both platform plugins. Devices are defined in JSON files and automatically synced before emulator/simulator startup.

**List available devices:**

```bash
# Android devices
devbox run --pure android.sh devices list

# iOS devices
devbox run --pure ios.sh devices list
```

**Create custom devices:**

```bash
# Android - specify API level and device profile
devbox run --pure android.sh devices create pixel_api30 \
  --api 30 \
  --device pixel \
  --tag google_apis

# iOS - specify simulator runtime
devbox run --pure ios.sh devices create iphone14 \
  --runtime 16.4

# Regenerate lock files after changes
devbox run --pure android.sh devices eval
devbox run --pure ios.sh devices eval
```

**Device definitions:**

Device JSON files are stored in the devices directory within your `devbox.d` folder. The exact path depends on how the plugin is included (local vs GitHub URL). Use the `devices list` command to see the configured path.

**Default devices:**

Device definitions include `min.json` and `max.json` representing the minimum and maximum supported platform versions. Configure which device to use with `ANDROID_DEFAULT_DEVICE` and `IOS_DEFAULT_DEVICE`.

**Override default device at runtime:**

```bash
# Start specific emulator
devbox run start:emu pixel_api30

# Start specific simulator
devbox run start:sim iphone14
```

For complete device management documentation, see:
- [Android Guide - Device Management](android-guide.md#device-management)
- [iOS Guide - Device Management](ios-guide.md#device-management)

### Metro Bundler Management

Metro is the JavaScript build tool for React Native. The plugin manages Metro instances with isolated state and dynamic port allocation.

**Automatic Metro management (recommended):**

Metro is automatically started and stopped by development and test commands:

```bash
devbox run start:android  # Starts Metro automatically
devbox run start:ios      # Starts Metro automatically
```

**Manual Metro control (advanced):**

The `start:metro` and `stop:metro` scripts below are user-defined wrappers from the example project. The plugin provides the `metro.sh` CLI directly.

```bash
# Start Metro for specific suite (user-defined wrapper)
devbox run start:metro android
devbox run start:metro ios

# Stop Metro for specific suite (user-defined wrapper)
devbox run stop:metro android
devbox run stop:metro ios

# Plugin-provided CLI commands
metro.sh status android
metro.sh status ios

# Health check (exit code only, for readiness probes)
metro.sh health android android
metro.sh health ios ios

# Clean Metro state files
metro.sh clean android
metro.sh clean ios
```

**Key features:**

- **Dynamic port allocation** - Allocates ports in range 8091-8199 to avoid conflicts
- **Unique suite names** - Isolate Metro instances (android, ios, web, all)
- **Parallel test support** - Run multiple Metro instances simultaneously
- **Automatic cleanup** - Process-compose handles lifecycle
- **Environment isolation** - Each suite gets unique environment files

**Metro state files:**

Located in `.devbox/virtenv/react-native/metro/`:
- `port-{suite}.txt` - Allocated port number
- `env-{suite}.sh` - Environment variables (sourced by deploy scripts)
- Cache files managed automatically

**Metro environment variables:**

When Metro starts, it exports:
- `METRO_PORT` - Allocated port number
- Cache directory paths

Deploy scripts source `env-{suite}.sh` to ensure React Native uses the correct Metro port.

## Testing

The example project demonstrates automated E2E testing with Release builds and cleanup. The test commands shown below are user-defined scripts from the example project. You will need to define your own test scripts in your `devbox.json`.

### Running E2E Tests

```bash
# Test iOS only (fast - skips Android SDK)
devbox run test:e2e:ios

# Test Android only (fast - skips iOS setup)
devbox run test:e2e:android

# Test both platforms in parallel
devbox run test:e2e:all

# Test web bundle
devbox run test:e2e:web
```

**E2E test behavior:**
- Automatically runs with `--pure` flag (isolated, reproducible)
- Uses Release builds for production-like behavior
- Starts fresh emulator/simulator from scratch
- Automatic cleanup after tests complete
- No TUI (automated, non-interactive)
- Summary reports with test results and log locations

**Test logs:**

Logs are written to `reports/` directory:
- iOS E2E: `reports/react-native-ios-e2e-logs/`
- Android E2E: `reports/react-native-android-e2e-logs/`
- Web E2E: `reports/react-native-web-e2e-logs/`
- Dev mode: `reports/react-native-{platform}-dev-logs/`

### Test Modes: --pure vs Development

**CI Mode (`--pure`) - Default for E2E Tests**

Purpose: Deterministic, reproducible test runs for continuous integration.

```bash
# E2E commands automatically use --pure
devbox run test:e2e:ios
devbox run test:e2e:android
```

Behavior:
- Always starts fresh emulator/simulator from scratch
- Clean state with no cached data or previous state
- Automatic cleanup (stops and deletes devices after completion)
- Isolated (each test run is completely independent)

**Development Mode - Default for start:\* Commands**

Purpose: Fast iteration during local development.

```bash
devbox run start:android
devbox run start:ios
```

Behavior:
- Reuses existing emulator/simulator if available
- Starts device only if not already running
- No cleanup (leaves device running after completion)
- Fast iteration with no startup/shutdown overhead

### Build Configuration

Development mode uses Debug builds. E2E tests use Release builds.

Override with environment variables:

```bash
# Force Debug build in E2E test (faster compilation)
IOS_BUILD_CONFIG=Debug devbox run test:e2e:ios

# Force Release build in dev mode (slower but production-like)
BUILD_CONFIG=Release devbox run start:android
```

### Platform-Specific Optimization

When testing a single platform, skip the unused platform to speed up initialization:

```bash
# iOS tests only (skips Android SDK evaluation)
devbox run test:e2e:ios

# Android tests only (skips iOS setup)
devbox run test:e2e:android
```

The test commands automatically set optimization flags:
- `ANDROID_SKIP_SETUP=1` - Skip Android SDK Nix flake evaluation (iOS tests)
- `IOS_SKIP_SETUP=1` - Skip iOS environment setup (Android tests)

**Important:** When using `--pure` mode manually, pass environment variables with `-e` flag:

```bash
# Correct way to skip Android SDK in pure mode
devbox run --pure -e ANDROID_SKIP_SETUP=1 test:e2e:ios

# Incorrect - env var gets reset to default
ANDROID_SKIP_SETUP=1 devbox run --pure test:e2e:ios
```

### Parallel Testing Multiple Versions

Test multiple platform versions in parallel by creating separate test suite files with unique suite names.

**Example: Test Android API 21 and API 35 simultaneously**

Create `test-suite-android-api21.yaml`:

```yaml
environment:
  - "ANDROID_DEFAULT_DEVICE=min"

processes:
  allocate-metro-port:
    command: |
      . ${REACT_NATIVE_VIRTENV}/scripts/lib/lib.sh
      metro_port=$(rn_allocate_metro_port "android-api21")
      rn_save_metro_env "android-api21" "$metro_port"

  metro-bundler:
    command: "metro.sh start android-api21"

  cleanup:
    command: "metro.sh stop android-api21"
```

Create `test-suite-android-api35.yaml`:

```yaml
environment:
  - "ANDROID_DEFAULT_DEVICE=max"

processes:
  allocate-metro-port:
    command: |
      . ${REACT_NATIVE_VIRTENV}/scripts/lib/lib.sh
      metro_port=$(rn_allocate_metro_port "android-api35")
      rn_save_metro_env "android-api35" "$metro_port"

  metro-bundler:
    command: "metro.sh start android-api35"

  cleanup:
    command: "metro.sh stop android-api35"
```

Run in parallel:

```bash
process-compose -f test-suite-android-api21.yaml &
process-compose -f test-suite-android-api35.yaml &
wait
```

**Key requirement:** Use unique suite names for:
- `rn_allocate_metro_port` calls
- `metro.sh start/stop` commands
- Environment file names

This ensures each test gets its own Metro instance on a unique port with isolated state.

## Troubleshooting

### Metro Port Conflicts

If you see "Metro port already in use" errors:

```bash
# Check what's using the port
lsof -ti:8081

# Stop Metro for specific suite
metro.sh stop android
metro.sh stop ios

# Clean all Metro state
metro.sh clean android
metro.sh clean ios
```

### Emulator/Simulator Not Starting

**Android:**

```bash
# Check emulator status
adb devices

# View emulator logs
tail -f reports/react-native-android-dev-logs/*.log

# Stop and restart
devbox run stop:emu
devbox run start:emu
```

**iOS:**

```bash
# Check simulator status
xcrun simctl list devices

# View simulator logs
tail -f reports/react-native-ios-dev-logs/*.log

# Stop and restart
devbox run stop:sim
devbox run start:sim
```

### App Not Updating with Hot Reload

1. Check Metro is running: `metro.sh status android`
2. Check Metro logs for errors
3. Force reload: Press `R` twice (Android) or `R` once (iOS)
4. Restart Metro: `devbox run stop:metro android && devbox run start:metro android`

### Build Failures

**Android Gradle errors:**

```bash
# Clean build
cd android && ./gradlew clean assembleDebug
```

**iOS Xcode errors:**

```bash
# Clean derived data
rm -rf .devbox/virtenv/ios/DerivedData

# Reinstall CocoaPods
cd ios && pod install --repo-update

# Rebuild
devbox run build:ios
```

### Platform-Specific Issues

For platform-specific troubleshooting, see:
- [Android Troubleshooting Guide](android-guide.md#troubleshooting)
- [iOS Troubleshooting Guide](ios-guide.md#troubleshooting)
- [General Troubleshooting Guide](troubleshooting.md)

### Debug Logging

Enable debug logging to diagnose issues:

```bash
# React Native debug
DEBUG=1 devbox run start:android

# Android debug
ANDROID_DEBUG=1 devbox run start:android

# iOS debug
IOS_DEBUG=1 devbox run start:ios

# Combined
DEBUG=1 ANDROID_DEBUG=1 devbox run start:android
```

### Process-Compose Logs

View all process logs:

```bash
# Development logs
ls -la reports/react-native-android-dev-logs/
ls -la reports/react-native-ios-dev-logs/

# E2E test logs
ls -la reports/react-native-android-e2e-logs/
ls -la reports/react-native-ios-e2e-logs/
```

## Configuration Reference

### Environment Variables

**React Native settings:**
- `WEB_BUILD_PATH` - Web bundle output directory (default: "web/build")

**Android settings** (see [Android Reference](../reference/android.md)):
- `ANDROID_DEFAULT_DEVICE` - Default emulator
- `ANDROID_DEVICES` - Devices to evaluate (comma-separated, empty = all)
- `ANDROID_APP_ID` - Android package identifier
- `ANDROID_APP_APK` - APK path/glob
- `ANDROID_COMPILE_SDK` - Compile SDK version
- `ANDROID_TARGET_SDK` - Target SDK version
- `ANDROID_BUILD_TOOLS_VERSION` - Build tools version
- `ANDROID_SKIP_SETUP` - Skip SDK downloads (1=skip, 0=evaluate)

**iOS settings** (see [iOS Reference](../reference/ios.md)):
- `IOS_DEFAULT_DEVICE` - Default simulator
- `IOS_DEVICES` - Devices to evaluate (comma-separated, empty = all)
- `IOS_APP_ARTIFACT` - App bundle path/glob (empty = auto-detect)
- `IOS_DOWNLOAD_RUNTIME` - Auto-download runtimes (1=yes, 0=no)
- `IOS_SKIP_SETUP` - Skip iOS setup (1=skip, 0=setup)

### Commands

#### Plugin-Provided Commands

These commands are provided by the Android, iOS, and React Native plugins and are available automatically when the plugin is included.

**Emulator/Simulator management (from Android and iOS plugins):**
- `devbox run start:emu [device]` - Start Android emulator
- `devbox run stop:emu` - Stop Android emulator
- `devbox run start:sim [device]` - Start iOS simulator
- `devbox run stop:sim` - Stop iOS simulator

**Device management CLI (from Android and iOS plugins):**
- `android.sh devices list` - List Android devices
- `android.sh devices create` - Create Android device
- `android.sh devices sync` - Sync AVDs with definitions
- `ios.sh devices list` - List iOS devices
- `ios.sh devices create` - Create iOS device
- `ios.sh devices sync` - Sync simulators with definitions

**Metro CLI (from React Native plugin):**
- `metro.sh start [suite]` - Start Metro bundler
- `metro.sh stop [suite]` - Stop Metro bundler
- `metro.sh status [suite]` - Check Metro status
- `metro.sh health [suite] [platform]` - Health check (exit code)
- `metro.sh clean [suite]` - Clean Metro state files

**Diagnostics (from all plugins):**
- `devbox run doctor` - Check environment health
- `devbox run verify:setup` - Verify environment is correctly configured

#### User-Defined Commands (Example Project)

These commands are **not** provided by the plugins. They are defined in the example project's `devbox.json` and serve as a reference for how to build your own workflow scripts. You must add similar scripts to your own `devbox.json` to use them.

**Development workflow:**
- `devbox run start:android` - Start Android development with hot reload
- `devbox run start:ios` - Start iOS development with hot reload
- `devbox run start:web` - Start web development with browser
- `devbox run start:metro [suite]` - Start Metro bundler (wraps `metro.sh start`)
- `devbox run stop:metro [suite]` - Stop Metro bundler (wraps `metro.sh stop`)

**Building:**
- `devbox run build:android` - Build Android APK (Debug)
- `devbox run build:ios` - Build iOS app (Debug)
- `devbox run build:web` - Build web bundle
- `devbox run build` - Build all platforms

**Testing:**
- `devbox run test:e2e:android` - Android E2E tests (--pure)
- `devbox run test:e2e:ios` - iOS E2E tests (--pure)
- `devbox run test:e2e:all` - Both platforms in parallel
- `devbox run test:e2e:web` - Web bundle tests
- `devbox run test` - Run Jest tests

### Files and Directories

**Configuration:**
- `devbox.json` - Project configuration
- `devbox.d/` - Plugin configuration directory containing device definitions for Android and iOS (exact subdirectory structure depends on how plugins are included)

**Generated files:**
- `.devbox/virtenv/react-native/metro/` - Metro state files
  - `port-{suite}.txt` - Allocated Metro port
  - `env-{suite}.sh` - Metro environment variables
- `.devbox/virtenv/android/` - Android runtime files
- `.devbox/virtenv/ios/` - iOS runtime files

**Logs:**
- `reports/react-native-{platform}-dev-logs/` - Development logs
- `reports/react-native-{platform}-e2e-logs/` - E2E test logs

## Next Steps

### Learn More

- [Android Development Guide](android-guide.md) - Platform-specific Android details
- [iOS Development Guide](ios-guide.md) - Platform-specific iOS details
- [Device Management Guide](device-management.md) - Cross-platform device management
- [Testing Guide](testing.md) - E2E testing patterns
- [Troubleshooting Guide](troubleshooting.md) - Common issues and solutions

### Reference Documentation

- [React Native Plugin Reference](../reference/react-native.md) - Complete API reference
- [Android Plugin Reference](../reference/android.md) - Android configuration options
- [iOS Plugin Reference](../reference/ios.md) - iOS configuration options

### Example Projects

- `/examples/react-native/` - Complete React Native app with test suites
- `/examples/android/` - Minimal Android app
- `/examples/ios/` - Swift package example

### Interactive Shell

For full environment setup with both platforms:

```bash
devbox shell
```

This provides a fully configured shell with Android SDK, iOS tooling, Metro, and all development tools ready to use.
