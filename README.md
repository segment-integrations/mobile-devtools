# Devbox Plugins for Mobile Development

Reproducible, project-local development environments for Android, iOS, and React Native using [Devbox](https://www.jetify.com/devbox).

## Quick Start

```bash
# Install devbox (if you haven't already)
curl -fsSL https://get.jetify.com/devbox | bash

# Initialize devbox in your project
devbox init
```

Replace the contents of your `devbox.json` with the Android plugin:

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

> **Note:** Plugins are added via `include` in `devbox.json`, not with `devbox add`. The plugin provides the Android SDK, emulator, and device management tools. You add your own build tooling (JDK, Gradle) as packages.

```bash
# Enter development environment (downloads SDK on first run)
devbox shell

# List available devices
devbox run android.sh devices list

# Start the default emulator
devbox run start:emu
```

**New to devbox-plugins?** Check out the [Quick Start Guide](wiki/guides/quick-start.md) for a complete walkthrough including how to set up build and deploy scripts.

## Features

- **Project-Local State** - All emulators, simulators, and caches stay in your project directory
- **Reproducible Environments** - Lock files ensure consistent SDK versions across machines
- **No Global Pollution** - Won't touch `~/.android`, `~/Library/Developer`, or other global state
- **Parallel Execution** - Run multiple test suites simultaneously with `--pure` isolation
- **Device-Driven Configuration** - Define devices as JSON, sync AVDs/simulators declaratively
- **CI/CD Optimized** - Device filtering and platform skipping for fast CI builds

## Plugins

### Android Plugin

Nix-managed Android SDK with AVD management.

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/android"]
}
```

**Guides:** [Android Guide](wiki/guides/android-guide.md) | [Cheatsheet](wiki/guides/cheatsheets/android.md)
**Reference:** [Android API](wiki/reference/android.md)

### iOS Plugin

Xcode toolchain integration with iOS Simulator management (macOS only).

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/ios"]
}
```

**Guides:** [iOS Guide](wiki/guides/ios-guide.md) | [Cheatsheet](wiki/guides/cheatsheets/ios.md)
**Reference:** [iOS API](wiki/reference/ios.md)

### React Native Plugin

Composition layer over Android and iOS with Metro bundler management.

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/react-native"]
}
```

**Guides:** [React Native Guide](wiki/guides/react-native-guide.md) | [Cheatsheet](wiki/guides/cheatsheets/react-native.md)
**Reference:** [React Native API](wiki/reference/react-native.md)

## Documentation

### For Users

- **[Quick Start](wiki/guides/quick-start.md)** - Set up your first project
- **[Device Management](wiki/guides/device-management.md)** - Managing emulators and simulators
- **[Testing Guide](wiki/guides/testing.md)** - Testing strategies and best practices
- **[Troubleshooting](wiki/guides/troubleshooting.md)** - Common issues and solutions
- **[Cheatsheets](wiki/guides/cheatsheets/)** - One-page quick references

### For Contributors

- **[Contributing Guide](wiki/project/CONTRIBUTING.md)** - How to contribute
- **[Architecture](wiki/project/ARCHITECTURE.md)** - Project structure and design
- **[Testing](wiki/project/TESTING.md)** - Testing infrastructure
- **[CI/CD](wiki/project/CI-CD.md)** - Continuous integration

**Full documentation:** [Wiki Home](wiki/README.md)

## Examples

The repository includes example projects demonstrating full workflows including build scripts, deploy commands, and E2E test suites:

- **[examples/android](examples/android/)** - Minimal Android app with Gradle build
- **[examples/ios](examples/ios/)** - Swift package with xcodebuild
- **[examples/react-native](examples/react-native/)** - React Native app with Android, iOS, and Web targets

These examples show how to wire up your own build and deploy scripts on top of the plugin-provided device and emulator management.

## Plugin-Provided Commands

The plugins provide device management, emulator/simulator control, and diagnostics. Build and deploy commands are project-specific — you define them in your own `devbox.json` (see the [Quick Start Guide](wiki/guides/quick-start.md) or the [examples](examples/) for patterns).

```bash
# Android emulator
devbox run start:emu [device]   # Start Android emulator
devbox run stop:emu             # Stop emulator
devbox run reset:emu            # Reset emulator state

# iOS simulator
devbox run start:sim [device]   # Start iOS simulator
devbox run stop:sim             # Stop simulator

# Device management
devbox run android.sh devices list
devbox run android.sh devices create mydevice --api 30 --device pixel
devbox run ios.sh devices list
devbox run ios.sh devices create mydevice --runtime 18.0

# Diagnostics
devbox run doctor               # Check environment health
devbox run verify:setup         # Quick verification
```

## Requirements

- **[Devbox](https://www.jetify.com/devbox)** - Install with `curl -fsSL https://get.jetify.com/devbox | bash`
- **macOS** - Required for iOS plugin (Xcode required)
- **Linux** - Supported for Android and React Native (Android only)

## Support

- **Questions?** Check [Troubleshooting](wiki/guides/troubleshooting.md)
- **Found a bug?** [Open an issue](https://github.com/segment-integrations/devbox-plugins/issues)
- **Want to contribute?** Read the [Contributing Guide](wiki/project/CONTRIBUTING.md)
