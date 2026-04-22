---
name: devbox-rn
description: React Native Devbox plugin composing Android + iOS plugins. Manages Metro bundler, cross-platform builds, and platform-specific workflows. Includes performance optimizations for single-platform contexts.
argument-hint: [command or workflow]
disable-model-invocation: false
allowed-tools: Bash(devbox *) Bash(metro.sh *) Bash(android.sh *) Bash(ios.sh *) Read Edit Write
---

# Devbox React Native Plugin

## Overview

React Native Devbox plugin composes Android and iOS plugins for cross-platform development. Adds Metro bundler management and web builds. See devbox-android and devbox-ios skills for platform-specific details.

Key features:
- Metro bundler lifecycle management
- Cross-platform builds (Android, iOS, Web)
- Platform-specific workflows with performance optimizations
- Suite-based Metro port allocation for parallel testing

## Setup

### Include Plugin

In `devbox.json`:
```json
{
  "include": ["github:segment-integrations/mobile-devtools?dir=plugins/react-native&ref=main"],
  "packages": [
    "nodejs@20",
    "watchman@latest",
    "jdk17@latest",
    "gradle@latest"
  ]
}
```

Includes both Android and iOS plugins automatically.

### Initialize

```bash
npm install                 # Install React Native dependencies
devbox shell                # Sets up Android + iOS environments
```

First run downloads Android SDK (Nix) and detects Xcode (macOS). Subsequent runs are fast (cached).

## Metro Bundler Management

### Start Metro

```bash
metro.sh start [suite-name]
devbox run start:metro [suite-name]         # Alias
```

Starts Metro bundler with:
- Port allocation (suite-namespaced)
- Environment saved to `$REACT_NATIVE_VIRTENV/metro/env-<suite>.sh`
- Reset cache on start
- Port saved to `$REACT_NATIVE_VIRTENV/metro/port-<suite>.txt`

Default suite: "default". Use different suite names for parallel Metro instances.

Example:
```bash
metro.sh start                    # Default suite on allocated port
metro.sh start android            # Android test suite
metro.sh start ios                # iOS test suite
```

### Stop Metro

```bash
metro.sh stop [suite-name]
devbox run stop:metro [suite-name]         # Alias
```

Stops Metro bundler for specified suite.

WARNING: Only stops Metro instances started by this plugin. Tracks PIDs to avoid killing external processes.

### Check Metro Status

```bash
metro.sh status [suite-name]
```

Shows:
- Port number
- Running status (PID)
- Environment file location

### Clean Metro

```bash
metro.sh clean [suite-name]
```

Removes state files for suite. Does not stop Metro.

## Platform-Specific Builds

### Android Build

```bash
devbox run build:android
devbox run build:android:release
```

Build script example in `devbox.json`:
```json
{
  "shell": {
    "scripts": {
      "build:android": [
        "npm install",
        "cd android && ./gradlew assembleDebug"
      ],
      "build:android:release": [
        "npm install",
        "cd android && ./gradlew assembleRelease"
      ]
    }
  }
}
```

### iOS Build

```bash
devbox run build:ios
devbox run build:ios:release
```

Build script example in `devbox.json`:
```json
{
  "shell": {
    "scripts": {
      "build:ios": [
        "npm install",
        "cd ios && pod install --repo-update",
        "ios.sh xcodebuild -workspace MyApp.xcworkspace -scheme MyApp -configuration Debug -destination 'generic/platform=iOS Simulator' build"
      ],
      "build:ios:release": [
        "npm install",
        "cd ios && pod install --repo-update",
        "ios.sh xcodebuild -workspace MyApp.xcworkspace -scheme MyApp -configuration Release build"
      ]
    }
  }
}
```

WARNING: Use `ios.sh xcodebuild` not bare `xcodebuild`. Wrapper strips Nix flags.

### Web Build

```bash
devbox run build:web
```

Creates web bundle. Build path configured via `WEB_BUILD_PATH` in `devbox.d/react-native/react-native.json`.

### Build All Platforms

```bash
devbox run build                # All platforms
devbox run build:debug          # Android + iOS debug
devbox run build:release        # Android + iOS release
```

## Development Workflows

### Android Development

```bash
devbox run start:android
devbox run start:android:release
```

Uses process-compose to orchestrate:
1. Start Metro bundler
2. Start Android emulator
3. Build and deploy app
4. Hot reload enabled

Stop:
```bash
# Process-compose stops Metro automatically
# Manually stop emulator if needed:
devbox run stop:emu
```

### iOS Development

```bash
devbox run start:ios
devbox run start:ios:release
```

Uses process-compose to orchestrate:
1. Start Metro bundler
2. Start iOS simulator
3. Build and deploy app
4. Hot reload enabled

Stop:
```bash
# Process-compose stops Metro automatically
# Manually stop simulator if needed:
devbox run stop:sim
```

### Web Development

```bash
devbox run start:web
```

Starts web server with Metro bundler.

## Direct Platform Commands

### Android

