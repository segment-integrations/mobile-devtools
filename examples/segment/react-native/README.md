# Segment React Native Bug Reproduction Example

A ready-to-use React Native app for reproducing and debugging issues with the Segment Analytics React Native SDK. Use this to demonstrate bugs, test unexpected behavior, or create minimal reproductions for issue reports.

## What This Example Provides

- **@segment/analytics-react-native** (v2.21+) - The core tracking library
- **ConsoleLogger Plugin** - Prints all events to the console for debugging
- **Interactive Demo UI** - Buttons to trigger track, identify, and screen events
- **Secure Config Management** - Write key in a file you can swap without committing secrets
- **Isolated Build Environment** - Everything stays in this folder via Devbox

## Prerequisites

1. **Xcode** (for iOS) - Install from Mac App Store
2. **Devbox** - Environment manager

```bash
curl -fsSL https://get.jetify.com/devbox | bash
```

## Quick Start

```bash
cd examples/segment/react-native

# Enter devbox environment
devbox shell

# Install JS dependencies
devbox run install

# iOS
devbox run build:ios
devbox run start:sim
devbox run start:app:ios

# Android
devbox run build:android
devbox run start:emu
devbox run start:app:android
```

## Configuration

Edit `src/Config.ts` to use your Segment write key:

```typescript
export const Config = {
  segmentWriteKey: 'YOUR_REAL_WRITE_KEY',
  // ...
};
```

With the demo key, events are queued locally and logged to the console but never sent to Segment.

## Available Commands

Run from the `examples/segment/react-native` directory:

```bash
devbox run install           # Install node_modules
devbox run build:android     # Build Android debug APK
devbox run build:ios         # Build iOS debug app
devbox run start:app:android # Build + install + launch on emulator
devbox run start:app:ios     # Build + install + launch on simulator
devbox run start:metro       # Start Metro bundler
devbox run stop:metro        # Stop Metro bundler
devbox run start:emu         # Start Android emulator
devbox run stop:emu          # Stop Android emulator
devbox run start:sim         # Start iOS simulator
devbox run stop:sim          # Stop iOS simulator
devbox run share             # Package reproduction for sharing
```

## Reproducing an Issue

1. Modify `App.tsx` to replicate the customer's SDK usage
2. Update `src/Config.ts` with their write key (or keep demo key for local testing)
3. Run the app and observe console output
4. Use `devbox run share` to package the reproduction

## Project Structure

```
examples/segment/react-native/
├── App.tsx                     # Main UI with track/identify/screen buttons
├── src/
│   ├── Config.ts               # Write key configuration
│   └── ConsoleLoggerPlugin.ts  # Logs all events to console
├── android/                    # Native Android shell
├── ios/                        # Native iOS shell
├── devbox.json                 # Devbox config (includes react-native plugin)
├── devbox.d/
│   ├── android/devices/        # Android emulator definitions (min/max)
│   └── ios/devices/            # iOS simulator definitions (min/max)
└── package.json                # JS dependencies
```
