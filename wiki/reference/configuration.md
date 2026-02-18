# Devbox.json Configuration Reference

Complete reference for configuring the Android, iOS, and React Native devbox plugins through `devbox.json`.

## Plugin Inclusion

### Android Plugin

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/android"]
}
```

Or use path-based inclusion:
```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/android"]
}
```

### iOS Plugin

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/ios"]
}
```

Or use path-based inclusion:
```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/ios"]
}
```

### React Native Plugin

The React Native plugin automatically includes both Android and iOS plugins:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/react-native"]
}
```

Or use path-based inclusion:
```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/react-native"]
}
```

## Android Plugin

### Environment Variables

#### Core Settings

- `ANDROID_USER_HOME` - Android user home directory (default: `{{ .Virtenv }}/android`)
- `ANDROID_AVD_HOME` - AVD home directory (default: `{{ .Virtenv }}/android/avd`)
- `ANDROID_EMULATOR_HOME` - Emulator home directory (default: `{{ .Virtenv }}/android`)
- `ANDROID_CONFIG_DIR` - Configuration directory (default: `{{ .DevboxDir }}`)
- `ANDROID_DEVICES_DIR` - Device definitions directory (default: `{{ .DevboxDir }}/devices`)
- `ANDROID_SCRIPTS_DIR` - Runtime scripts directory (default: `{{ .Virtenv }}/scripts`)
- `ANDROID_RUNTIME_DIR` - Runtime directory (default: `{{ .Virtenv }}`)

#### Device Configuration

- `ANDROID_DEFAULT_DEVICE` - Default device name when none specified (default: `max`)
- `ANDROID_DEVICES` - Comma-separated device names to evaluate (empty = all devices, default: `""`)
- `ANDROID_DEVICE_NAME` - Override device selection for current command
- `TARGET_DEVICE` - Alternative device selection (deprecated, use `ANDROID_DEVICE_NAME`)

#### SDK Configuration

- `ANDROID_LOCAL_SDK` - Use local SDK instead of Nix-managed SDK (0=false, 1=true, default: `0`)
- `ANDROID_COMPILE_SDK` - Compile SDK version (default: `36`)
- `ANDROID_TARGET_SDK` - Target SDK version (default: `36`)
- `ANDROID_BUILD_TOOLS_VERSION` - Build tools version (default: `36.1.0`)
- `ANDROID_CMDLINE_TOOLS_VERSION` - Command-line tools version (default: `19.0`)
- `ANDROID_SYSTEM_IMAGE_TAG` - System image tag (default: `google_apis`)
  - Valid values: `google_apis`, `google_apis_playstore`, `play_store`, `aosp_atd`, `google_atd`

#### NDK and CMake

- `ANDROID_INCLUDE_NDK` - Include Android NDK in SDK (true/false, default: `false`)
- `ANDROID_NDK_VERSION` - NDK version when enabled (default: `27.0.12077973`)
- `ANDROID_INCLUDE_CMAKE` - Include CMake in SDK (true/false, default: `false`)
- `ANDROID_CMAKE_VERSION` - CMake version when enabled (default: `3.22.1`)

#### App Configuration

- `ANDROID_APP_APK` - Path or glob pattern for APK (relative to project root)
- `ANDROID_APP_ID` - Android application ID (e.g., `com.example.app`)

#### Emulator Behavior

- `EMU_HEADLESS` - Run emulator headless without GUI window (0/1)
- `EMU_PORT` - Preferred emulator port (default: `5554`)
- `ANDROID_EMULATOR_PURE` - Always start fresh emulator with clean state (0/1, default: `0`)
- `ANDROID_SKIP_CLEANUP` - Skip offline emulator cleanup during startup (0/1, default: `0`)
  - Set to 1 in multi-emulator scenarios to prevent cleanup from killing emulators that are still booting
- `ANDROID_DISABLE_SNAPSHOTS` - Disable snapshot boots, force cold boot (0/1, default: `0`)

#### Performance Settings

- `ANDROID_SKIP_DOWNLOADS` - Skip Android SDK downloads/evaluation during shell initialization (0/1, default: `0`)
  - Useful for iOS-only contexts in React Native projects to speed up initialization
  - When set to 1, skips Nix flake evaluation, SDK resolution, and environment configuration
  - Set before shell initialization: `devbox run -e ANDROID_SKIP_DOWNLOADS=1 build:ios`
  - With --pure flag: `devbox run --pure -e ANDROID_SKIP_DOWNLOADS=1 build:ios`

#### Testing and Reporting

- `REPORTS_DIR` - Base reports directory (default: `reports`)
- `TEST_LOGS_DIR` - Test logs directory (default: `reports/logs`)
- `TEST_RESULTS_DIR` - Test results directory (default: `reports/results`)

### Included Packages

The Android plugin automatically includes:

- `bash@latest`
- `coreutils@latest`
- `gnused@latest`
- `gnugrep@latest`
- `gawk@latest`
- `jq@latest`
- `process-compose@latest`

### Shell Scripts

#### Device Management

- `android:devices:eval` - Generate lock file from device definitions
- `start:emu` - Start Android emulator
- `stop:emu` - Stop Android emulator
- `reset:emu` - Reset Android emulator

#### Diagnostics

- `doctor` - Check Android environment health
- `verify:setup` - Quick verification that Android environment is functional (exits 1 on failure)

### Init Hooks

The Android plugin runs two initialization hooks:

1. `init-hook.sh` - Pre-shell initialization (generates lock file, sets up flake)
2. `setup.sh` - Shell environment setup (configures PATH and environment variables)

### Example Configuration

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/android"],
  "packages": {
    "jdk17": "latest",
    "gradle": "latest"
  },
  "env": {
    "ANDROID_DEFAULT_DEVICE": "max",
    "ANDROID_DEVICES": "min,max",
    "ANDROID_APP_ID": "com.example.devbox",
    "ANDROID_APP_APK": "app/build/outputs/apk/debug/app-debug.apk",
    "ANDROID_COMPILE_SDK": "36",
    "ANDROID_TARGET_SDK": "36"
  },
  "shell": {
    "scripts": {
      "build": [
        "gradle assembleDebug"
      ],
      "run": [
        "android.sh run ${1:-${ANDROID_DEFAULT_DEVICE:-max}}"
      ]
    }
  }
}
```

