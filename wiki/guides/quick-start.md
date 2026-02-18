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
# Clone the example or start from scratch
git clone https://github.com/jetify-com/devbox-plugins
cd devbox-plugins/examples/android

# Or initialize in your existing Android project
devbox init
devbox add plugin:android
```

### 2. Enter the Development Environment

```sh
devbox shell
```

This installs the Android SDK, build tools, and emulator without touching your global `~/.android` directory.

### 3. List Available Devices

```sh
devbox run android.sh devices list
```

You'll see the default devices: `min` (API 21) and `max` (API 36).

### 4. Build and Run Your App

```sh
# Build, install, and launch on the default emulator
devbox run start-android

# Or specify a device
devbox run start-android max
```

This command:
- Starts the emulator
- Builds your APK
- Installs and launches the app

### 5. Stop the Emulator

```sh
devbox run stop-emu
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
# Clone the example or start from scratch
git clone https://github.com/jetify-com/devbox-plugins
cd devbox-plugins/examples/ios

# Or initialize in your existing iOS project
devbox init
devbox add plugin:ios
```

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
# Clone the example
git clone https://github.com/jetify-com/devbox-plugins
cd devbox-plugins/examples/react-native

# Or initialize in your existing React Native project
devbox init
devbox add plugin:react-native
npm install  # or yarn
```

### 2. Enter the Development Environment

```sh
devbox shell
```

This sets up both Android SDK and iOS tools (macOS only).

### 3. Run on Android

```sh
# Start Metro bundler (in a separate terminal)
npx react-native start

# Build and run on Android emulator
devbox run start-android

# When done
devbox run stop-emu
```

### 4. Run on iOS (macOS only)

```sh
# Start Metro bundler (in a separate terminal)
npx react-native start

# Build and run on iOS simulator
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

# Select specific devices for evaluation
devbox run android.sh devices select min max
devbox run ios.sh devices select min max

# Regenerate lock file after device changes
devbox run android.sh devices eval
devbox run ios.sh devices eval
```

### Configuration

```sh
# View current configuration
devbox run android.sh config show
devbox run ios.sh config show

# Set default device
devbox run android.sh config set ANDROID_DEFAULT_DEVICE=max
# Or edit devbox.json directly:
# {
#   "env": {
#     "ANDROID_DEFAULT_DEVICE": "max",
#     "IOS_DEFAULT_DEVICE": "max"
#   }
# }
```

### Build Commands

```sh
# Android
devbox run build-android        # Build APK
devbox run gradle-clean         # Clean build artifacts

# iOS
devbox run build                # Build app
devbox run test                 # Run tests
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
- **Issues** - [GitHub Issues](https://github.com/jetify-com/devbox-plugins/issues)
- **Community** - [Devbox Discord](https://discord.gg/jetify)
