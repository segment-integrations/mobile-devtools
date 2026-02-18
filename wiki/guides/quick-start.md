# Quick Start Guide

Get up and running with Android, iOS, or React Native development in 5 minutes.

## Prerequisites

Install Devbox if you haven't already:

```sh
curl -fsSL https://get.jetify.com/devbox | bash
```

## Choose Your Platform

Pick your platform and follow the quickstart below:

- **[Android](#android-quickstart)** - Native Android development with emulators
- **[iOS](#ios-quickstart)** - Native iOS development with simulators (macOS only)
- **[React Native](#react-native-quickstart)** - Cross-platform mobile development

---

## Android Quickstart

### 1. Initialize Your Project

```sh
# Initialize devbox in your existing Android project
devbox init
```

Add the Android plugin to your `devbox.json`:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/android"],
  "packages": {
    "jdk17": "latest",
    "gradle": "latest"
  },
  "env": {
    "ANDROID_APP_APK": "app/build/outputs/apk/debug/app-debug.apk"
  }
}
```

Set `ANDROID_APP_APK` to the path where your build outputs the APK. The app's package name (`ANDROID_APP_ID`) is auto-detected from the APK at install time.

> **Note:** These are custom plugins hosted on GitHub, not built-in devbox plugins. You cannot use `devbox add plugin:android` — add the `include` URL to your `devbox.json` manually.

### 2. Enter the Development Environment

```sh
devbox shell
```

This installs the Android SDK, build tools, and emulator without touching your global `~/.android` directory.

### 3. List Available Devices

```sh
devbox run android.sh devices list
```

You'll see the default devices: `min` (API 21) and `max` (API 35).

### 4. Build and Run Your App

```sh
# Build, install, and launch on the default emulator
devbox run start

# Or specify a device
devbox run start max
```

This command:
- Starts the emulator
- Builds your APK
- Installs and launches the app

### 5. Stop the Emulator

```sh
devbox run stop:emu
```

### Next Steps

- [Android Guide](android-guide.md) - Complete Android development workflow
- [Device Management](device-management.md) - Create custom device configurations
- [Troubleshooting](troubleshooting.md) - Common issues and solutions

---

## iOS Quickstart

**Note:** Requires macOS with Xcode installed.

### 1. Initialize Your Project

```sh
# Initialize devbox in your existing iOS project
devbox init
```

Add the iOS plugin to your `devbox.json`:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/ios"],
  "env": {
    "IOS_APP_PROJECT": "MyApp.xcodeproj",
    "IOS_APP_SCHEME": "MyApp",
    "IOS_APP_BUNDLE_ID": "com.example.myapp",
    "IOS_APP_ARTIFACT": "DerivedData/Build/Products/Debug-iphonesimulator/MyApp.app"
  }
}
```

Use `-derivedDataPath DerivedData` in your `xcodebuild` command to keep build output project-local.

> **Note:** These are custom plugins hosted on GitHub, not built-in devbox plugins. Add the `include` URL to your `devbox.json` manually.

### 2. Enter the Development Environment

```sh
devbox shell
```

The plugin automatically discovers your Xcode installation and configures the iOS development tools.

### 3. List Available Devices

```sh
devbox run ios.sh devices list
```

You'll see the default devices: `min` (iOS 15.4) and `max` (iOS 26.2).

### 4. Build and Run Your App

```sh
# Build, install, and launch on the default simulator
devbox run start:ios

# Or specify a device
devbox run start:ios max
```

This command:
- Starts the simulator
- Builds your app
- Installs and launches it

### 5. Stop the Simulator

```sh
devbox run stop:sim
```

### Next Steps

- [iOS Guide](ios-guide.md) - Complete iOS development workflow
- [Device Management](device-management.md) - Create custom device configurations
- [Troubleshooting](troubleshooting.md) - Common issues and solutions

---

## React Native Quickstart

The React Native plugin combines Android and iOS plugins for cross-platform development.

### 1. Initialize Your Project

```sh
# Initialize devbox in your existing React Native project
devbox init
npm install  # or yarn
```

Add the React Native plugin to your `devbox.json`:

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
    "ANDROID_APP_APK": "android/app/build/outputs/apk/debug/app-debug.apk",
    "IOS_APP_PROJECT": "MyApp.xcodeproj",
    "IOS_APP_SCHEME": "MyApp",
    "IOS_APP_BUNDLE_ID": "com.example.myapp",
    "IOS_APP_ARTIFACT": "DerivedData/Build/Products/Debug-iphonesimulator/MyApp.app"
  }
}
```

> **Note:** These are custom plugins hosted on GitHub, not built-in devbox plugins. Add the `include` URL to your `devbox.json` manually.

### 2. Enter the Development Environment

```sh
devbox shell
```

This sets up both Android SDK and iOS tools (macOS only).

### 3. Run on Android

```sh
# Start emulator and build/run (uses process-compose)
devbox run start:android

# When done
devbox run stop:emu
```

### 4. Run on iOS (macOS only)

```sh
# Start simulator and build/run (uses process-compose)
devbox run start:ios

# When done
devbox run stop:sim
```

### Next Steps

- [React Native Guide](react-native-guide.md) - Complete React Native workflow
- [Device Management](device-management.md) - Configure emulators and simulators
- [Testing Guide](testing.md) - Set up automated testing

---

## Common Commands

### Device Management

```sh
# List devices
devbox run android.sh devices list  # Android
devbox run ios.sh devices list      # iOS

# Create a new device
devbox run android.sh devices create pixel_api30 --api 30 --device pixel
devbox run ios.sh devices create iphone15 --runtime 17.5

# Regenerate lock file after device changes
devbox run android.sh devices eval
devbox run ios.sh devices eval

# Sync AVDs/simulators to match device definitions
devbox run android.sh devices sync
devbox run ios.sh devices sync
```

### Configuration

Configuration is managed via environment variables in `devbox.json`:

```json
{
  "env": {
    "ANDROID_DEFAULT_DEVICE": "max",
    "ANDROID_DEVICES": "min,max",
    "IOS_DEFAULT_DEVICE": "max",
    "IOS_DEVICES": "min,max"
  }
}
```

View current configuration:

```sh
devbox run android.sh config show
devbox run ios.sh config show
```

### Build Commands

```sh
# Android
devbox run build                # Build APK
devbox run start                # Build, install, and launch app

# iOS
devbox run build                # Build app
devbox run start:ios            # Build, install, and launch on simulator
```

---

## Why Devbox for Mobile Development?

- **Project-local environments** - No global state pollution (`~/.android`, `~/Library/Developer`)
- **Reproducible builds** - Lock files ensure consistent SDK versions across team and CI
- **Version management** - Test against multiple Android API levels and iOS versions
- **Pure mode testing** - `devbox run --pure` creates isolated test environments
- **Fast CI** - Cached Nix derivations speed up builds

---

## Getting Help

- **Reference Docs** - See [Android Reference](../reference/android.md), [iOS Reference](../reference/ios.md), or [React Native Reference](../reference/react-native.md)
- **Examples** - Explore `examples/{android|ios|react-native}/`
- **Issues** - [GitHub Issues](https://github.com/segment-integrations/devbox-plugins/issues)
- **Community** - [Devbox Discord](https://discord.gg/jetify)
