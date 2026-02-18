# Environment Variables Reference

This document provides an exhaustive reference of all environment variables used across the Android, iOS, and React Native plugins. All variables are defined in the respective `plugin.json` files and can be overridden in project `devbox.json` files.

## Table of Contents

- [Android Plugin Variables](#android-plugin-variables)
- [iOS Plugin Variables](#ios-plugin-variables)
- [React Native Plugin Variables](#react-native-plugin-variables)
- [Shared Variables](#shared-variables)
- [Runtime-Only Variables](#runtime-only-variables)
- [Override Patterns](#override-patterns)
- [Validation](#validation)
- [Best Practices](#best-practices)

## Android Plugin Variables

### ANDROID_USER_HOME

**Plugin:** Android

**Default:** `{{ .Virtenv }}/android`

**Description:** Root directory for Android user configuration. Overrides the default `~/.android` location to enable project-local, reproducible Android environments.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_USER_HOME": "/custom/path/android"
  }
}
```

### ANDROID_AVD_HOME

**Plugin:** Android

**Default:** `{{ .Virtenv }}/android/avd`

**Description:** Directory where Android Virtual Device (AVD) configurations and data are stored. Overrides the default `~/.android/avd` location to keep AVDs project-local.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_AVD_HOME": "/custom/path/avd"
  }
}
```

### ANDROID_EMULATOR_HOME

**Plugin:** Android

**Default:** `{{ .Virtenv }}/android`

**Description:** Directory where emulator configuration files are stored. Overrides the default `~/.android` location.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_EMULATOR_HOME": "/custom/path/emulator"
  }
}
```

### ANDROID_CONFIG_DIR

**Plugin:** Android

**Default:** `{{ .DevboxDir }}`

**Description:** Directory containing Android plugin configuration files, including device definitions and flake configuration. Typically `devbox.d/android`.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_CONFIG_DIR": "custom-config"
  }
}
```

### ANDROID_DEVICES_DIR

**Plugin:** Android

**Default:** `{{ .DevboxDir }}/devices`

**Description:** Directory containing Android device definition JSON files. Device definitions specify emulator configurations (API level, device profile, system image tag, ABI).

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_DEVICES_DIR": "custom-devices"
  }
}
```

### ANDROID_DEVICES

**Plugin:** Android, React Native

**Default:** `""` (empty string, evaluates all devices)

**Description:** Comma-separated list of device names to evaluate. When empty, all device definitions in `ANDROID_DEVICES_DIR` are evaluated. Used to limit which devices are included in the Nix flake evaluation, optimizing CI/CD performance.

**Example:**
```bash
# Set in devbox.json to only evaluate specific devices
{
  "env": {
    "ANDROID_DEVICES": "min,max"
  }
}
```

### ANDROID_SCRIPTS_DIR

**Plugin:** Android

**Default:** `{{ .Virtenv }}/scripts`

**Description:** Directory containing runtime scripts for the Android plugin. Includes CLI entry points, domain operations, and utility functions.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_SCRIPTS_DIR": "/custom/scripts"
  }
}
```

### ANDROID_RUNTIME_DIR

**Plugin:** Android

**Default:** `{{ .Virtenv }}`

**Description:** Base runtime directory for the Android plugin. Used as the root for temporary runtime files and state.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_RUNTIME_DIR": "/custom/runtime"
  }
}
```

### ANDROID_LOCAL_SDK

**Plugin:** Android

**Default:** `"0"`

**Valid Values:** `"0"` (use Nix SDK), `"1"` (use local SDK)

**Description:** Controls whether to use the Android SDK from Nix flake or a locally installed SDK. When set to `"1"`, the plugin expects `ANDROID_SDK_ROOT` to point to an existing local SDK installation.

**Example:**
```bash
# Set in devbox.json to use local SDK
{
  "env": {
    "ANDROID_LOCAL_SDK": "1",
    "ANDROID_SDK_ROOT": "/usr/local/android-sdk"
  }
}
```

### ANDROID_COMPILE_SDK

**Plugin:** Android, React Native

**Default:** `"36"` (Android), `"35"` (React Native)

**Description:** Android SDK API level used for compilation. Corresponds to the `compileSdkVersion` in Android projects.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_COMPILE_SDK": "34"
  }
}
```

### ANDROID_TARGET_SDK

**Plugin:** Android, React Native

**Default:** `"36"` (Android), `"35"` (React Native)