## iOS Plugin

### Environment Variables

#### Core Settings

- `IOS_CONFIG_DIR` - Configuration directory (default: `{{ .DevboxDir }}`)
- `IOS_DEVICES_DIR` - Device definitions directory (default: `{{ .DevboxDir }}/devices`)
- `IOS_SCRIPTS_DIR` - Scripts directory (default: `{{ .Virtenv }}/scripts`)

#### Device Configuration

- `IOS_DEFAULT_DEVICE` - Default device name when none specified (default: `max`)
- `IOS_DEVICES` - Comma-separated device names to evaluate (empty = all devices, default: `""`)
- `IOS_DEFAULT_RUNTIME` - Default iOS runtime version (empty = latest available)

#### Xcode Settings

- `IOS_DEVELOPER_DIR` - Xcode developer directory path (empty = auto-detect)
- `IOS_XCODE_ENV_PATH` - Additional PATH entries for Xcode tools
- `IOS_DOWNLOAD_RUNTIME` - Auto-download missing runtimes (1=yes, 0=no, default: `1`)

#### App Build Settings

- `IOS_APP_PROJECT` - Xcode project path (default: `ios.xcodeproj`)
- `IOS_APP_SCHEME` - Xcode build scheme (default: matches project name)
- `IOS_APP_BUNDLE_ID` - App bundle identifier (default: `com.example.ios`)
- `IOS_APP_ARTIFACT` - App bundle path/glob after build (default: `DerivedData/Build/Products/Debug-iphonesimulator/*.app`)
- `IOS_APP_DERIVED_DATA` - Xcode derived data directory (default: `.devbox/virtenv/ios/DerivedData`)

#### Performance Settings

