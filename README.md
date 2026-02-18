# Devbox Plugins for Mobile Development

Reproducible, project-local development environments for Android, iOS, and React Native using [Devbox](https://www.jetify.com/devbox).

## Quick Start

```bash
# Add Android plugin to your project
echo '{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/android"]
}' > devbox.json

# Enter development environment
devbox shell

# Start emulator and run app
devbox run start-emu
devbox run start-app
```

**New to devbox-plugins?** Check out the [Quick Start Guide](wiki/guides/quick-start.md) for detailed setup instructions.

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

- **[Quick Start](wiki/guides/quick-start.md)** - Get started in 5 minutes
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

The repository includes example projects demonstrating plugin usage:

- **[examples/android](examples/android/)** - Minimal Android app
- **[examples/ios](examples/ios/)** - Swift package example
- **[examples/react-native](examples/react-native/)** - React Native app with Android, iOS, and Web

Each example includes device definitions, test suites, and build scripts.

## Common Commands

```bash
# Android
devbox run start-emu        # Start Android emulator
devbox run start-app        # Build and launch app
devbox run stop-emu         # Stop emulator

# iOS
devbox run start-sim        # Start iOS simulator
devbox run start-ios        # Build and launch app
devbox run stop-sim         # Stop simulator

# Device management
devbox run android.sh devices list
devbox run ios.sh devices list

# Testing
devbox run test:fast        # Quick tests (~2-5 min)
devbox run test:e2e         # Full E2E tests (~15-30 min)
```

## Requirements

- **[Devbox](https://www.jetify.com/devbox)** - Install with `curl -fsSL https://get.jetify.com/devbox | bash`
- **macOS** - Required for iOS plugin (Xcode required)
- **Linux** - Supported for Android and React Native (Android only)

## License

MIT

## Support

- **Questions?** Check [Troubleshooting](wiki/guides/troubleshooting.md)
- **Found a bug?** [Open an issue](https://github.com/segment-integrations/devbox-plugins/issues)
- **Want to contribute?** Read the [Contributing Guide](wiki/project/CONTRIBUTING.md)
