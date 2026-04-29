# React Native Devbox Plugin

This plugin composes the Android and iOS Devbox plugins to provide emulator and simulator services
for React Native projects.

## Quickstart

```sh
# Metro bundler
devbox run start:metro              # Start Metro bundler
devbox run stop:metro               # Stop Metro bundler

# Android
devbox run start:android            # Build, install, and launch on emulator

# iOS
devbox run start:ios                # Build, install, and launch on simulator
```

These commands require build scripts defined in your `devbox.json`:
- `build:android` or `build` for Android builds
- `build:ios` or `build` for iOS builds

## Reference

See `devbox/plugins/react-native/REFERENCE.md` for the full command and config reference.
