# React Native Devbox Plugin Reference

## Overview

This plugin composes the Android and iOS plugins.

## Performance Optimization

When running iOS-only workflows, you can skip Android SDK evaluation and downloads by setting `ANDROID_SKIP_SETUP=1`:

```bash
# iOS-only commands
devbox run -e ANDROID_SKIP_SETUP=1 build:ios
devbox run --pure -e ANDROID_SKIP_SETUP=1 start:sim

# The flag is automatically set in test-suite-ios.yaml
devbox run test:e2e:ios
```

This significantly speeds up iOS workflows and prevents unnecessary Android SDK downloads.

## Commands

### Plugin-provided commands

These commands are provided by the React Native plugin (and its included Android and iOS plugins):

- `devbox run --pure start:emu [device]` — Start Android emulator
- `devbox run --pure stop:emu` — Stop Android emulator
- `devbox run --pure start:sim [device]` — Start iOS simulator
- `devbox run --pure stop:sim` — Stop iOS simulator
- `devbox run --pure doctor` — Run environment diagnostics
- `devbox run --pure verify:setup` — Verify environment is functional

### User-defined commands

These commands are typically defined in your project's `devbox.json` and are not part of the plugin itself:

- Build and run scripts (e.g., `start:app`, `build:android`, `build:ios`)
- Web/Metro scripts (e.g., `start:web`)

See the example projects for typical script definitions.

## Files

- Android config and devices in your devbox.d directory (e.g., `devbox.d/android/`)
- iOS config and devices in your devbox.d directory (e.g., `devbox.d/ios/`)

## Configuration (Environment Variables)

The React Native plugin sets the following environment variables (configurable in `devbox.json`):

- `REACT_NATIVE_WEB_BUILD_PATH` — Path for web build output (default: `web/build`)
- `METRO_CACHE_DIR` — Metro bundler cache directory
- `RN_METRO_PORT_START` — Start of Metro port range (default: `8091`)
- `RN_METRO_PORT_END` — End of Metro port range (default: `8199`)

It also overrides some Android plugin defaults for React Native compatibility (NDK, CMake, SDK versions). See the Android and iOS plugin references for their respective configuration options.
