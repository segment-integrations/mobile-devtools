# Segment Swift Bug Reproduction Example

This is a fully-configured iOS app for reproducing Segment Analytics Swift SDK issues. Use this as a starting point when customers or CSMs need to demonstrate bugs or unexpected behavior.

## What's Included

- **Segment Analytics Swift SDK** (v1.6.2+) - Core analytics tracking
- **Amplitude Destination Plugin** (v1.2.0+) - Example destination integration
- **ConsoleLogger Custom Plugin** - Logs all events to console for debugging
- **Interactive Demo UI** - Buttons to test track, identify, and screen events
- **Secure Config Management** - Gitignored `Config.swift` for API keys
- **Project-Local Builds** - DerivedData isolated to this directory

## Prerequisites

- macOS (required for iOS development)
- Xcode 14+ (included via Devbox)
- [Devbox](https://www.jetify.com/devbox/docs/installing_devbox/) installed

## Quick Start

```bash
# Clone and navigate to this directory
cd examples/repro/swift

# Build and launch the app (automatic simulator boot)
devbox run --pure start:app
```

The `--pure` flag ensures a clean, reproducible environment isolated from your system.

## How to Connect Your Segment Account

The example comes with a demo write key pre-configured. To use your own Segment source:

1. **Copy the example config file:**
   ```bash
   cp Config.example.swift ios/Config.swift
   ```

2. **Add your write key:**
   Edit `ios/Config.swift` and replace the write key:
   ```swift
   enum Config {
       static let segmentWriteKey = "YOUR_WRITE_KEY_HERE"
   }
   ```

3. **Get your write key from Segment:**
   - Go to https://app.segment.com
   - Navigate to: **Sources** → **Your iOS Source** → **Settings** → **API Keys**
   - Copy the **Write Key**

The `ios/Config.swift` file is gitignored, so your write key won't be committed to version control.

## Plugin Documentation

### 1. Amplitude Destination Plugin

The app includes Segment's official Amplitude destination plugin. You can toggle it on/off in the UI to test destination behavior.

**Features:**
- Toggle plugin at runtime via the UI switch
- Sessions automatically tracked
- Events forwarded to Amplitude when enabled

**Known limitation:** The current implementation doesn't remove the plugin when toggled off due to the Segment SDK's plugin architecture. This is expected behavior and can be used to test plugin lifecycle issues.

### 2. ConsoleLogger Plugin

A custom enrichment plugin that logs all events to the Xcode console for debugging.

**What it logs:**
- Track events with properties
- Identify calls with traits
- Screen events with properties
- Group and alias events

**Location:** `ios/ConsoleLoggerPlugin.swift`

**Example output:**
```
📊 Track Event: Button Pressed
   Properties: ["button": "Track Event", "count": 1, "timestamp": "2026-04-22T10:30:00Z"]
```

## Build Configuration

This example uses project-local build output for complete isolation:

**DerivedData Location:** `./DerivedData/`
- Build artifacts stay in this directory
- No interference with other Xcode projects
- Gitignored (won't be committed)

**Why this matters:**
- Multiple reproduction cases can coexist
- Clean environment for each bug report
- Easy to delete and rebuild from scratch

## Available Commands

```bash
# Build the app
devbox run --pure build

# Build and launch on simulator
devbox run --pure start:app

# Build release configuration
devbox run --pure build:release

# Clean build artifacts
devbox run --pure build:clean

# Run unit tests
devbox run --pure test

# Run E2E test suite
devbox run --pure test:e2e

# List available iOS simulators
devbox run --pure ios.sh devices list

# Start a specific simulator
devbox run --pure start:app iphone15
```

## Using the Demo App

The app provides an interactive UI to test Segment SDK functionality:

1. **Track Event** - Sends a track call with button press count
2. **Identify User** - Identifies a demo user with traits
3. **Track Screen** - Sends a screen view event
4. **Amplitude Toggle** - Enable/disable the Amplitude destination plugin

All events are logged to the Xcode console via the ConsoleLogger plugin.

## How to Create Bug Reproductions

When a customer reports a bug, follow this workflow:

### 1. Start with a Clean Slate

```bash
cd examples/repro/swift
devbox run --pure build:clean
```

### 2. Add Customer's Configuration

Update `ios/Config.swift` with the customer's write key (if needed):
```swift
static let segmentWriteKey = "customer_write_key_here"
```

### 3. Reproduce the Issue

Modify `ios/ContentView.swift` to match the customer's use case:

```swift
// Example: Customer reports identify not working
private func identifyUser() {
    // Replicate customer's exact identify call
    analytics.identify(
        userId: "customer-user-id",
        traits: [
            "name": "Customer Name",
            "email": "customer@example.com"
        ]
    )
}
```

### 4. Verify with Console Output

Launch the app and watch the Xcode console:
```bash
devbox run --pure start:app
```

The ConsoleLogger plugin will show exactly what's being sent to Segment.

### 5. Test Different SDK Versions

Update the package dependencies in Xcode:
1. Open `ios.xcodeproj` in Xcode
2. Select the project in the navigator
3. Go to **Package Dependencies**
4. Select `analytics-swift` and click the version
5. Test with different versions to isolate when the bug was introduced

### 6. Share the Reproduction

Create a minimal reproduction and share:
```bash
# Clean build artifacts
devbox run --pure build:clean

# Commit your changes
git add ios/ContentView.swift
git commit -m "Reproduce: describe the issue"

# Share the branch or create a patch
git format-patch HEAD~1
```

## Troubleshooting

### App Won't Build

```bash
# Clean and rebuild
devbox run --pure build:clean
devbox run --pure build
```

### Simulator Not Found

```bash
# List available simulators
devbox run --pure ios.sh devices list

# Create a new simulator
devbox run --pure ios.sh devices create iphone15 --runtime 17.5

# Sync simulators
devbox run --pure ios.sh devices sync
```

### Config.swift Missing

```bash
# Copy the example config
cp Config.example.swift ios/Config.swift

# Edit and add your write key
# (File is gitignored, so it won't be committed)
```

### Events Not Appearing in Segment

1. Check the write key in `ios/Config.swift`
2. Watch the Xcode console for ConsoleLogger output
3. Verify network connectivity (simulator has internet access)
4. Check Segment debugger: https://app.segment.com → Sources → Your Source → Debugger

### Wrong Simulator Launched

Specify the device explicitly:
```bash
devbox run --pure start:app iphone15
```

Or set the default in `devbox.json`:
```json
{
  "env": {
    "IOS_DEFAULT_DEVICE": "iphone15"
  }
}
```

## Why Use Devbox for Reproductions?

**Reproducibility:** Everyone gets the exact same Xcode, SDKs, and simulator versions.

**Isolation:** No global state pollution. Each reproduction is self-contained.

**Speed:** CSMs and support engineers can run reproductions without manual Xcode setup.

**Consistency:** CI, developers, and support all use the same environment.

## Plugin Configuration

This example uses a **local path include** for development within this repository:

```json
{
  "include": [
    "path:../../../plugins/ios/plugin.json"
  ]
}
```

If you copy this example outside the repository, change to the GitHub URL:

```json
{
  "include": [
    "github:segment-integrations/mobile-devtools?dir=plugins/ios&ref=main"
  ]
}
```

For more information, see the [iOS Plugin Reference](../../../plugins/ios/REFERENCE.md).

## Project Structure

```
examples/repro/swift/
├── ios/                        # Swift source files
│   ├── iosApp.swift            # App entry point
│   ├── ContentView.swift       # Main UI with demo buttons
│   ├── ConsoleLoggerPlugin.swift  # Custom debug plugin
│   └── Config.swift            # Gitignored config (write keys)
├── ios.xcodeproj/              # Xcode project
├── devbox.json                 # Devbox configuration
├── devbox.d/ios/devices/       # Simulator definitions
└── DerivedData/                # Project-local build artifacts
```

## Related Resources

- [Segment Analytics Swift SDK](https://github.com/segmentio/analytics-swift)
- [Amplitude Destination Plugin](https://github.com/segmentio/analytics-swift-amplitude)
- [iOS Plugin Reference](../../../plugins/ios/REFERENCE.md)
- [Devbox Documentation](https://www.jetify.com/devbox)

## Support

For issues with:
- **This reproduction example:** Open an issue in this repository
- **Segment SDK bugs:** Check the [analytics-swift issues](https://github.com/segmentio/analytics-swift/issues)
- **Devbox:** See the [Devbox documentation](https://www.jetify.com/devbox/docs/)
