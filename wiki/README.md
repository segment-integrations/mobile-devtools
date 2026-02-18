# Devbox Plugins Documentation

Welcome to the devbox-plugins documentation. This wiki provides comprehensive guides, references, and contributor documentation for the Android, iOS, and React Native devbox plugins.

## Quick Links

- **New to devbox-plugins?** Start with the [Quick Start Guide](guides/quick-start.md)
- **Need a quick reference?** Check the [Cheatsheets](guides/cheatsheets/)
- **Looking for API docs?** Browse the [Reference](reference/)
- **Want to contribute?** Read the [Contributing Guide](project/CONTRIBUTING.md)

## Documentation Structure

### Guides

Step-by-step tutorials and practical workflows for using the plugins:

- [Quick Start](guides/quick-start.md) - Get started in 5 minutes
- [Android Guide](guides/android-guide.md) - Complete Android workflow
- [iOS Guide](guides/ios-guide.md) - Complete iOS workflow
- [React Native Guide](guides/react-native-guide.md) - Complete React Native workflow
- [Device Management](guides/device-management.md) - Managing emulators and simulators
- [Testing Guide](guides/testing.md) - Testing strategies and best practices
- [Troubleshooting](guides/troubleshooting.md) - Common issues and solutions

#### Cheatsheets

One-page quick references with the most common commands:

- [Android Cheatsheet](guides/cheatsheets/android.md)
- [iOS Cheatsheet](guides/cheatsheets/ios.md)
- [React Native Cheatsheet](guides/cheatsheets/react-native.md)

### Reference

Exhaustive API documentation for all public interfaces:

- [Android Reference](reference/android.md) - Complete Android plugin API
- [iOS Reference](reference/ios.md) - Complete iOS plugin API
- [React Native Reference](reference/react-native.md) - Complete React Native plugin API
- [Environment Variables](reference/environment-variables.md) - All environment variables across plugins
- [CLI Commands](reference/cli-commands.md) - All CLI commands and scripts
- [Configuration](reference/configuration.md) - devbox.json configuration options

### Project

Documentation for contributors and maintainers:

- [Contributing Guide](project/CONTRIBUTING.md) - How to contribute to the project
- [Architecture](project/ARCHITECTURE.md) - Project structure and design
- [Conventions](project/CONVENTIONS.md) - Code and naming conventions
- [Testing](project/TESTING.md) - Testing infrastructure and practices
- [CI/CD](project/CI-CD.md) - Continuous integration and deployment
- [Release Process](project/RELEASE.md) - Versioning and release procedures

## Plugins Overview

### Android Plugin

Provides reproducible Android development environments with:
- Nix-managed Android SDK
- AVD (Android Virtual Device) management
- Device definitions for min/max testing
- Project-local state (no `~/.android` pollution)

**Include in devbox.json:**
```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/android"]
}
```

### iOS Plugin

Provides reproducible iOS development environments with:
- Xcode toolchain integration
- iOS Simulator management
- Device definitions for min/max testing
- Runtime auto-download support

**Include in devbox.json:**
```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/ios"]
}
```

**Requirements:** macOS with Xcode installed

### React Native Plugin

Composition layer over Android and iOS plugins with:
- Metro bundler management
- Parallel test execution
- Cross-platform development workflows
- Web build support

**Include in devbox.json:**
```json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/react-native"]
}
```

## Key Features

- **Project-Local State** - All emulators, simulators, and caches are project-local, not global
- **Reproducible Environments** - Lock files ensure consistent SDK versions across machines
- **Parallel Execution** - Run multiple test suites simultaneously with `--pure` isolation
- **Device-Driven Configuration** - Define devices as JSON, sync AVDs/simulators declaratively
- **CI/CD Optimized** - Device filtering and platform skipping for fast CI builds

## Getting Help

- **Found a bug?** [Open an issue](https://github.com/segment-integrations/devbox-plugins/issues)
- **Have a question?** Check [Troubleshooting](guides/troubleshooting.md) first
- **Want to contribute?** Read the [Contributing Guide](project/CONTRIBUTING.md)

## Examples

Example projects are available in the repository:
- `examples/android/` - Minimal Android app
- `examples/ios/` - Swift package example
- `examples/react-native/` - React Native app with Android, iOS, and Web

Each example includes device definitions, test suites, and build scripts.
