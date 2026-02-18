# Quick Start Guide

Set up a project-local Android or iOS development environment from scratch.

## Prerequisites

Install [Devbox](https://www.jetify.com/devbox/docs/installing_devbox/) if you haven't already:

```sh
curl -fsSL https://get.jetify.com/devbox | bash
```

Devbox handles downloading all build tools (JDK, Gradle, Xcode CLI tools, etc.) so you don't need to install them separately.

## Choose Your Platform

- **[Android](#android-quickstart)** - Native Android development with emulators
- **[iOS](#ios-quickstart)** - Native iOS development with simulators (macOS only)
- **[React Native](#react-native-quickstart)** - Cross-platform mobile development

---

## Android Quickstart

### 1. Initialize Your Project

In your existing Android project directory:

```sh
devbox init
```

Replace the contents of your `devbox.json` with:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/android"],
  "packages": {
    "jdk17": "latest",
    "gradle": "latest"
  }
}
```

The `include` line adds the Android plugin from GitHub. Devbox downloads the Android SDK, emulator, and device management tools automatically. The `packages` section adds JDK and Gradle for building your app.

> **Note:** Plugins are included via URL in `devbox.json`, not with `devbox add`. You cannot use `devbox add plugin:android`.

### 2. Enter the Development Environment

```sh
devbox shell
```

On first run, this downloads the Android SDK via Nix. Subsequent runs are fast. The SDK is stored project-locally — nothing is written to `~/.android`.

Two quick devbox concepts:
- `devbox shell` enters an interactive shell with all tools on your PATH
- `devbox run <script>` runs a single command or script from your `devbox.json`

### 3. List Available Devices

```sh
devbox run android.sh devices list
```

You'll see the two default device definitions:

```
medium_phone_api36  36  medium_phone  google_apis  {...}
pixel_api21         21  pixel         google_apis  {...}
```

These come from `min.json` and `max.json` in your `devbox.d/` directory, which is the devbox plugin configuration folder. The plugin creates a subdirectory there with a `devices/` folder containing these files (e.g., `devbox.d/<plugin-dir>/devices/min.json`). The filenames (`min`, `max`) are short nicknames you use in commands. The names shown in the listing (`medium_phone_api36`, `pixel_api21`) are the full AVD names defined inside each JSON file.

### 4. Start the Emulator

```sh
# Start the default device (max)
devbox run start:emu

# Or start a specific device by nickname
devbox run start:emu min
```

### 5. Add Build and Deploy Scripts

The plugin provides emulator and device management. Build and deploy commands are specific to your project, so you define them in your `devbox.json`. Add a `shell.scripts` section:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/android"],
  "packages": {
    "jdk17": "latest",
    "gradle": "latest"
  },
  "shell": {
    "scripts": {
      "build:android": [
        "gradle assembleDebug --info"
      ],
      "start:app": [
        "android.sh run ${1:-}"
      ]
    }
  }
}
```

The `${1:-}` syntax passes an optional argument through to the command. It means "use the first argument if provided, otherwise use nothing." This lets you run both `devbox run start:app` (uses the default device) and `devbox run start:app min` (targets a specific device).

Now you can build and deploy:

```sh
# Build the APK
devbox run build:android

# Build, install, and launch on the default device
devbox run start:app

# Or target a specific device by nickname
devbox run start:app min
```

The `android.sh run` command waits for the emulator to boot, then auto-detects, installs, and launches the APK. The app's package name is extracted from the APK automatically.

**How APK auto-detection works:** The `run` command searches your project for `.apk` files, skipping build caches like `.gradle/`, `build/intermediates/`, `node_modules/`, and `.devbox/`. If your build outputs the APK to a standard location (e.g., `app/build/outputs/apk/`), it will be found automatically.

If auto-detection picks the wrong APK or you want to be explicit, set `ANDROID_APP_APK` in your `devbox.json` env. This accepts a path or glob pattern relative to your project root:

```json
{
  "env": {
    "ANDROID_APP_APK": "app/build/outputs/apk/debug/app-debug.apk"
  }
}
```

### 6. Stop the Emulator

```sh
devbox run stop:emu
```

### Next Steps

- Check out the [Android example project](../../examples/android/) for a complete working setup with build scripts and E2E test suites
- [Android Guide](android-guide.md) - Complete Android development workflow
- [Device Management](device-management.md) - Create custom device configurations
- [Troubleshooting](troubleshooting.md) - Common issues and solutions

---

## iOS Quickstart

Requires macOS with [Xcode](https://apps.apple.com/app/xcode/id497799835) installed.

### 1. Initialize Your Project

In your existing iOS project directory:

```sh
devbox init
```

Replace the contents of your `devbox.json` with:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/ios"]
}
```

The `include` line adds the iOS plugin from GitHub. The plugin discovers your Xcode installation, manages simulators, and auto-detects your Xcode project, `.app` bundle, and bundle ID when deploying.

> **Note:** Plugins are included via URL in `devbox.json`, not with `devbox add`.

### 2. Enter the Development Environment

```sh
devbox shell
```

The plugin automatically discovers Xcode and configures iOS development tools. Two quick devbox concepts:
- `devbox shell` enters an interactive shell with all tools on your PATH
- `devbox run <script>` runs a single command or script from your `devbox.json`

### 3. List Available Devices

```sh
devbox run ios.sh devices list
```

You'll see the two default device definitions:

```
iPhone 17   26.2
iPhone 13   15.4
```

These come from `min.json` (iOS 15.4) and `max.json` (iOS 26.2) in your `devbox.d/` directory, which is the devbox plugin configuration folder. The plugin creates a subdirectory there with a `devices/` folder containing these files (e.g., `devbox.d/<plugin-dir>/devices/min.json`). The filenames (`min`, `max`) are short nicknames you use in commands. The names shown (`iPhone 13`, `iPhone 17`) are the simulator display names defined inside each JSON file.

### 4. Start the Simulator

```sh
# Start the default device (max)
devbox run start:sim

# Or start a specific device by nickname
devbox run start:sim min
```

### 5. Add Build and Deploy Scripts

The plugin provides simulator and device management. Build and deploy commands are specific to your Xcode project, so you define them in your `devbox.json`. Add a `shell.scripts` section:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/ios"],
  "shell": {
    "scripts": {
      "build:ios": [
        "env -u LD -u LDFLAGS -u NIX_LDFLAGS -u NIX_CFLAGS_COMPILE -u NIX_CFLAGS_LINK xcodebuild -project MyApp.xcodeproj -scheme MyApp -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData build"
      ],
      "start:app": [
        "ios.sh run ${1:-}"
      ]
    }
  }
}
```

As with the Android example, `${1:-}` passes an optional device nickname through (e.g., `devbox run start:app min`). If omitted, the default device is used.

Now you can build and deploy:

```sh
# Build the app
devbox run build:ios

# Start simulator, install, and launch
devbox run start:app
```

**How app auto-detection works:** The `ios.sh run` command starts the simulator, runs your `build:ios` script, then auto-detects the `.app` bundle. It uses this precedence chain:

1. Query `xcodebuild -showBuildSettings` for the built products path (works when your project has an `.xcodeproj` or `.xcworkspace` in the project root)
2. Recursive search of the project directory for `.app` bundles, skipping `Pods/`, `.build/`, `node_modules/`, `.devbox/`, and similar directories

The bundle ID is extracted automatically from the `.app`'s `Info.plist`.

If auto-detection picks the wrong `.app` or your project structure is non-standard, set `IOS_APP_ARTIFACT` in your `devbox.json` env. This accepts a path or glob pattern relative to your project root:

```json
{
  "env": {
    "IOS_APP_ARTIFACT": "DerivedData/Build/Products/Debug-iphonesimulator/MyApp.app"
  }
}
```

Use `-derivedDataPath DerivedData` in your xcodebuild command to keep build output project-local.

### 6. Stop the Simulator

```sh
devbox run stop:sim
```

### Next Steps

- Check out the [iOS example project](../../examples/ios/) for a complete working setup with build scripts and E2E test suites
- [iOS Guide](ios-guide.md) - Complete iOS development workflow
- [Device Management](device-management.md) - Create custom device configurations
- [Troubleshooting](troubleshooting.md) - Common issues and solutions

---

## React Native Quickstart

The React Native plugin combines the Android and iOS plugins for cross-platform development.

### 1. Initialize Your Project

In your existing React Native project directory:

```sh
devbox init
```

Replace the contents of your `devbox.json` with:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/react-native"],
  "packages": [
    "nodejs@20",
    "watchman@latest",
    "jdk17@latest",
    "gradle@latest"
  ]
}
```

The React Native plugin automatically includes both the Android and iOS plugins. APK and `.app` paths are auto-detected at runtime.

> **Note:** Plugins are included via URL in `devbox.json`, not with `devbox add`.

### 2. Enter the Development Environment

```sh
devbox shell
```

This sets up both Android SDK and iOS tools (iOS requires macOS with Xcode).

### 3. Add Build and Run Scripts

The plugin provides emulator/simulator control, device management, and Metro bundler management. Build and deploy scripts are specific to your project. Add them to your `devbox.json`:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/react-native"],
  "packages": [
    "nodejs@20",
    "watchman@latest",
    "jdk17@latest",
    "gradle@latest"
  ],
  "shell": {
    "scripts": {
      "build:android": [
        "npm install",
        "cd android && gradle assembleDebug"
      ],
      "build:ios": [
        "npm install",
        "cd ios && pod install --repo-update",
        "env -u LD -u LDFLAGS -u NIX_LDFLAGS -u NIX_CFLAGS_COMPILE -u NIX_CFLAGS_LINK xcodebuild -workspace ios/MyApp.xcworkspace -scheme MyApp -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData -quiet build"
      ]
    }
  }
}
```

### 4. Run on Android

```sh
# Start emulator
devbox run start:emu

# Build and install (using your custom script)
devbox run build:android

# Stop when done
devbox run stop:emu
```

### 5. Run on iOS (macOS only)

```sh
# Start simulator
devbox run start:sim

# Build and install (using your custom script)
devbox run build:ios

# Stop when done
devbox run stop:sim
```

### Next Steps

- Check out the [React Native example project](../../examples/react-native/) for a complete working setup with Metro orchestration, process-compose test suites, and multi-platform builds
- [React Native Guide](react-native-guide.md) - Complete React Native workflow
- [Device Management](device-management.md) - Configure emulators and simulators
- [Testing Guide](testing.md) - Set up automated testing

---

## Common Plugin Commands

These commands are provided by the plugins and available in all projects:

```sh
# Device management
devbox run android.sh devices list       # List Android devices
devbox run android.sh devices create pixel_api30 --api 30 --device pixel
devbox run ios.sh devices list           # List iOS devices
devbox run ios.sh devices create iphone15 --runtime 17.5

# Regenerate lock file after device changes
devbox run android.sh devices eval
devbox run ios.sh devices eval

# Sync AVDs/simulators to match device definitions
devbox run android.sh devices sync
devbox run ios.sh devices sync

# View configuration
devbox run android.sh config show
devbox run ios.sh config show

# Diagnostics
devbox run doctor
devbox run verify:setup
```

### Configuration

Configure the plugins via environment variables in `devbox.json`:

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

---

## Getting Help

- **Reference Docs** - See [Android Reference](../reference/android.md), [iOS Reference](../reference/ios.md), or [React Native Reference](../reference/react-native.md)
- **Examples** - Explore `examples/{android|ios|react-native}/`
- **Issues** - [GitHub Issues](https://github.com/segment-integrations/devbox-plugins/issues)
- **Community** - [Devbox Discord](https://discord.gg/jetify)