```bash
devbox run start:emu [device]          # Start emulator
devbox run stop:emu                    # Stop emulator
android.sh emulator start [device]     # Direct command
android.sh run [apk] [device]          # Build + deploy
```

See devbox-android skill for full Android commands.

### iOS

```bash
devbox run start:sim [device]          # Start simulator
devbox run stop:sim                    # Stop simulator
ios.sh simulator start [device]        # Direct command
ios.sh run [app] [device]              # Build + deploy
```

See devbox-ios skill for full iOS commands.

## Testing Workflows

### E2E Tests

```bash
devbox run test:e2e:android           # Android E2E
devbox run test:e2e:ios               # iOS E2E
devbox run test:e2e:web               # Web E2E
devbox run test:e2e:all               # All platforms in parallel
```

Each test suite:
1. Starts Metro with suite-namespaced port
2. Starts platform-specific environment (emulator/simulator)
3. Builds and deploys app
4. Runs E2E tests
5. Cleans up

Parallel execution: Each suite uses unique `SUITE_NAME` for state isolation.

### Unit Tests

```bash
devbox run test                       # Run Jest/native tests
npm test                              # Direct npm command
```

## Configuration

### Environment Variables

**React Native:**
- `WEB_BUILD_PATH`: Web build output directory (in react-native.json)

**Android (inherited):**
- `ANDROID_DEFAULT_DEVICE`: Default emulator device
- `ANDROID_APP_ID`: App identifier
- `ANDROID_APP_APK`: APK path or glob
- `ANDROID_BUILD_CONFIG`: Debug or Release
- `ANDROID_SKIP_SETUP`: Skip Android SDK setup (0/1)

**iOS (inherited):**
- `IOS_DEFAULT_DEVICE`: Default simulator device
- `IOS_APP_SCHEME`: Xcode scheme
- `IOS_APP_ARTIFACT`: .app path or glob
- `IOS_APP_BUNDLE_ID`: Bundle identifier
- `IOS_BUILD_CONFIG`: Debug or Release
- `IOS_SKIP_SETUP`: Skip iOS setup (0/1)

**Metro:**
- `METRO_PORT`: Allocated port (set automatically per suite)
- `REACT_NATIVE_VIRTENV`: Plugin virtenv directory

**Suite isolation:**
- `SUITE_NAME`: Test suite name for state isolation (default: "default")

### Configuration Files

```
devbox.d/
├── android/
│   └── devices/              # Android device definitions
├── ios/
│   └── devices/              # iOS device definitions
└── react-native/
    └── react-native.json     # React Native config
```

Example `react-native.json`:
```json
{
  "WEB_BUILD_PATH": "web/build"
}
```

## Performance Optimization

### Skip Android Setup (iOS-only workflows)

Set `ANDROID_SKIP_SETUP=1` to skip Android SDK downloads and evaluation:

```bash
# One-time commands
devbox run -e ANDROID_SKIP_SETUP=1 build:ios
devbox run -e ANDROID_SKIP_SETUP=1 start:ios
devbox run --pure -e ANDROID_SKIP_SETUP=1 start:sim

# In devbox.json
{
  "shell": {
    "scripts": {
      "start:ios-only": [
        "ANDROID_SKIP_SETUP=1 process-compose -f tests/dev-ios.yaml"
      ]
    }
  }
}

# In process-compose YAML
ios-workflow:
  environment:
    - ANDROID_SKIP_SETUP=1
```

Significantly speeds up iOS workflows by avoiding Android SDK initialization.

### Skip iOS Setup (Android-only workflows)

Set `IOS_SKIP_SETUP=1` to skip iOS environment setup:

```bash
# One-time commands
devbox run -e IOS_SKIP_SETUP=1 build:android
devbox run -e IOS_SKIP_SETUP=1 start:android

# In devbox.json
{
  "shell": {
    "scripts": {
      "start:android-only": [
        "IOS_SKIP_SETUP=1 process-compose -f tests/dev-android.yaml"
      ]
    }
  }
}
```

On non-macOS platforms, iOS setup is automatically skipped regardless of flag.

## Common Workflows

### Initial Setup

```bash
# 1. Include plugin in devbox.json
# 2. Install dependencies
npm install

# 3. Create device definitions (optional - min/max provided by default)
mkdir -p devbox.d/android/devices
mkdir -p devbox.d/ios/devices

# 4. Initialize environment
devbox shell

# 5. Verify platform setups
android.sh devices list
ios.sh devices list
```

### Cross-Platform Development

```bash
# Start Metro (shared across platforms)
metro.sh start

# In separate terminals:
# Android
devbox run start:emu
android.sh run

# iOS
devbox run start:sim
ios.sh run

# Web
devbox run start:web

# Stop when done
metro.sh stop
devbox run stop:emu
devbox run stop:sim
```

### Platform-Specific Development

**Android only:**
```bash
# Use ANDROID_SKIP_SETUP to skip iOS
devbox run start:android                # Starts Metro + emulator + app
```

**iOS only:**
```bash
# Use IOS_SKIP_SETUP to skip Android (automatic in macOS)
devbox run start:ios                    # Starts Metro + simulator + app
```

