# Doctor Command Guide

The `doctor` command provides comprehensive health checks for your mobile development environment.

## Usage

```bash
# Run doctor check
devbox run doctor

# Check exit code
devbox run doctor
echo "Exit code: $?"
```

## Exit Codes

- `0` = All checks passed (success)
- `1` = Warnings detected (non-fatal issues)
- `2` = Fatal errors (critical failures)

## CI Integration

Use doctor in CI to validate environment before running tests:

```yaml
# Fail on errors, allow warnings
- name: Validate environment
  run: devbox run doctor || test $? -lt 2

# Fail on any issues
- name: Validate environment (strict)
  run: devbox run doctor
```

## Platform-Specific

### Android
```bash
cd examples/android
devbox run doctor
```

Checks:
- Android SDK installation and path
- Essential tools (adb, emulator, avdmanager)
- Device configuration and lock files
- Configuration drift detection
- Project structure (build.gradle, app module)
- Disk space and system resources

### iOS
```bash
cd examples/ios
devbox run doctor
```

Checks:
- Xcode and command line tools
- Simulator runtimes availability
- Device configuration
- Project structure (.xcodeproj, .xcworkspace)
- CocoaPods installation
- Disk space and memory

### React Native
```bash
cd examples/react-native
devbox run doctor
```

Checks:
- Node.js version and package manager
- React Native project structure
- Development tools (Watchman, Metro)
- Android platform (respects ANDROID_SKIP_SETUP)
- iOS platform (respects IOS_SKIP_SETUP)

## Skip Flags

Skip platform checks when not needed:

```bash
# Skip Android checks
ANDROID_SKIP_SETUP=1 devbox run doctor

# Skip iOS checks
IOS_SKIP_SETUP=1 devbox run doctor

# Android only
IOS_SKIP_SETUP=1 devbox run doctor

# iOS only
ANDROID_SKIP_SETUP=1 devbox run doctor
```

## Troubleshooting

### Exit Code 2 (Errors)
Critical issues that must be fixed:
- SDK not installed
- Essential tools missing from PATH
- Invalid configuration

**Action:** Fix the reported errors before proceeding

### Exit Code 1 (Warnings)
Non-critical issues that may impact development:
- Optional tools not installed
- Low disk space
- Configuration drift
- Missing device lock files

**Action:** Review warnings and fix if needed, but development can continue

### Exit Code 0 (Success)
All checks passed, environment ready for development.