**Description:** Android SDK API level targeted by the application. Corresponds to the `targetSdkVersion` in Android projects.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_TARGET_SDK": "34"
  }
}
```

### ANDROID_DEFAULT_DEVICE

**Plugin:** Android

**Default:** `"max"`

**Description:** Name of the default device to use when no device is explicitly specified. Must match a device definition file name (without `.json` extension) in `ANDROID_DEVICES_DIR`.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_DEFAULT_DEVICE": "pixel_api30"
  }
}
```

### ANDROID_SYSTEM_IMAGE_TAG

**Plugin:** Android

**Default:** `"google_apis"`

**Valid Values:** `"google_apis"`, `"google_apis_playstore"`, `"default"`, `"android-wear"`, `"android-tv"`

**Description:** System image tag/flavor for Android emulators. Determines which system image variant is used when creating AVDs.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_SYSTEM_IMAGE_TAG": "google_apis_playstore"
  }
}
```

### ANDROID_BUILD_TOOLS_VERSION

**Plugin:** Android, React Native

**Default:** `"36.1.0"` (Android), `"35.0.0"` (React Native)

**Description:** Version of Android Build Tools to include in the SDK. Build Tools include aapt, aidl, dx, and other build-related utilities.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_BUILD_TOOLS_VERSION": "34.0.0"
  }
}
```

### ANDROID_INCLUDE_NDK

**Plugin:** Android, React Native

**Default:** `"false"` (Android), `"true"` (React Native)

**Valid Values:** `"true"`, `"false"`

**Description:** Controls whether the Android NDK (Native Development Kit) is included in the SDK. Required for projects with native C/C++ code.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_INCLUDE_NDK": "true"
  }
}
```

### ANDROID_NDK_VERSION

**Plugin:** Android, React Native

**Default:** `"27.0.12077973"` (Android), `"29.0.14206865"` (React Native)

**Description:** Version of the Android NDK to include when `ANDROID_INCLUDE_NDK` is `"true"`. NDK versions follow a specific versioning scheme.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_NDK_VERSION": "26.1.10909125"
  }
}
```

### ANDROID_INCLUDE_CMAKE

**Plugin:** Android, React Native

**Default:** `"false"` (Android), `"true"` (React Native)

**Valid Values:** `"true"`, `"false"`

**Description:** Controls whether CMake is included in the SDK. CMake is used for building native C/C++ code in Android projects.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_INCLUDE_CMAKE": "true"
  }
}
```

### ANDROID_CMAKE_VERSION

**Plugin:** Android, React Native

**Default:** `"3.22.1"` (Android), `"4.1.2"` (React Native)

**Description:** Version of CMake to include when `ANDROID_INCLUDE_CMAKE` is `"true"`.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_CMAKE_VERSION": "3.28.0"
  }
}
```

### ANDROID_CMDLINE_TOOLS_VERSION

**Plugin:** Android

**Default:** `"19.0"`

**Description:** Version of Android Command Line Tools to include in the SDK. Command Line Tools include sdkmanager, avdmanager, and other SDK management utilities.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_CMDLINE_TOOLS_VERSION": "18.0"
  }
}
```

### ANDROID_DISABLE_SNAPSHOTS

**Plugin:** Android

**Default:** `"0"`

**Valid Values:** `"0"` (snapshots enabled), `"1"` (snapshots disabled)

**Description:** Controls whether emulator snapshots are disabled. When set to `"1"`, the emulator starts with the `-no-snapshot` flag, ensuring a clean boot every time.

**Example:**
```bash
# Set in devbox.json to disable snapshots
{
  "env": {
    "ANDROID_DISABLE_SNAPSHOTS": "1"
  }
}
```

### ANDROID_SKIP_SETUP

**Plugin:** Android

**Default:** `"0"`

**Valid Values:** `"0"` (allow downloads), `"1"` (skip downloads)

**Description:** Controls whether the plugin should skip downloading SDK components. When set to `"1"`, the plugin assumes all required SDK components are already installed.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "ANDROID_SKIP_SETUP": "1"
  }
}
```

## iOS Plugin Variables

### IOS_CONFIG_DIR

**Plugin:** iOS

**Default:** `{{ .DevboxDir }}`

**Description:** Directory containing iOS plugin configuration files, including device definitions. Typically `devbox.d/ios`.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "IOS_CONFIG_DIR": "custom-config"
  }
}
```

### IOS_DEVICES_DIR

**Plugin:** iOS

**Default:** `{{ .DevboxDir }}/devices`

**Description:** Directory containing iOS device definition JSON files. Device definitions specify simulator configurations (device name, iOS runtime).

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "IOS_DEVICES_DIR": "custom-devices"
  }
}
```

### IOS_DEVICES

**Plugin:** iOS, React Native

**Default:** `""` (empty string, evaluates all devices)

