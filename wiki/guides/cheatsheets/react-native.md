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
# Plugin-provided
devbox run start:emu         # Start Android emulator
devbox run stop:emu          # Stop Android emulator
devbox run start:sim         # Start iOS simulator
devbox run stop:sim          # Stop iOS simulator

# User-defined scripts (add to your devbox.json shell.scripts):
# "start:android": ["process-compose -f tests/dev-android.yaml"]
# "start:ios": ["process-compose -f tests/dev-ios.yaml"]
# "start:web": ["process-compose -f tests/dev-web.yaml"]
```

## Metro Bundler

```bash
# Plugin-provided
devbox run rn:metro:port android    # Get Metro port for test suite
devbox run rn:metro:clean android   # Clean Metro for test suite

# User-defined scripts (add to your devbox.json shell.scripts):
# "start:metro": ["metro.sh start ${1:-default}"]
# "stop:metro": ["metro.sh stop ${1:-default}"]

# Metro with custom port
RN_METRO_PORT=8091 devbox run start:metro
```

## Building

Build scripts are project-specific. Define them in your `devbox.json`.

```bash
# User-defined scripts (add to your devbox.json shell.scripts):
# "build": ["devbox run build:android", "devbox run build:ios", "devbox run build:web"]
# "build:android": ["cd android && gradle assembleDebug"]
# "build:ios": ["cd ios && pod install && xcodebuild ..."]
# "build:web": ["npx react-native-web build"]
```

## Testing

Test scripts are project-specific. Define them in your `devbox.json`.

```bash
# Plugin-provided
devbox run test:metro           # Test Metro bundler setup

# User-defined scripts (add to your devbox.json shell.scripts):
# "test": ["npm test"]
# "test:e2e:android": ["process-compose -f tests/test-suite-android-e2e.yaml --no-server --tui=${TEST_TUI:-false}"]
# "test:e2e:ios": ["process-compose -f tests/test-suite-ios-e2e.yaml --no-server --tui=${TEST_TUI:-false}"]

# Skip unused platform for faster startup
devbox run --pure -e IOS_SKIP_SETUP=1 test:e2e:android
devbox run --pure -e ANDROID_SKIP_SETUP=1 test:e2e:ios
```

## Configuration

```bash
# Show configuration
devbox run android.sh config show
devbox run ios.sh config show
```

## Diagnostics

```bash
# Plugin-provided
devbox run doctor              # Health check
devbox run verify:setup        # Quick verification
devbox run test:metro          # Test Metro setup
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

# Reset Metro cache
devbox run rn:metro:clean android
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

The commands below assume you have defined `build:android`, `build:ios`, `start:android`, and `start:ios` in your `devbox.json`.

```bash
# Full Android workflow
devbox run start:emu              # Plugin-provided
npm install
devbox run build:android          # User-defined
devbox run start:android          # User-defined

# Full iOS workflow
devbox run start:sim              # Plugin-provided
npm install
cd ios && pod install && cd ..
devbox run build:ios              # User-defined
devbox run start:ios              # User-defined
```

## Process Isolation

```bash
# Run multiple test suites in parallel (user-defined test scripts)
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

.devbox/virtenv/               # Runtime directory (auto-regenerated, never edit)
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