- `IOS_SKIP_SETUP` - Skip iOS environment setup during shell initialization (1=skip, 0=setup, default: `0`)
  - Useful for Android-only contexts in React Native projects to speed up initialization
  - When set to 1, skips Xcode path detection, device lock generation, and environment configuration

#### Testing and Reporting

- `REPORTS_DIR` - Base reports directory (default: `reports`)

#### Internal Variables (Auto-Set)

These are set automatically by the plugin:

- `DEVELOPER_DIR` - Xcode developer directory (used by xcrun, xcodebuild)
- `CC` - C compiler path (`/usr/bin/clang`)
- `CXX` - C++ compiler path (`/usr/bin/clang++`)
- `IOS_NODE_BINARY` - Node.js binary path (if available, for React Native)

#### Runtime Variables (During Operations)

Set during simulator/app operations:

- `IOS_SIM_UDID` - UUID of running simulator
- `IOS_SIM_NAME` - Name of running simulator
- `IOS_APP_BUNDLE_PATH` - Resolved app bundle path after build

### Included Packages

The iOS plugin automatically includes:

- `bash@latest`
- `coreutils@latest`
- `gnused@latest`
- `gnugrep@latest`
- `gawk@latest`
- `jq@latest`
- `process-compose@latest`
- `cocoapods@latest` (macOS only: x86_64-darwin, aarch64-darwin)

### Shell Scripts

#### Simulator Management

- `start:sim` - Start iOS simulator
- `stop:sim` - Stop iOS simulator

#### Device Management

- `ios:devices:eval` - Generate lock file from device definitions

#### Diagnostics

- `doctor` - Check iOS environment health
- `verify:setup` - Quick verification that iOS environment is functional (exits 1 on failure)

### Init Hooks

The iOS plugin runs two initialization hooks:

1. `init-hook.sh` - Pre-shell initialization (generates lock file)
2. `setup.sh` - Shell environment setup (configures PATH and environment variables)