### Parallel Testing

Use process-compose with suite isolation:

```yaml
# tests/parallel.yaml
test-android:
  command: devbox run test:e2e:android
  environment:
    - SUITE_NAME=android

test-ios:
  command: devbox run test:e2e:ios
  environment:
    - SUITE_NAME=ios
    - ANDROID_SKIP_SETUP=1

test-web:
  command: devbox run test:e2e:web
  environment:
    - SUITE_NAME=web
    - ANDROID_SKIP_SETUP=1
    - IOS_SKIP_SETUP=1
```

Run:
```bash
process-compose -f tests/parallel.yaml
```

Each suite gets:
- Unique Metro port
- Isolated state files
- Independent cleanup

### CI Workflows

Optimize by testing platforms independently:

```yaml
# .github/workflows/test.yml
android-tests:
  steps:
    - run: devbox run -e IOS_SKIP_SETUP=1 test:e2e:android

ios-tests:
  runs-on: macos-latest
  steps:
    - run: devbox run -e ANDROID_SKIP_SETUP=1 test:e2e:ios

web-tests:
  steps:
    - run: devbox run -e ANDROID_SKIP_SETUP=1 -e IOS_SKIP_SETUP=1 test:e2e:web
```

## File Structure

```
.
├── devbox.json                         # Plugin include, scripts
├── package.json                        # React Native dependencies
├── devbox.d/
│   ├── android/
│   │   └── devices/                    # Android device definitions
│   ├── ios/
│   │   └── devices/                    # iOS device definitions
│   └── react-native/
│       └── react-native.json           # React Native config
├── android/                            # Android native code
├── ios/                                # iOS native code
└── .devbox/
    └── virtenv/
        ├── android/                    # Android plugin virtenv
        ├── ios/                        # iOS plugin virtenv
        └── react-native/
            └── metro/                  # Metro state
                ├── port-<suite>.txt
                ├── env-<suite>.sh
                └── cache/              # Metro cache
```

## Troubleshooting

### Metro Port Conflicts

Check Metro status:
```bash
metro.sh status [suite]
```

If port conflict:
```bash
metro.sh stop [suite]
metro.sh clean [suite]
metro.sh start [suite]      # Allocates new port
```

### Platform Setup Slow

Skip unused platforms:
```bash
# iOS-only
ANDROID_SKIP_SETUP=1 devbox shell

# Android-only
IOS_SKIP_SETUP=1 devbox shell
```

### Android SDK Missing

Ensure Android plugin working:
```bash
android.sh devices list
android.sh devices eval
```

See devbox-android skill.

### iOS Xcode Not Found

Ensure Xcode installed:
```bash
ios.sh info
ios.sh devices list
```

See devbox-ios skill.

### Metro Cache Issues

Clear Metro cache:
```bash
rm -rf .devbox/virtenv/react-native/metro/cache
metro.sh stop
metro.sh start --reset-cache
```

Or use npx directly:
```bash
npx react-native start --reset-cache
```

### Parallel Test Failures

Verify suite isolation:
```bash
metro.sh status android
metro.sh status ios
metro.sh status web
```

Each should show unique ports. If not, ensure `SUITE_NAME` set in process-compose environment.

## Quick Reference

| Task | Command |
|------|---------|
| Install dependencies | `npm install` |
| Start Metro | `metro.sh start [suite]` |
| Stop Metro | `metro.sh stop [suite]` |
| Metro status | `metro.sh status [suite]` |
| Build Android | `devbox run build:android` |
| Build iOS | `devbox run build:ios` |
| Build Web | `devbox run build:web` |
| Build all | `devbox run build` |
| Start Android dev | `devbox run start:android` |
| Start iOS dev | `devbox run start:ios` |
| Start Web dev | `devbox run start:web` |
| Test Android E2E | `devbox run test:e2e:android` |
| Test iOS E2E | `devbox run test:e2e:ios` |
| Test all E2E | `devbox run test:e2e:all` |
| Start emulator | `devbox run start:emu [device]` |
| Stop emulator | `devbox run stop:emu` |
| Start simulator | `devbox run start:sim [device]` |
| Stop simulator | `devbox run stop:sim` |

## Key Differences from Standard React Native

**Standard React Native:**
- Global React Native CLI
- Manual Metro management
- Platform-specific setup per developer
- Manual port management
- Ad-hoc parallel testing

**Devbox React Native:**
- Project-local Metro with state tracking
- Suite-based port allocation
- Reproducible Android + iOS environments
- Automated workflows via process-compose
- Built-in parallel test support
- Performance optimizations (skip unused platforms)

All React Native state is project-local. Android SDK via Nix, iOS via system Xcode. No global pollution.

## Integration with Other Skills

**devbox-android:** Android-specific commands, device management, emulator operations. Use for Android-only workflows.

**devbox-ios:** iOS-specific commands, device management, simulator operations. Use for iOS-only workflows.

**devbox:** Core Devbox CLI, project structure, package management. Use for general Devbox operations.

When creating PRs for React Native projects, consider splitting by platform if changes are large (see pr skill).
