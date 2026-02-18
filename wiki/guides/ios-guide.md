# iOS Development Guide

A complete guide to iOS development using the Devbox iOS plugin. This guide covers setup, device management, development workflow, testing, and troubleshooting.

## What the iOS Plugin Provides

The iOS plugin enables reproducible iOS development by automatically discovering Xcode and managing iOS simulators project-locally. It provides:

- **Project-local simulator management**: Device definitions stored in your devbox.d directory, isolated from system-wide simulator configuration
- **Automatic Xcode discovery**: Multi-strategy detection with caching for fast shell initialization
- **Device management**: JSON-based device definitions with CLI commands for creating, updating, and managing simulators
- **Simulator control**: Scripts for starting and stopping simulators

The plugin does **not** provide build or deploy commands. Every project has different Xcode configurations (project vs. workspace, different schemes, different derived data paths), so you define those in your own `devbox.json`. See [Adding Build Scripts](#adding-build-and-deploy-scripts) for patterns.

Pure shells with `devbox run --pure` create test-specific simulators and clean up after execution, ensuring isolated, reproducible testing.

## Setup and Installation

### Prerequisites

- macOS with [Xcode](https://apps.apple.com/app/xcode/id497799835) installed
- [Devbox](https://www.jetify.com/devbox/docs/installing_devbox/) installed

Devbox handles downloading other tools — you don't need to install them separately.

### Adding the Plugin to Your Project

Create or modify your `devbox.json` to include the iOS plugin:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/ios"]
}
```

The Xcode project, build scheme, bundle ID, and app path are all auto-detected at runtime. Use `-derivedDataPath DerivedData` in your xcodebuild command to keep build output project-local.

### Initial Setup

Initialize the Devbox environment:

```bash
devbox shell
```

This command:
1. Discovers Xcode installation automatically
2. Creates device definitions in your devbox.d directory
3. Sets up runtime scripts
4. Configures environment variables for iOS development
5. Caches Xcode path for fast subsequent initialization

Verify the installation:

```bash
devbox run ios.sh info
```

This displays Xcode developer directory, iOS SDK version, available runtimes, and device configuration.

You can also run diagnostics to check your setup:

```bash
devbox run doctor
```

This checks for Xcode installation, command-line tools, xcrun and simctl availability, device definitions, and lock file status.

## Device Management

Device definitions are JSON files that describe simulator configurations. Each plugin install creates a `devices/` directory inside your `devbox.d/` folder with default device files.

### Default Devices

The plugin includes two default devices:

- `min.json` - Minimum supported iOS version (iOS 15.4, named `iPhone 13`)
- `max.json` - Latest iOS version (iOS 26.2, named `iPhone 17`)

These files live in your `devbox.d/` directory, which is the devbox plugin configuration folder. The plugin creates a subdirectory there with a `devices/` folder containing them (e.g., `devbox.d/<plugin-dir>/devices/min.json`). The filenames (`min`, `max`) are short nicknames you use in commands. The `name` field inside each JSON file is the simulator display name that appears in device listings.

### Listing Devices

View all available device definitions:

```bash
devbox run ios.sh devices list
```

Output shows device names and iOS runtime versions.

### Viewing Available Device Types and Runtimes

To see what device types and runtimes are available on your system:

```bash
# List available device types (e.g., iPhone 15, iPhone 13, iPad Pro)
xcrun simctl list devicetypes

# List available iOS runtimes (iOS versions installed)
xcrun simctl list runtimes
```

### Creating a New Device

Create a device with specific configuration:

```bash
devbox run ios.sh devices create iphone15 --runtime 17.5
```

Parameters:
- Device name (first argument): Used as filename and identifier
- `--runtime` (required): iOS version (e.g., "17.5", "18.0", "15.4")

The device name typically corresponds to iOS device types like:
- `iPhone 15 Pro`
- `iPhone 14`
- `iPad Pro`
- `iPad Air`

### Viewing Device Details

Show configuration for a specific device:

```bash
devbox run ios.sh devices show iphone15
```

### Updating a Device

Modify an existing device definition:

```bash
# Update iOS runtime version
devbox run ios.sh devices update iphone15 --runtime 18.0

# Rename device
devbox run ios.sh devices update iphone15 --name iphone15pro
```

### Deleting a Device

Remove a device definition:

```bash
devbox run ios.sh devices delete iphone15
```

### Selecting Devices for Evaluation

By default, the plugin evaluates all devices. To optimize evaluation time (especially in CI), select specific devices in `devbox.json`:

```json
{
  "env": {
    "IOS_DEVICES": "min,max"
  }
}
```

To evaluate all devices, use an empty string:

```json
{
  "env": {
    "IOS_DEVICES": ""
  }
}
```

### Regenerating the Lock File

After creating, updating, or deleting devices, regenerate the lock file:

```bash
devbox run ios.sh devices eval
```

The lock file (in your devices directory) tracks which devices should be created and includes checksums for validation. Commit this file to version control.

### Syncing Simulators

Ensure local simulators match device definitions:

```bash
devbox run ios.sh devices sync
```

This creates or updates simulators to match your JSON device definitions. The sync process reports:
- **Matched**: Simulators that already exist and match definitions
- **Recreated**: Simulators that needed to be deleted and recreated
- **Created**: New simulators created
- **Skipped**: Devices skipped due to missing runtimes

Run this after modifying device files or pulling changes.

## Development Workflow

### Starting a Simulator

Start an iOS simulator for testing:

```bash
# Start default device
devbox run start:sim

# Start specific device by nickname
devbox run start:sim iphone15
```

The simulator boots if not already running. The default device is configured via `IOS_DEFAULT_DEVICE` (defaults to `max`).

Set the default device in `devbox.json`:

```json
{
  "env": {
    "IOS_DEFAULT_DEVICE": "max"
  }
}
```

### Stopping the Simulator

Stop all running simulators:

```bash
devbox run stop:sim
```

### Adding Build and Deploy Scripts

The plugin provides simulator and device management. Build and deploy commands are specific to your Xcode project, so you define them in your `devbox.json`. Here's a typical setup:

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

The `ios.sh run` command starts the simulator, builds (via `build:ios`), auto-detects the .app bundle, extracts the bundle ID, installs, and launches. The `${1:-}` syntax passes an optional device nickname through.

With these scripts defined, you can:

```bash
# Build the app
devbox run build:ios

# Start simulator, install, and launch
devbox run start:app

# Run on a specific device
devbox run start:app min
```

See the [iOS example project](../../examples/ios/) for a complete working setup.

### Complete Development Workflow Example

Typical development session:

```bash
# 1. Enter devbox shell
devbox shell

# 2. Start simulator
devbox run start:sim max

# 3. Build and deploy app (using your custom scripts)
devbox run build
devbox run start:app max

# 4. Make code changes, rebuild, and redeploy
devbox run build
devbox run start:app max

# 5. Stop simulator when done
devbox run stop:sim
```

## Testing

### Running E2E Tests

The [iOS example project](../../examples/ios/) includes E2E test infrastructure using process-compose. You can use it as a template for your own project.

Copy the example test suite:

```bash
cp -r examples/ios/tests/ your-project/tests/
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

### Normal Mode vs Pure Mode

The test suite automatically adjusts behavior based on the execution mode:

**Normal Mode (Developer):**
- Reuses existing simulators
- Keeps app and simulator running after test
- Fast iteration for development

```bash
devbox run test:e2e
```

**Pure Mode (CI):**
- Creates fresh test-specific simulator (with " Test" suffix)
- Stops and cleans up everything after test
- Reproducible, isolated environment

```bash
devbox run --pure test:e2e

# Or in CI:
IN_NIX_SHELL=pure devbox run test:e2e
```

The `IN_NIX_SHELL` environment variable is automatically set by devbox:
- `IN_NIX_SHELL=impure` - Normal mode
- `IN_NIX_SHELL=pure` - Pure mode (set by `--pure` flag)

### Interactive Monitoring

Run tests with TUI for real-time monitoring:

```bash
TEST_TUI=true devbox run test:e2e
```

The TUI shows process status, logs, and resource usage during test execution.

### Adding Tests to Your Project

Configure for your app in `devbox.json`:

```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/ios"],
  "shell": {
    "scripts": {
      "test:e2e": [
        "process-compose -f tests/test-suite.yaml --no-server --tui=${TEST_TUI:-false}"
      ]
    }
  }
}
```

Create device definitions:

```bash
mkdir -p devbox.d/ios/devices

# Create min device (oldest supported iOS)
devbox run ios.sh devices create min --runtime 15.4

# Create max device (latest iOS)
devbox run ios.sh devices create max --runtime 26.2

# Generate lock file
devbox run ios.sh devices eval
```

### Test Configuration

Customize test behavior with environment variables:

```bash
# Set simulator boot timeout (seconds)
BOOT_TIMEOUT=120 devbox run test:e2e

# Run headless (no simulator GUI - always headless on CI)
SIM_HEADLESS=1 devbox run test:e2e

# Enable debug logging
IOS_DEBUG=1 devbox run test:e2e
```

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `IOS_APP_ARTIFACT` | Path or glob for .app bundle | Auto-detect |
| `IOS_DEFAULT_DEVICE` | Default simulator device | `max` |
| `IOS_DOWNLOAD_RUNTIME` | Auto-download missing runtimes (0/1) | `1` |
| `TEST_TUI` | Show process-compose TUI (true/false) | `false` |
| `BOOT_TIMEOUT` | Simulator boot timeout (seconds) | `120` |
| `TEST_TIMEOUT` | Overall test timeout (seconds) | `300` |

## Configuration Options

### Environment Variables

Configure the plugin by setting environment variables in `devbox.json`:

```json
{
  "env": {
    "IOS_DEFAULT_DEVICE": "max",
    "IOS_DEVICES": "min,max",
    "IOS_DOWNLOAD_RUNTIME": "1"
  }
}
```

Key variables:
- `IOS_DEFAULT_DEVICE` - Default device when none specified
- `IOS_DEVICES` - Comma-separated device names to evaluate (empty = all)
- `IOS_APP_ARTIFACT` - Path or glob for .app bundle (empty = auto-detect via xcodebuild + search)
- `IOS_DOWNLOAD_RUNTIME` - Auto-download missing iOS runtimes (0/1, default: 1)

### Xcode Configuration

The plugin automatically discovers Xcode using multiple fallback strategies:

1. Check `IOS_DEVELOPER_DIR` environment variable
2. Check cache file (1-hour TTL)
3. Find latest Xcode in `/Applications/Xcode*.app` by version number
4. Use `xcode-select -p` output
5. Fallback to `/Applications/Xcode.app/Contents/Developer`

Override discovery by setting `IOS_DEVELOPER_DIR`:

```json
{
  "env": {
    "IOS_DEVELOPER_DIR": "/Applications/Xcode-15.4.app/Contents/Developer"
  }
}
```

### Performance Optimization

#### Skip iOS Setup for Faster Initialization

In React Native projects or Android-only contexts, skip iOS environment setup:

```json
{
  "env": {
    "IOS_SKIP_SETUP": "1"
  }
}
```

This speeds up shell initialization when you only need Android tooling. When set to 1, skips:
- Xcode path detection
- Device lock generation
- Environment configuration

#### Select Specific Devices

Limit which devices are evaluated to reduce initialization time:

```json
{
  "env": {
    "IOS_DEVICES": "min,max"
  }
}
```

After changing device selection, regenerate the lock file:

```bash
devbox run ios.sh devices eval
```

### Viewing Current Configuration

Display all configuration settings:

```bash
devbox run ios.sh config show
```

This shows:
- Configuration directory
- Device definitions directory
- Scripts directory
- Default device
- Selected devices (from `IOS_DEVICES`)
- App artifact path (or auto-detect)
- Runtime download setting

## Troubleshooting

### Xcode Not Found

**Symptom**: "Xcode developer directory not found" or Xcode tools unavailable.

**Solutions**:

1. Check if Xcode is installed:
   ```bash
   xcode-select -p
   ```

2. Install Xcode from the App Store, then set the active developer directory:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

3. Or install command-line tools only:
   ```bash
   xcode-select --install
   ```

4. Set explicit path in `devbox.json`:
   ```json
   {
     "env": {
       "IOS_DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer"
     }
   }
   ```

### Simulator Runtime Missing

**Symptom**: "Runtime iOS X.X not found" or simulator won't start due to missing runtime.

**Solutions**:

1. List available runtimes:
   ```bash
   xcrun simctl list runtimes
   ```

2. Download runtime via Xcode Settings:
   - Open Xcode
   - Go to Settings > Platforms
   - Click "+" to download iOS Simulator runtimes

3. Enable auto-download in `devbox.json`:
   ```json
   {
     "env": {
       "IOS_DOWNLOAD_RUNTIME": "1"
     }
   }
   ```

4. Or download via command line:
   ```bash
   xcodebuild -downloadPlatform iOS
   ```

### CoreSimulatorService Issues

**Symptom**: "CoreSimulatorService connection became invalid" or simulators won't start.

**Solutions**:

1. Restart CoreSimulatorService:
   ```bash
   killall -9 CoreSimulatorService
   ```

2. Check service status:
   ```bash
   launchctl list | grep CoreSimulator
   ```

3. Kickstart the service:
   ```bash
   launchctl kickstart -k gui/$UID/com.apple.CoreSimulatorService
   ```

4. Open Simulator app to initialize:
   ```bash
   open -a Simulator
   ```

### App Installation Fails

**Symptom**: Error installing app on simulator or app doesn't launch.

**Solutions**:

1. Verify app bundle exists (check your build output directory):
   ```bash
   find . -name '*.app' -type d -not -path '*/.devbox/*'
   ```

2. Check simulator is booted:
   ```bash
   xcrun simctl list devices | grep Booted
   ```

3. Verify bundle ID from a .app bundle:
   ```bash
   /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /path/to/MyApp.app/Info.plist
   ```

4. If auto-detection fails, set `IOS_APP_ARTIFACT` explicitly in `devbox.json`:
   ```json
   {
     "env": {
       "IOS_APP_ARTIFACT": "DerivedData/Build/Products/Debug-iphonesimulator/MyApp.app"
     }
   }
   ```

### Build Failures with Nix Flags

**Symptom**: Xcode build errors related to linker flags or Nix environment variables.

**Solution**: Strip Nix-related flags from the build environment. Use:

```bash
env -u LD -u LDFLAGS -u NIX_LDFLAGS xcodebuild ...
```

This ensures Xcode uses its native toolchain without interference from Nix.

### Lock File Out of Sync

**Symptom**: "Warning: devices.lock may be stale" or checksum mismatch.

**Solution**: Regenerate the lock file:

```bash
devbox run ios.sh devices eval
```

Commit the updated lock file to version control.

### Simulator Won't Boot

**Symptom**: Simulator times out during boot or fails to start.

**Solutions**:

1. Increase boot timeout:
   ```bash
   BOOT_TIMEOUT=180 devbox run start:sim
   ```

2. Check system resources (CPU, memory):
   ```bash
   top
   ```

3. View simulator logs:
   ```bash
   tail -f ~/Library/Logs/CoreSimulator/*/system.log
   ```

4. Check disk space:
   ```bash
   df -h
   ```

5. Restart your Mac if simulators are consistently failing.

### Enable Debug Logging

For detailed troubleshooting information, enable debug logging:

```bash
# iOS-specific debug
IOS_DEBUG=1 devbox shell

# Global debug
DEBUG=1 devbox shell
```

Debug logs show:
- Environment variable resolution
- Xcode path discovery
- Device configuration loading
- Simulator startup commands
- App deployment steps

### Debugging Failed Tests

**Check Test Logs:**

Test logs are written to `reports/`:

```bash
# View all logs
ls -la reports/

# View specific process log (paths depend on your test suite configuration)
cat reports/ios-e2e-logs/build-app.log
cat reports/ios-e2e-logs/ios-simulator.log
cat reports/ios-e2e-logs/deploy-app.log
```

**Check Simulator Status:**

```bash
# List all simulators
xcrun simctl list devices

# Check if specific simulator is running
xcrun simctl list devices | grep "Booted"

# View simulator logs
tail -f ~/Library/Logs/CoreSimulator/*/system.log
```

## Common Use Cases

### Multi-Device Testing

Test your app across multiple iOS versions:

1. Create device definitions for each version:
   ```bash
   devbox run ios.sh devices create iphone_ios15 --runtime 15.4
   devbox run ios.sh devices create iphone_ios17 --runtime 17.5
   devbox run ios.sh devices create iphone_ios18 --runtime 18.0
   ```

2. Regenerate lock file:
   ```bash
   devbox run ios.sh devices eval
   ```

3. Sync simulators:
   ```bash
   devbox run ios.sh devices sync
   ```

4. Test on each device:
   ```bash
   devbox run start:sim iphone_ios15
   # run your tests...
   devbox run stop:sim

   devbox run start:sim iphone_ios18
   # run your tests...
   devbox run stop:sim
   ```

### CI/CD Integration

Use the plugin in GitHub Actions:

```yaml
name: iOS CI

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Devbox
        uses: jetify-com/devbox-install-action@v0.11.0

      - name: Run E2E Tests
        working-directory: examples/ios
        env:
          SIM_HEADLESS: 1
          BOOT_TIMEOUT: 180
          TEST_TIMEOUT: 600
          IOS_DEFAULT_DEVICE: max
          TEST_TUI: false
        run: devbox run --pure test:e2e
```

Key CI settings:
- `devbox run --pure` ensures isolated environment
- `TEST_TUI=false` disables interactive TUI
- Longer timeouts for slower CI machines
- Headless simulator mode (via `SIM_HEADLESS=1`)

### Development with Multiple Xcode Versions

Switch between Xcode versions:

```json
{
  "env": {
    "IOS_DEVELOPER_DIR": "/Applications/Xcode-15.4.app/Contents/Developer"
  }
}
```

Or use shell environment:

```bash
# Use Xcode 15.4 for this session
export IOS_DEVELOPER_DIR="/Applications/Xcode-15.4.app/Contents/Developer"
devbox shell

# Verify
devbox run ios.sh info
```

### Testing Different Device Types

Create simulators for various device types:

```bash
# iPhone devices
devbox run ios.sh devices create iphone15_pro --runtime 17.5
devbox run ios.sh devices create iphone14 --runtime 17.5

# iPad devices
devbox run ios.sh devices create ipad_pro --runtime 17.5
devbox run ios.sh devices create ipad_air --runtime 17.5

# Regenerate lock file
devbox run ios.sh devices eval
```

The device name in the JSON file should match the device type from `xcrun simctl list devicetypes`.

## Next Steps

### Learn More

- **Complete API Reference**: See [iOS Reference](../reference/ios.md) for exhaustive documentation of all commands, environment variables, and configuration options
- **Architecture**: See [Architecture](../project/ARCHITECTURE.md) for script organization and layer documentation
- **Plugin Testing**: See [plugins/tests/ios/](../../plugins/tests/ios/) for plugin unit tests
- **CI/CD Workflows**: See [CI/CD](../project/CI-CD.md) for CI integration examples
- **Plugin Development**: See [Conventions](../project/CONVENTIONS.md) for plugin development patterns

### Related Guides

- **[Android Development Guide](android-guide.md)**: Comprehensive Android development with the Android plugin
- **[React Native Guide](react-native-guide.md)**: Cross-platform development with both iOS and Android plugins
- **[Device Management Guide](device-management.md)**: Deep dive into device definitions and management
- **[Testing Guide](testing.md)**: Comprehensive testing strategies and best practices
- **[Troubleshooting Guide](troubleshooting.md)**: Extended troubleshooting scenarios

### Example Projects

- **[iOS Example](../../examples/ios/)**: Complete iOS app with build scripts, deploy commands, and E2E test suites
- **[React Native Example](../../examples/react-native/)**: Cross-platform app using both iOS and Android plugins

### Community and Support

- **GitHub Issues**: Report bugs or request features
- **Devbox Documentation**: [jetify.com/devbox/docs](https://www.jetify.com/devbox/docs/)
- **Discord**: Join the Jetify community for help and discussions