### Example Configuration

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/ios"],
  "packages": {
    "process-compose": "latest"
  },
  "env": {
    "IOS_DEFAULT_DEVICE": "max",
    "IOS_DEVICES": "min,max",
    "IOS_APP_PROJECT": "ios.xcodeproj",
    "IOS_APP_SCHEME": "ios",
    "IOS_APP_BUNDLE_ID": "com.example.ios",
    "IOS_APP_ARTIFACT": ".devbox/virtenv/ios/DerivedData/Build/Products/Debug-iphonesimulator/ios.app"
  },
  "shell": {
    "scripts": {
      "build": [
        "xcodebuild -project ${IOS_APP_PROJECT} -scheme ${IOS_APP_SCHEME} -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .devbox/virtenv/ios/DerivedData build"
      ],
      "start:ios": [
        "ios.sh simulator start ${1:-${IOS_DEFAULT_DEVICE:-max}}",
        "xcrun simctl install booted ${IOS_APP_ARTIFACT}",
        "xcrun simctl launch booted ${IOS_APP_BUNDLE_ID}"
      ]
    }
  }
}
```

## React Native Plugin

The React Native plugin composes both Android and iOS plugins. All Android and iOS environment variables are available.

### Additional Environment Variables

#### React Native Specific

- `REACT_NATIVE_CONFIG_DIR` - Configuration directory (default: `{{ .DevboxDir }}`)
- `REACT_NATIVE_VIRTENV` - Virtual environment directory (default: `{{ .Virtenv }}`)
- `REACT_NATIVE_SCRIPTS_DIR` - Scripts directory (default: `{{ .Virtenv }}/scripts`)
- `REACT_NATIVE_WEB_BUILD_PATH` - Web build output path (default: `web/build`)

#### Metro Bundler

- `METRO_CACHE_DIR` - Metro cache directory (default: `{{ .Virtenv }}/metro/cache`)
- `RN_METRO_PORT_START` - Metro port range start (default: `8091`)
- `RN_METRO_PORT_END` - Metro port range end (default: `8199`)

#### Overridden Defaults

The React Native plugin overrides some Android default values:

- `ANDROID_DEVICES` - Empty by default (evaluate all devices)
- `IOS_DEVICES` - Empty by default (evaluate all devices)
- `ANDROID_COMPILE_SDK` - Set to `35`
- `ANDROID_TARGET_SDK` - Set to `35`
- `ANDROID_BUILD_TOOLS_VERSION` - Set to `35.0.0`
- `ANDROID_INCLUDE_NDK` - Set to `true`
- `ANDROID_NDK_VERSION` - Set to `29.0.14206865`
- `ANDROID_INCLUDE_CMAKE` - Set to `true`
- `ANDROID_CMAKE_VERSION` - Set to `4.1.2`

### Included Packages

The React Native plugin includes all packages from Android and iOS plugins, plus:

- `nodejs@20`
- `watchman@latest`
- `process-compose@latest`

### Shell Scripts

#### Metro Management

- `rn:metro:port` - Get Metro port for a test suite
- `rn:metro:clean` - Clean Metro cache for a test suite

#### Diagnostics

- `doctor` - Check React Native environment health (includes Android and iOS checks)
- `verify:setup` - Quick verification that all environments are functional (exits 1 on failure)

#### Testing

- `test:metro` - Test Metro bundler functionality
- `test:metro:shutdown` - Test Metro shutdown behavior

### Init Hooks

The React Native plugin runs its own initialization hook plus the Android and iOS hooks:

1. `init-hook.sh` - React Native-specific initialization
2. Android `init-hook.sh` and `setup.sh`
3. iOS `init-hook.sh` and `setup.sh`

Additional exports:
- `NODE_BINARY` - Set to Node.js binary path

### Example Configuration

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
    "IOS_APP_PROJECT": "ReactNativeExample.xcodeproj",
    "IOS_APP_SCHEME": "ReactNativeExample",
    "IOS_APP_BUNDLE_ID": "org.reactjs.native.example.ReactNativeExample",
    "IOS_APP_ARTIFACT": ".devbox/virtenv/ios/DerivedData/Build/Products/Debug-iphonesimulator/ReactNativeExample.app",
    "ANDROID_APP_ID": "com.reactnativeexample",
    "ANDROID_APP_APK": "android/app/build/outputs/apk/debug/app-debug.apk",
    "ANDROID_MAX_API": "35",
    "DEVBOX_COREPACK_ENABLED": "",
    "ANDROID_SDK_REQUIRED": "0"
  },
  "shell": {
    "scripts": {
      "install": [
        "npm install"
      ],
      "build:android": [
        "devbox run install",
        "cd android && gradle assembleDebug"
      ],
      "build:ios": [
        "devbox run install",
        "cd ios && pod install --repo-update",
        "cd ios && xcodebuild -workspace ReactNativeExample.xcworkspace -scheme ${IOS_APP_SCHEME} -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath ${DEVBOX_PROJECT_ROOT}/.devbox/virtenv/ios/DerivedData build"
      ],
      "start:android": [
        "process-compose -f tests/dev-android.yaml"
      ],
      "start:ios": [
        "process-compose -f tests/dev-ios.yaml"
      ]
    }
  }
}
```

## Common Configuration Patterns

### Platform-Specific Device Selection

Limit which devices are evaluated (useful for CI to reduce build time):

```json
{
  "env": {
    "ANDROID_DEVICES": "min,max",
    "IOS_DEVICES": "min,max"
  }
}
```

### Headless Emulator for CI

Run Android emulator without GUI in CI environments:

```json
{
  "env": {
    "EMU_HEADLESS": "1",
    "ANDROID_DISABLE_SNAPSHOTS": "1"
  }
}
```

### Skip Platform Setup for Single-Platform Workflows

React Native projects can skip unused platform setup:

```json
{
  "shell": {
    "scripts": {
      "build:ios": [
        "ANDROID_SKIP_DOWNLOADS=1 devbox run --pure xcodebuild ..."
      ],
      "build:android": [
        "IOS_SKIP_SETUP=1 devbox run --pure gradle assembleDebug"
      ]
    }
  }
}
```

Or set in process-compose test suites:

