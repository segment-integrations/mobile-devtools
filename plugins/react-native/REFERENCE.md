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

- Android: `devbox run --pure start:emu`, `devbox run --pure start:android`, `devbox run --pure stop:emu`
- iOS: `devbox run --pure start:sim`, `devbox run --pure start:ios`, `devbox run --pure stop:sim`
- Web/Metro: `devbox run --pure start-web`

## Files

- Android config and devices: `devbox.d/android/`
- iOS config and devices: `devbox.d/ios/`
- React Native config: `devbox.d/react-native/react-native.json`

## Config keys (`react-native.json`)

- `WEB_BUILD_PATH`