**Description:** Comma-separated list of device names to evaluate. When empty, all device definitions in `IOS_DEVICES_DIR` are evaluated. Used to limit which devices are validated and synced.

**Example:**
```bash
# Set in devbox.json to only evaluate specific devices
{
  "env": {
    "IOS_DEVICES": "min,max"
  }
}
```

### IOS_SCRIPTS_DIR

**Plugin:** iOS

**Default:** `{{ .Virtenv }}/scripts`

**Description:** Directory containing runtime scripts for the iOS plugin. Includes CLI entry points, domain operations, and utility functions.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "IOS_SCRIPTS_DIR": "/custom/scripts"
  }
}
```

### IOS_DEFAULT_DEVICE

**Plugin:** iOS

**Default:** `"max"`

**Description:** Name of the default device to use when no device is explicitly specified. Must match a device definition file name (without `.json` extension) in `IOS_DEVICES_DIR`.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "IOS_DEFAULT_DEVICE": "iphone15"
  }
}
```

### IOS_DEFAULT_RUNTIME

**Plugin:** iOS

**Default:** `""` (empty string, auto-detect latest runtime)

**Description:** Default iOS runtime version to use when creating simulators. When empty, the plugin automatically selects the latest available runtime. Format: `"17.5"`, `"18.0"`, etc.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "IOS_DEFAULT_RUNTIME": "17.5"
  }
}
```

### IOS_DEVELOPER_DIR

**Plugin:** iOS

**Default:** `""` (empty string, auto-detect)

**Description:** Path to the Xcode Developer directory. When empty, the plugin uses `xcode-select -p` to discover the active Xcode installation. Overrides automatic Xcode discovery.

**Example:**
```bash
# Set in devbox.json to use specific Xcode version
{
  "env": {
    "IOS_DEVELOPER_DIR": "/Applications/Xcode-15.4.app/Contents/Developer"
  }
}
```

### IOS_DOWNLOAD_RUNTIME

**Plugin:** iOS

**Default:** `"1"`

**Valid Values:** `"0"` (do not auto-download), `"1"` (auto-download)

**Description:** Controls whether the plugin automatically downloads iOS simulator runtimes that are not installed. When set to `"0"`, the plugin will fail if required runtimes are missing.

**Example:**
```bash
# Set in devbox.json to disable auto-download
{
  "env": {
    "IOS_DOWNLOAD_RUNTIME": "0"
  }
}
```

### IOS_XCODE_ENV_PATH

**Plugin:** iOS

**Default:** `""` (empty string, auto-detect)

**Description:** Path to the Xcode environment setup script. When empty, the plugin automatically discovers the correct path. Used internally for caching Xcode environment variables.

**Example:**
```bash
# Set in devbox.json (advanced usage)
{
  "env": {
    "IOS_XCODE_ENV_PATH": "/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
  }
}
```

## React Native Plugin Variables

The React Native plugin inherits all Android and iOS variables (see above sections) and adds the following React Native-specific variables.

### REACT_NATIVE_CONFIG_DIR

**Plugin:** React Native

**Default:** `{{ .DevboxDir }}`

**Description:** Directory containing React Native plugin configuration files. Typically `devbox.d`.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "REACT_NATIVE_CONFIG_DIR": "rn-config"
  }
}
```

### REACT_NATIVE_VIRTENV

**Plugin:** React Native

**Default:** `{{ .Virtenv }}`

**Description:** Base virtual environment directory for React Native plugin. Used for storing Metro bundler state, cache, and runtime files.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "REACT_NATIVE_VIRTENV": "/custom/virtenv"
  }
}
```

### REACT_NATIVE_SCRIPTS_DIR

**Plugin:** React Native

**Default:** `{{ .Virtenv }}/scripts`

**Description:** Directory containing runtime scripts for the React Native plugin, including Metro bundler management scripts.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "REACT_NATIVE_SCRIPTS_DIR": "/custom/scripts"
  }
}
```

### REACT_NATIVE_WEB_BUILD_PATH

**Plugin:** React Native

**Default:** `"web/build"`

**Description:** Output directory path for React Native Web builds. Used by web build scripts to determine where to place compiled web assets.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "REACT_NATIVE_WEB_BUILD_PATH": "dist/web"
  }
}
```

### METRO_CACHE_DIR

**Plugin:** React Native

**Default:** `{{ .Virtenv }}/metro/cache`

**Description:** Directory where Metro bundler caches compiled JavaScript bundles. Keeping this project-local ensures cache isolation between projects.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "METRO_CACHE_DIR": "node_modules/.cache/metro"
  }
}
```

### RN_METRO_PORT_START

**Plugin:** React Native

**Default:** `"8091"`

