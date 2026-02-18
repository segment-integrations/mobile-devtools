# React Native Cheatsheet

Quick reference for common React Native plugin operations.

## Setup

```bash
# Add plugin to devbox.json
{
  "include": ["github:segment-integrations/devbox-plugins?dir=plugins/react-native"],
  "packages": ["nodejs@20", "watchman@latest"],
  "env": {
    "ANDROID_DEFAULT_DEVICE": "max",
    "IOS_DEFAULT_DEVICE": "max",
    "ANDROID_DEVICES": "min,max",
    "IOS_DEVICES": "min,max"
  }
}

# Install dependencies
npm install

# Enter shell
devbox shell
```

## Device Management

```bash
# Android devices
devbox run android.sh devices list
devbox run android.sh devices create pixel_api30 --api 30 --device pixel
devbox run android.sh devices eval

# iOS devices
devbox run ios.sh devices list
devbox run ios.sh devices create iphone15 --runtime 17.5
devbox run ios.sh devices eval
```

## Running Apps

```bash
# Android
devbox run start:emu         # Start emulator
devbox run start:android     # Build and run app

# iOS
devbox run start:sim         # Start simulator
devbox run start:ios         # Build and run app

# Web
devbox run start:web         # Start web dev server
```

## Metro Bundler

```bash
# Start Metro manually
devbox run start:metro

# Metro with custom port
RN_METRO_PORT=8091 devbox run start:metro

# Clean Metro cache
devbox run clean-metro

# Get Metro port for test suite
devbox run rn:metro:port android

# Clean Metro for test suite
devbox run rn:metro:clean android
```

## Building

```bash
# Build all platforms
devbox run build

# Build specific platform
devbox run build:android
devbox run build:ios
devbox run build:web
```

## Testing

```bash
# Run all tests
devbox run test:fast

# Platform-specific E2E tests
devbox run test:e2e:android
devbox run test:e2e:ios
devbox run test:e2e:web

# With TUI (terminal UI)
TEST_TUI=true devbox run test:e2e:android
```

## Configuration

```bash
# Show configuration
devbox run android.sh config show
devbox run ios.sh config show
```

## Diagnostics

```bash
# Health checks
devbox run doctor
devbox run verify:setup

# Check Metro
devbox run test:metro
```

## Common Environment Variables

### Android
```bash
ANDROID_DEFAULT_DEVICE="max"
ANDROID_DEVICES="min,max"
ANDROID_APP_ID="com.reactnativeexample"
ANDROID_APP_APK="android/app/build/outputs/apk/debug/app-debug.apk"
ANDROID_COMPILE_SDK="35"
ANDROID_TARGET_SDK="35"
ANDROID_SKIP_SETUP="0"              # Skip Android for iOS-only
```

### iOS
```bash
IOS_DEFAULT_DEVICE="max"
IOS_DEVICES="min,max"
IOS_APP_PROJECT="ReactNativeExample.xcodeproj"
IOS_APP_SCHEME="ReactNativeExample"
IOS_APP_BUNDLE_ID="org.reactjs.native.example.ReactNativeExample"
IOS_SKIP_SETUP="0"                      # Skip iOS for Android-only
```

### Metro
```bash
METRO_CACHE_DIR=".devbox/virtenv/metro/cache"
RN_METRO_PORT_START="8091"
RN_METRO_PORT_END="8199"
```

## Troubleshooting

```bash
# Enable debug logging
ANDROID_DEBUG=1 IOS_DEBUG=1 devbox shell

# Reset Metro
devbox run clean-metro
rm -rf node_modules/.cache
npm start -- --reset-cache

# Android: Check emulator
adb devices
adb logcat | grep ReactNative

# iOS: Check simulator
xcrun simctl list devices
xcrun simctl spawn booted log stream --level debug

# Kill stuck Metro
pkill -f "react-native start"

# Clean build artifacts
rm -rf android/app/build
rm -rf ios/build
rm -rf .devbox/virtenv/ios/DerivedData
```

## Development Workflow

```bash
# Full Android workflow
devbox run start:emu
npm install
devbox run build:android
devbox run start:android

# Full iOS workflow
devbox run start:sim
npm install
cd ios && pod install && cd ..
devbox run build:ios
devbox run start:ios

# Development with hot reload
devbox run start:metro &
devbox run start:android    # Android
devbox run start:ios        # iOS
```

## Process Isolation

```bash
# Run multiple test suites in parallel
TEST_SUITE_NAME=android devbox run --pure test:e2e:android &
TEST_SUITE_NAME=ios devbox run --pure test:e2e:ios &

# Each suite gets unique Metro port (8091-8199)
# Logs go to reports/logs/suite-name-*.log
```

## Files and Directories

```
devbox.d/
├── android/devices/   # Android device definitions
│   ├── min.json
│   ├── max.json
│   └── devices.lock
└── ios/devices/       # iOS device definitions
    ├── min.json
    ├── max.json
    └── devices.lock

.devbox/virtenv/
├── android/           # Android runtime
├── ios/               # iOS runtime
└── metro/             # Metro state
    ├── cache/
    └── pid-*.txt      # Metro PIDs per suite

reports/
├── logs/              # Test logs
└── results/           # Test results

node_modules/
android/app/build/     # Android build output
ios/build/             # iOS build output
```

## See Also

- [React Native Guide](../react-native-guide.md) - Complete workflow
- [React Native Reference](../../reference/react-native.md) - Full API
- [Android Guide](../android-guide.md) - Android-specific details
- [iOS Guide](../ios-guide.md) - iOS-specific details
- [Testing Guide](../testing.md) - Testing strategies
