# Android Development Guide

A complete guide to Android development using the Devbox Android plugin. This guide covers setup, device management, development workflow, testing, and troubleshooting.

## What the Android Plugin Provides

The Android plugin enables reproducible Android development without touching global system state. It provides:

- **Project-local Android environment**: All Android user data (AVDs, emulator configs, adb keys) is stored in `.devbox/virtenv/`, never in `~/.android`
- **Reproducible SDK management**: Android SDK composed via Nix flake, ensuring consistent tooling across machines
- **Device management**: JSON-based device definitions with CLI commands for creating, updating, and managing AVDs
- **Emulator control**: Scripts for starting, stopping, and resetting emulators

The plugin does **not** provide build or deploy commands. Every project has different build tooling (Gradle, Bazel, custom scripts), so you define those in your own `devbox.json`. See [Adding Build Scripts](#adding-build-and-deploy-scripts) for patterns.

Pure shells with `devbox run --pure` guarantee isolated, reproducible execution without side effects.

## Setup and Installation

### Prerequisites

- [Devbox](https://www.jetify.com/devbox/docs/installing_devbox/) installed

Devbox handles downloading JDK, Gradle, and all other tools — you don't need to install them separately.

### Adding the Plugin to Your Project

Create or modify your `devbox.json` to include the Android plugin:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/android"],
  "packages": {
    "jdk17": "latest",
    "gradle": "latest"
  }
}
```

The `include` line adds the plugin. The `packages` section adds your build tooling. APK paths are auto-detected at runtime when you deploy.

### Initial Setup

Initialize the Devbox environment:

```bash
devbox shell
```

This command:
1. Downloads and installs the Android SDK via Nix
2. Creates device definitions in your devbox.d directory
3. Sets up runtime scripts
4. Configures environment variables for Android development

Verify the installation:

```bash
devbox run android.sh info
```

This displays resolved SDK information including SDK root, build tools version, and available devices.

## Device Management

Device definitions are JSON files that describe AVD configurations. Each plugin install creates a `devices/` directory inside your `devbox.d/` folder with default device files.

### Default Devices

The plugin includes two default devices:

- `min.json` - Minimum supported Android version (API 21, named `pixel_api21`)
- `max.json` - Latest Android version (API 36, named `medium_phone_api36`)

These files live in your `devbox.d/` directory, which is the devbox plugin configuration folder. The plugin creates a subdirectory there with a `devices/` folder containing them (e.g., `devbox.d/<plugin-dir>/devices/min.json`). The filenames (`min`, `max`) are short nicknames you use in commands. The `name` field inside each JSON file is the full AVD name that appears in device listings.

### Listing Devices

View all available device definitions:

```bash
devbox run android.sh devices list
```

Output shows device names, API levels, device profiles, and system image tags.

### Creating a New Device

Create a device with specific configuration:

```bash
devbox run android.sh devices create pixel_api28 \
  --api 28 \
  --device pixel \
  --tag google_apis \
  --abi x86_64
```

Parameters:
- `--api` (required): Android API level
- `--device` (required): AVD device profile (e.g., `pixel`, `pixel_xl`, `Nexus 5`)
- `--tag`: System image tag (`google_apis`, `google_apis_playstore`, `play_store`, `aosp_atd`, `google_atd`)
- `--abi`: Preferred ABI architecture (`x86_64`, `arm64-v8a`, `x86`)

### Viewing Device Details

Show configuration for a specific device:

```bash
devbox run android.sh devices show pixel_api28
```

### Updating a Device

Modify an existing device definition:

```bash
# Update API level
devbox run android.sh devices update pixel_api28 --api 29

# Rename device
devbox run android.sh devices update pixel_api28 --name pixel_api29

# Change system image tag
devbox run android.sh devices update pixel_api28 --tag google_apis_playstore
```

### Deleting a Device

Remove a device definition:

```bash
devbox run android.sh devices delete pixel_api28
```

### Selecting Devices for Evaluation

By default, the Android SDK flake evaluates all devices. To optimize evaluation time (especially in CI), set the `ANDROID_DEVICES` environment variable in your `devbox.json`:

```json
{
  "env": {
    "ANDROID_DEVICES": "min,max"
  }
}
```

Leave `ANDROID_DEVICES` unset or empty to evaluate all devices.

### Regenerating the Lock File

After creating, updating, or deleting devices, regenerate the lock file:

```bash
devbox run android.sh devices eval
```

The lock file (in your devices directory) optimizes CI builds by limiting which SDK versions are downloaded. Commit this file to version control.

### Syncing AVDs

Ensure local AVDs match device definitions:

```bash
devbox run android.sh devices sync
```

This creates or updates AVDs to match your JSON device definitions. Run this after modifying device files or pulling changes.

## Development Workflow

### Starting an Emulator

Start an Android emulator for testing:

```bash
# Start default device
devbox run start:emu

# Start specific device by nickname
devbox run start:emu pixel_api28

# Start with clean state (wipe data)
devbox run android.sh emulator start --pure pixel_api28
```

Without `--pure`, the emulator reuses existing state if already running (faster for development). With `--pure`, it always starts fresh with wiped data (reproducible for testing).

Set the default device in `devbox.json`:

```json
{
  "env": {
    "ANDROID_DEFAULT_DEVICE": "max"
  }
}
```

### Stopping the Emulator

Stop all running emulators:

```bash
devbox run stop:emu
```

### Resetting Emulator State

Reset AVD state (clears all data and app installations):

```bash
devbox run android.sh emulator reset
```

This is useful after Nix package updates or when you need a clean slate.

### Adding Build and Deploy Scripts

The plugin provides emulator and device management. Build and deploy commands are project-specific, so you define them in your `devbox.json`. Here's a typical setup:

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
        "android.sh build"
      ],
      "build:release": [
        "android.sh build --config Release"
      ],
      "start:app": [
        "android.sh run ${1:-}"
      ]
    }
  }
}
```

The `${1:-}` syntax passes an optional argument through to the command — it means "use the first argument if provided, otherwise use nothing." This lets you run `devbox run start:app` (default device) or `devbox run start:app min` (specific device).

With these scripts defined, you can:

```bash
# Build the APK
devbox run build:android

# Build, install, and launch on the emulator
devbox run start:app

# Run on a specific device
devbox run start:app min
```

**How APK auto-detection works:** The `android.sh run` command waits for the emulator to boot, then auto-detects the APK using this precedence chain:

1. `ANDROID_APP_APK` env var — if set, resolves the path/glob relative to project root
2. Recursive search of the project directory for `.apk` files, skipping `.gradle/`, `build/intermediates/`, `node_modules/`, and `.devbox/`
3. Recursive search of the current working directory (if different from project root)

The app's package name and launch activity are extracted from the APK automatically.

In most projects, step 2 finds the right APK with no configuration. If auto-detection picks the wrong APK (e.g., multiple build variants), set `ANDROID_APP_APK` explicitly:

```json
{
  "env": {
    "ANDROID_APP_APK": "app/build/outputs/apk/debug/app-debug.apk"
  }
}
```

See the [Android example project](../../examples/android/) for a complete working setup. The example project uses a local plugin path for development. If you use it as a template, change the `include` to the GitHub URL shown above.

### Complete Development Workflow Example

Typical development session:

```bash
# 1. Enter devbox shell
devbox shell

# 2. Start emulator
devbox run start:emu max

# 3. Build and run app (using your custom scripts)
devbox run build
devbox run start:app max

# 4. Make code changes, rebuild, and redeploy
devbox run build
devbox run start:app max

# 5. Stop emulator when done
devbox run stop:emu
```

## Testing

### Running E2E Tests

The [Android example project](../../examples/android/) includes E2E test infrastructure using process-compose. You can use it as a template for your own project.

Copy the example test suite:

```bash
cp -r examples/android/tests/ your-project/tests/
```

Add a test script to your `devbox.json`:

```json
{
  "shell": {
    "scripts": {
      "test:e2e": [
        "process-compose -f tests/test-suite.yaml --no-server --tui=${TEST_TUI:-false}"
      ]
    }
  }
}
```

### Deterministic Testing

For reproducible CI/CD testing, use pure mode:

```bash
TEST_PURE=1 devbox run test:e2e
```

This ensures:
- Fresh emulator with clean state
- No cached data from previous runs
- Emulator and app are stopped after tests

### Interactive Monitoring

Run tests with TUI for real-time monitoring:

```bash
TEST_TUI=true devbox run test:e2e
```

The TUI shows process status, logs, and resource usage during test execution.

### Test Configuration

Customize test behavior with environment variables:

```bash
# Set emulator boot timeout (seconds)
BOOT_TIMEOUT=120 devbox run test:e2e

# Run headless (no emulator GUI)
EMU_HEADLESS=1 devbox run test:e2e

# Enable debug logging
ANDROID_DEBUG=1 devbox run test:e2e
```

## Configuration Options

### Environment Variables

Configure the plugin by setting environment variables in `devbox.json`:

```json
{
  "env": {
    "ANDROID_DEFAULT_DEVICE": "max",
    "ANDROID_BUILD_TOOLS_VERSION": "36.1.0",
    "ANDROID_COMPILE_SDK": "36",
    "ANDROID_TARGET_SDK": "36"
  }
}
```

Key variables:
- `ANDROID_DEFAULT_DEVICE` - Default device when none specified
- `ANDROID_APP_APK` - Path or glob pattern for APK (empty = auto-detect)
- `ANDROID_BUILD_TOOLS_VERSION` - Build tools version
- `ANDROID_COMPILE_SDK` - Compile SDK version
- `ANDROID_TARGET_SDK` - Target SDK version

### Performance Optimization

#### Skip Downloads for Faster Initialization

In React Native projects or iOS-only contexts, skip Android SDK evaluation:

```json
{
  "env": {
    "ANDROID_SKIP_SETUP": "1"
  }
}
```

This speeds up shell initialization when you only need iOS tooling.

#### Use Local SDK

Use an existing local Android SDK instead of Nix-managed SDK:

```json
{
  "env": {
    "ANDROID_LOCAL_SDK": "1"
  }
}
```

Set `ANDROID_SDK_ROOT` to your local SDK path.

#### Select Specific Devices

Limit which devices are evaluated to reduce initialization time:

```json
{
  "env": {
    "ANDROID_DEVICES": "min,max"
  }
}
```

### Emulator Configuration

Customize emulator behavior:

```json
{
  "env": {
    "EMU_HEADLESS": "1",
    "EMU_PORT": "5554",
    "ANDROID_EMULATOR_PURE": "1",
    "ANDROID_DISABLE_SNAPSHOTS": "1"
  }
}
```

Options:
- `EMU_HEADLESS` - Run emulator without GUI window
- `EMU_PORT` - Preferred emulator port (default: 5554)
- `ANDROID_EMULATOR_PURE` - Always start fresh with clean state
- `ANDROID_DISABLE_SNAPSHOTS` - Disable snapshot boots, force cold boot

### Viewing Current Configuration

Display all configuration settings:

```bash
devbox run android.sh config show
```

Run `devbox shell` after changing `devbox.json` to apply the new values. To reset to defaults, remove the overrides from your `devbox.json`.

## Troubleshooting

### Emulator Won't Start

**Symptom**: Emulator fails to start or times out during boot.

**Solutions**:

1. Check if hardware acceleration is available:
   ```bash
   devbox run emulator -accel-check
   ```

2. Try starting with snapshot disabled:
   ```bash
   ANDROID_DISABLE_SNAPSHOTS=1 devbox run start:emu
   ```

3. Reset emulator state:
   ```bash
   devbox run android.sh emulator reset
   ```

4. Increase boot timeout:
   ```bash
   BOOT_TIMEOUT=180 devbox run start:emu
   ```

### APK Installation Fails

**Symptom**: Error installing APK on emulator.

**Solutions**:

1. Verify the APK exists (check your build output directory):
   ```bash
   find . -name '*.apk' -not -path '*/.gradle/*' -not -path '*/intermediates/*'
   ```

2. Check if app is already installed:
   ```bash
   adb shell pm list packages | grep your.package.name
   ```

3. Uninstall existing version:
   ```bash
   adb uninstall com.example.myapp
   ```

4. Check emulator is fully booted:
   ```bash
   adb shell getprop sys.boot_completed
   ```

### SDK Not Found

**Symptom**: Commands fail with "ANDROID_SDK_ROOT not set" or SDK tools not found.

**Solutions**:

1. Re-enter devbox shell to reload the environment:
   ```bash
   exit
   devbox shell
   ```

2. Verify SDK installation:
   ```bash
   devbox run android.sh info
   ```

### Lock File Checksum Mismatch

**Symptom**: Warning about lock file checksum not matching device definitions.

**Solution**:

Regenerate the lock file:
```bash
devbox run android.sh devices eval
```

Commit the updated lock file.

### Multiple Emulators Conflict

**Symptom**: Multiple emulators running on the same port.

**Solutions**:

1. Stop all emulators:
   ```bash
   devbox run stop:emu
   ```

2. Specify different ports for each emulator:
   ```bash
   EMU_PORT=5554 devbox run start:emu device1
   EMU_PORT=5556 devbox run start:emu device2
   ```

### Build Fails with SDK Version Errors

**Symptom**: Gradle build fails with "SDK Build Tools version X not found".

**Solutions**:

1. Check available build tools:
   ```bash
   devbox run android.sh info
   ```

2. Update build tools version in `devbox.json`:
   ```json
   {
     "env": {
       "ANDROID_BUILD_TOOLS_VERSION": "36.1.0"
     }
   }
   ```

3. Sync Gradle configuration with SDK version:
   Edit `app/build.gradle`:
   ```gradle
   android {
       compileSdk 36
       buildToolsVersion "36.1.0"
   }
   ```

### Enable Debug Logging

For detailed troubleshooting information, enable debug logging:

```bash
# Platform-specific debug
ANDROID_DEBUG=1 devbox shell

# Global debug
DEBUG=1 devbox shell
```

Debug logs show:
- Environment variable resolution
- SDK path discovery
- Device configuration loading
- Emulator startup commands
- ADB communication

## Common Use Cases

### Multi-Device Testing

Test your app across multiple Android versions:

1. Create device definitions for each version:
   ```bash
   devbox run android.sh devices create api21 --api 21 --device pixel --tag google_apis
   devbox run android.sh devices create api28 --api 28 --device pixel --tag google_apis
   devbox run android.sh devices create api36 --api 36 --device pixel --tag google_apis
   ```

2. Regenerate lock file:
   ```bash
   devbox run android.sh devices eval
   ```

3. Test on each device:
   ```bash
   devbox run start:emu api21
   # run your tests...
   devbox run stop:emu

   devbox run start:emu api36
   # run your tests...
   devbox run stop:emu
   ```

### CI/CD Integration

Use the plugin in GitHub Actions:

```yaml
name: Android CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Devbox
        uses: jetify-com/devbox-install-action@v0.11.0

      - name: Run E2E Tests
        run: |
          EMU_HEADLESS=1 TEST_PURE=1 devbox run test:e2e
```

Configure for headless operation:
```json
{
  "env": {
    "EMU_HEADLESS": "1",
    "ANDROID_EMULATOR_PURE": "1"
  }
}
```

### Development with Custom System Images

Use specific system image tags:

```bash
# Google APIs (recommended for most apps)
devbox run android.sh devices create dev --api 34 --device pixel --tag google_apis

# Google Play Store (for testing in-app purchases)
devbox run android.sh devices create prod --api 34 --device pixel --tag google_apis_playstore

# AOSP (minimal Android, no Google services)
devbox run android.sh devices create minimal --api 34 --device pixel --tag default
```

## Next Steps

### Learn More

- **Complete API Reference**: See [Android Reference](../reference/android.md) for exhaustive documentation of all commands, environment variables, and configuration options
- **Plugin Testing**: See [plugins/tests/android/](../../plugins/tests/android/) for plugin unit tests
- **CI/CD Workflows**: See [.github/workflows/](../../.github/workflows/) for CI integration examples
- **Plugin Development**: See [Conventions](../project/CONVENTIONS.md) for plugin development patterns

### Related Guides

- **[Device Management Guide](device-management.md)**: Deep dive into device definitions and management
- **[Testing Guide](testing.md)**: Comprehensive testing strategies and best practices
- **[Troubleshooting Guide](troubleshooting.md)**: Extended troubleshooting scenarios
- **[Quick Start](quick-start.md)**: Get up and running quickly

### Example Projects

- **[Android Example](../../examples/android/)**: Complete Android app with build scripts, deploy commands, and E2E test suites
- **[React Native Example](../../examples/react-native/)**: Cross-platform app using both Android and iOS plugins

### Community and Support

- **GitHub Issues**: Report bugs or request features
- **Devbox Documentation**: [jetify.com/devbox/docs](https://www.jetify.com/devbox/docs/)
- **Discord**: Join the Jetify community for help and discussions