**Description:** Starting port number for automatic Metro port allocation. When a port is in use, the plugin increments from this value until finding an available port.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "RN_METRO_PORT_START": "9000"
  }
}
```

### RN_METRO_PORT_END

**Plugin:** React Native

**Default:** `"8199"`

**Description:** Ending port number for automatic Metro port allocation. The plugin searches for available ports between `RN_METRO_PORT_START` and this value.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "RN_METRO_PORT_END": "9099"
  }
}
```

## Shared Variables

### REPORTS_DIR

**Plugins:** Android, iOS, React Native

**Default:** `"reports"`

**Description:** Base directory for test reports, logs, and other output artifacts. Used by test scripts and CI/CD workflows to store test results, emulator logs, and debugging information. Subdirectories include `logs/`, `results/`, and `coverage/`.

**Example:**
```bash
# Set in devbox.json
{
  "env": {
    "REPORTS_DIR": "build/reports"
  }
}
```

**Derived Variables:**
- `TEST_LOGS_DIR`: Defaults to `${REPORTS_DIR}/logs`
- `TEST_RESULTS_DIR`: Defaults to `${REPORTS_DIR}/results`

## Runtime-Only Variables

The following variables are set dynamically by the plugins at runtime and are not configured in `plugin.json`. They are included here for reference.

### ANDROID_SDK_ROOT

**Plugin:** Android

**Set By:** Nix flake evaluation or `ANDROID_LOCAL_SDK=1` user configuration

**Description:** Path to the Android SDK root directory. Automatically set by the Nix flake when `ANDROID_LOCAL_SDK=0`, or must be provided by the user when `ANDROID_LOCAL_SDK=1`.

### TEST_LOGS_DIR

**Plugins:** Android, iOS, React Native

**Set By:** Plugin scripts at runtime

**Default:** `${REPORTS_DIR}/logs`

**Description:** Directory for storing test execution logs. Used by logging functions to write structured log output.

### TEST_RESULTS_DIR

**Plugins:** Android, iOS, React Native

**Set By:** Plugin scripts at runtime

**Default:** `${REPORTS_DIR}/results`

**Description:** Directory for storing test results and artifacts. Used by test scripts to write JUnit XML, screenshots, and other test outputs.

### NODE_BINARY

**Plugin:** React Native

**Set By:** React Native plugin init hook

**Description:** Absolute path to the Node.js binary used by React Native. Set automatically by the plugin to ensure the correct Node version is used by Metro and React Native CLI.

## Override Patterns

Environment variables can be overridden at multiple levels:

### 1. Project-Level Override

Set in project's `devbox.json`:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/android"],
  "env": {
    "ANDROID_DEFAULT_DEVICE": "pixel_api30",
    "ANDROID_DEVICES": "min,pixel_api30,max"
  }
}
```

### 2. Shell-Level Override

Set for a single command execution:

```bash
ANDROID_DEFAULT_DEVICE=pixel_api28 devbox run start:emu
```

### 3. Script-Level Override

Set in `devbox.json` script definitions:

```json
{
  "shell": {
    "scripts": {
      "test-min": "ANDROID_DEFAULT_DEVICE=min devbox run start:app"
    }
  }
}
```

## Validation

Some variables are validated at runtime:

- **ANDROID_DEVICES** and **IOS_DEVICES**: Device names must match existing device definition files
- **ANDROID_DEFAULT_DEVICE** and **IOS_DEFAULT_DEVICE**: Must match an existing device definition
- **ANDROID_LOCAL_SDK**: When set to `"1"`, requires valid `ANDROID_SDK_ROOT`
- **Port ranges**: `RN_METRO_PORT_START` must be less than `RN_METRO_PORT_END`

Validation warnings are non-blocking and provide actionable fix commands.

## Best Practices

1. **Use default device names**: Stick with `min.json` and `max.json` for minimum and maximum supported versions
2. **Limit device evaluation in CI**: Set `ANDROID_DEVICES` and `IOS_DEVICES` to only required devices to optimize CI performance
3. **Keep cache and state project-local**: Use default paths for `ANDROID_AVD_HOME`, `ANDROID_USER_HOME`, and `METRO_CACHE_DIR`
4. **Pin SDK versions in CI**: Explicitly set `ANDROID_COMPILE_SDK`, `ANDROID_BUILD_TOOLS_VERSION`, etc. for reproducible builds
5. **Override at project level**: Set environment variables in `devbox.json` rather than exporting them globally

## See Also

- [Android Plugin Reference](android.md)
- [iOS Plugin Reference](ios.md)
- [React Native Plugin Reference](react-native.md)
- [Configuration Guide](../guides/configuration.md)