```yaml
processes:
  build-ios:
    environment:
      - ANDROID_SKIP_DOWNLOADS=1
    command: devbox run build:ios
```

### Custom Xcode Path

Pin to specific Xcode version:

```json
{
  "env": {
    "IOS_DEVELOPER_DIR": "/Applications/Xcode-15.4.app/Contents/Developer"
  }
}
```

### Custom SDK Configuration

Override Android SDK settings:

```json
{
  "env": {
    "ANDROID_COMPILE_SDK": "35",
    "ANDROID_TARGET_SDK": "34",
    "ANDROID_BUILD_TOOLS_VERSION": "35.0.0",
    "ANDROID_INCLUDE_NDK": "true",
    "ANDROID_NDK_VERSION": "27.0.12077973"
  }
}
```

### Local SDK Usage

Use existing local Android SDK instead of Nix-managed SDK:

```json
{
  "env": {
    "ANDROID_LOCAL_SDK": "1"
  }
}
```

Requires `ANDROID_HOME` or `ANDROID_SDK_ROOT` to be set in your system environment.

### Project-Local Reporting

Configure test output directories:

```json
{
  "env": {
    "REPORTS_DIR": "test-reports",
    "TEST_LOGS_DIR": "test-reports/logs",
    "TEST_RESULTS_DIR": "test-reports/results"
  }
}
```

### Metro Port Configuration

Customize Metro bundler port range:

```json
{
  "env": {
    "RN_METRO_PORT_START": "9000",
    "RN_METRO_PORT_END": "9099"
  }
}
```

## Device Definitions

### Android Device Schema

Device definitions in `devbox.d/android/devices/*.json`:

```json
{
  "name": "pixel_api30",
  "api": 30,
  "device": "pixel",
  "tag": "google_apis",
  "preferred_abi": "x86_64"
}
```

- `name` - Device identifier (string, required)
- `api` - Android API level (number, required)
- `device` - AVD device profile ID (string, required)
- `tag` - System image tag (string, optional)
  - Valid values: `google_apis`, `google_apis_playstore`, `play_store`, `aosp_atd`, `google_atd`
- `preferred_abi` - Preferred ABI (string, optional)
  - Valid values: `arm64-v8a`, `x86_64`, `x86`

### iOS Device Schema

Device definitions in `devbox.d/ios/devices/*.json`:

```json
{
  "name": "iPhone 15 Pro",
  "runtime": "17.5"
}
```

- `name` - Simulator display name (string, required)
- `runtime` - iOS version (string, required)

### Semantic Device Names

Convention for min/max device definitions:

- `min.json` - Minimum supported platform version
- `max.json` - Maximum/latest supported platform version

Example Android `min.json`:
```json
{
  "name": "min",
  "api": 21,
  "device": "pixel",
  "tag": "google_apis"
}
```

Example iOS `max.json`:
```json
{
  "name": "max",
  "runtime": "18.0"
}
```

## Lock Files

### Android Lock File

Generated at `devbox.d/android/devices/devices.lock` by `android.sh devices eval`.

Format (plain text):
```
device_name:checksum
min:abc123def456
max:789ghi012jkl
```

### iOS Lock File

Generated at `devbox.d/ios/devices/devices.lock` by `ios.sh devices eval`.

Format (JSON):
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

Lock files should be committed to version control to optimize CI builds by limiting which SDK versions are evaluated.

## Regenerating Environment

The `.devbox/virtenv/` directory is temporary and auto-regenerated. After modifying plugin configurations or when the virtenv is stale:

```bash
devbox shell  # Regenerates virtenv
```

Or force sync without entering shell:

```bash
devbox run sync  # If sync script is defined
```

## See Also

- [Android Reference](android.md) - Complete Android API reference
- [iOS Reference](ios.md) - Complete iOS API reference
- [React Native Reference](react-native.md) - Complete React Native API reference
- [Plugin Conventions](../project/CONVENTIONS.md) - Plugin development patterns
- [CLAUDE.md](../../CLAUDE.md) - Repository overview and development rules
