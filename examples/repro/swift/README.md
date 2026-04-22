# Segment Swift Bug Reproduction Example

This is a ready-to-use iOS app for reproducing and debugging issues with the Segment Analytics Swift SDK. If a customer reports a bug or unexpected behavior, you can use this example to quickly replicate and investigate the issue.

## What This Example Provides

- **Segment Analytics Swift SDK** (v1.6.2+) - The core tracking library
- **Amplitude Destination Plugin** (v1.2.0+) - An example of how destinations integrate
- **ConsoleLogger Plugin** - Prints all events to your console for easy debugging
- **Interactive Demo UI** - Buttons to trigger track, identify, and screen events
- **Secure Config Management** - Your API keys are never committed to Git
- **Isolated Build Environment** - Everything stays in this folder, no interference with other projects

## Prerequisites and Installation

**You need TWO things installed before you can run this example:**

1. ✅ **Xcode** - Apple's development tools (**NOT included with Devbox - you must install separately**)
2. ✅ **Devbox** - Environment manager that handles everything else

Follow these steps in order. Each step has inline instructions you can follow right now.

---

## Step 1: Make Sure You Have macOS

iOS development requires macOS. If you're on Windows or Linux, you'll need access to a Mac (physical or virtual).

---

## Step 2: Install Xcode

**⚠️ IMPORTANT: Xcode is NOT included with Devbox. You must install it separately from the Mac App Store.**

Xcode is Apple's development environment. It's about 15 GB and takes 30-60 minutes to download and install.

### Install Xcode Now:

**1. Open the App Store**
   - Look for the **App Store** icon in your dock (blue icon with a white "A")
   - Or click the Apple menu (top-left) → **App Store**

**2. Search and Install**
   - In the App Store, search for **"Xcode"**
   - Click **Get** or **Install** (it's free)
   - Enter your Apple ID password if prompted
   - Wait for it to download and install (30-60 minutes depending on internet speed)

**3. Open Xcode Once**
   - After installation, open Xcode from your Applications folder
   - Click **Agree** when you see the license agreement
   - Wait for additional components to install (a few minutes)
   - You can close Xcode after this

### Verify Xcode Installation:

**Open Terminal:**
- Press `Command (⌘) + Space` 
- Type "Terminal" and press Enter
- A window with black text will open

**Check if Xcode is installed:**

Copy this command, paste it into Terminal, and press Enter:
```bash
xcodebuild -version
```

**✅ Success looks like:**
```
Xcode 16.2
Build version 16B5109o
```

**❌ If you see an error:**
- Make sure Xcode finished installing completely
- Open Xcode once to accept the license
- Run this command to set it up:
  ```bash
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  ```
- Enter your Mac password when prompted

---

## Step 3: Install Devbox

Devbox manages iOS simulators and build tools, but **it requires Xcode to be installed first** (from Step 2).

### Install Devbox Now:

**1. Terminal Should Already Be Open** (from verifying Xcode above)
   - If not: Press `Command (⌘) + Space`, type "Terminal", press Enter

**2. Run the Installation Command**

Copy this entire line, paste it into Terminal, and press Enter:
```bash
curl -fsSL https://get.jetify.com/devbox | bash
```

You'll see text scrolling as it installs. Takes about 1-2 minutes.

**3. Close and Reopen Terminal (CRITICAL!)**
   - Click **Terminal** menu → **Quit Terminal**
   - Press `Command (⌘) + Space`, type "Terminal", press Enter again
   - This step is required for Devbox to work!

### Verify Devbox Installation:

In the new Terminal window, type this and press Enter:
```bash
devbox version
```

**✅ Success looks like:**
```
0.15.0
```

**❌ If you see "command not found":**
- Did you close and reopen Terminal? (Most common issue!)
- Quit Terminal completely (Command + Q) and open a fresh window
- If still broken, re-run the curl command from step 2 above

---

## Step 4: Download the Code

### Download Now:

**1. Download the Repository**
   - Go to: https://github.com/segment-integrations/mobile-devtools
   - Click the green **Code** button
   - Click **Download ZIP**
   - Wait for download to complete (file will be in your Downloads folder)

**2. Unzip the File**
   - Go to your Downloads folder
   - Double-click `mobile-devtools-main.zip`
   - You'll see a new folder: `mobile-devtools-main`

**3. Navigate to the Swift Example in Terminal**

Copy and paste this into Terminal and press Enter:
```bash
cd ~/Downloads/mobile-devtools-main/examples/repro/swift
```

**If you saved it somewhere else:** Replace `~/Downloads` with the actual folder location.

### Verify You're in the Right Place:

Type this and press Enter:
```bash
ls
```

**✅ You should see:**
```
Config.example.swift
README.md
devbox.json
ios/
ios.xcodeproj/
scripts/
tests/
```

If you see these files, you're ready to run the app! ✅

---

## Quick Start - Run the App

You're now in the Swift example directory with Xcode and Devbox installed. Let's run it!

### Run the App Now:

Copy this command and paste it into Terminal, then press Enter:
```bash
devbox run --pure start:app
```

### What Happens Next:

**First time (slow - 5-10 minutes):**
- Devbox sets up the environment
- Downloads iOS simulators
- Builds the app
- Launches iPhone simulator
- Installs and opens the app

**After first time (fast - 1-2 minutes):**
- Just builds and launches

**You'll see:**
- Lots of text scrolling in Terminal (that's normal!)
- An iPhone simulator window will open
- The app will launch with buttons you can tap

### When the App Launches:

You'll see an iPhone screen with:
- **Track Event** button - Tap to send an event
- **Identify User** button - Tap to identify a user
- **Track Screen** button - Tap to track a screen view
- **Amplitude Toggle** - Switch to enable Amplitude destination

**Watch Terminal for Event Logs:**
When you tap buttons, Terminal will show:
```
📊 Track Event: Button Pressed
   Properties: {"button": "Track Event", "count": 1}
```

**Congratulations!** 🎉 You're now running the Swift repro example!

---

## What Does `--pure` Mean?

The `--pure` flag tells Devbox to use a completely isolated environment with no interference from other tools on your Mac. This ensures everyone sees the same behavior.

**What you should see:**
- Terminal will show build progress messages
- A simulator window will open showing an iPhone screen
- The app will launch with a simple interface showing buttons like "Track Event", "Identify User", etc.

**What does `--pure` mean?**
The `--pure` flag tells Devbox to use only the tools it provides, ignoring anything else on your system. This ensures consistent, reproducible builds.

## Setting Up Your Segment Account (Optional)

The example comes with a demo write key already configured, so you can use it immediately. If you want to connect your own Segment source to see data flowing into your account, follow these steps:

### Step 1: Copy the Configuration Template

In Terminal, run:
```bash
cp Config.example.swift ios/Config.swift
```

This creates a new file called `Config.swift` in the `ios` folder. This file is where you'll put your API key.

### Step 2: Get Your Write Key from Segment

1. Go to https://app.segment.com and log in
2. Click on **Sources** in the left sidebar
3. Select your iOS source (or create a new one)
4. Click **Settings** at the top
5. Click **API Keys** in the left menu
6. Copy the **Write Key** (it looks like: `1a2b3c4d5e6f7g8h9i0j`)

### Step 3: Add Your Write Key to the Config File

Open the file `ios/Config.swift` in any text editor and replace `YOUR_WRITE_KEY_HERE` with your actual write key:

```swift
enum Config {
    static let segmentWriteKey = "1a2b3c4d5e6f7g8h9i0j"  // Your actual write key here
}
```

Save the file.

**Note:** This file is automatically ignored by Git, so your write key will never be committed or shared accidentally.

### Step 4: Rebuild and Run

After updating the config, rebuild the app:
```bash
devbox run --pure start:app
```

Now events will flow to your Segment account!

## Using the Demo App

Once the app is running in the simulator, you'll see several interactive buttons:

### Track Event Button
Tap this to send a track event to Segment. Each time you tap it, a counter increments. The event includes:
- Event name: "Button Pressed"
- Properties: button name and tap count

### Identify User Button
Tap this to identify a user. The identify call includes:
- User ID: "demo-user-123"
- Traits: name, email, signup date

### Track Screen Button
Tap this to record a screen view event. Screen tracking lets you see which screens users visit in your analytics.

### Amplitude Destination Toggle
This toggle adds the Amplitude destination plugin to demonstrate destination functionality.

**Important notes:**
- The toggle only adds the plugin when switched on
- Due to SDK architecture, switching it off doesn't actually remove the plugin (this is a known limitation)
- To see events in Amplitude, you need to configure the Amplitude destination in your Segment workspace
- No separate Amplitude API key is needed - events flow through Segment to Amplitude

**How to see events in Amplitude:**
1. Log into your Segment workspace at https://app.segment.com
2. Go to **Connections** → **Destinations**
3. Add the **Amplitude** destination if not already configured
4. Enable it for your iOS source
5. Events tracked in the app will now flow to Amplitude

**Where are the events?**
All events are printed to the Terminal window where you ran `devbox run --pure start:app`. Look for lines starting with 📊 to see the events as they're tracked.

You can also see events in the Segment Debugger:
1. Go to https://app.segment.com
2. Navigate to your Source
3. Click **Debugger** in the left menu
4. Watch events appear in real-time (may take a few seconds)

## Available Commands

Here are all the commands you can run. Type these in Terminal from the `examples/repro/swift` directory:

**Build the app (without running it):**
```bash
devbox run --pure build
```
This compiles the code but doesn't launch the simulator or app.

**Build and run the app:**
```bash
devbox run --pure start:app
```
This is the command you'll use most often - it builds and launches everything.

**Build for release mode:**
```bash
devbox run --pure build:release
```
Release builds are optimized for performance. Use this to test how the app behaves in production.

**Clean build artifacts:**
```bash
devbox run --pure build:clean
```
If something isn't working, run this to delete all build files and start fresh. Then run `devbox run --pure build` again.

**Run unit tests:**
```bash
devbox run --pure test
```
Runs the automated tests included in the project.

**Run end-to-end tests:**
```bash
devbox run --pure test:e2e
```
Runs full integration tests that launch the app and verify functionality.

**List available iOS simulators:**
```bash
devbox run --pure ios.sh devices list
```
Shows all the iPhone/iPad simulators you can use.

**Run on a specific simulator:**
```bash
devbox run --pure start:app iphone15
```
Launches the app on iPhone 15 instead of the default device.

**Share your reproduction:**
```bash
devbox run share
```
Packages your reproduction into a zip file for sharing via Jira, email, or Slack. Automatically commits changes and creates a properly named archive.

## Understanding the Console Output

When you run the app, the Terminal shows a lot of output. Here's what to look for:

**Build progress:**
```
Building for debugging...
Build succeeded
```

**Simulator starting:**
```
[INFO] [simulator.sh] Starting simulator: iPhone 15 Pro
```

**App launching:**
```
[INFO] [deploy.sh] Installing app bundle
[INFO] [deploy.sh] Launching app
```

**Event tracking (from ConsoleLogger plugin):**
```
📊 Track Event: Button Pressed
   Properties: ["button": "Track Event", "count": 1, "timestamp": "2026-04-22T10:30:00Z"]
```

## How to Create Bug Reproductions

When a customer reports a bug with the Segment SDK, here's how to reproduce it using this example:

### Step 1: Start Fresh

Clean any previous builds:
```bash
cd examples/repro/swift
devbox run --pure build:clean
```

### Step 2: Replicate Customer Setup

If the customer is using their own write key, update `ios/Config.swift` with their key (get permission first!).

### Step 3: Modify the Code to Match Their Use Case

Open `ios/ContentView.swift` in a text editor (you can use Xcode, VS Code, or any editor). Find the function that relates to the customer's issue and modify it.

For example, if a customer reports that identify isn't working:

```swift
private func identifyUser() {
    // Change this to match exactly what the customer is doing
    analytics.identify(
        userId: "their-user-id",
        traits: [
            "name": "Their Name",
            "email": "their@email.com"
        ]
    )
}
```

Save the file.

### Step 4: Run and Observe

Launch the app:
```bash
devbox run --pure start:app
```

Tap the relevant button in the simulator and watch the Terminal output. The ConsoleLogger plugin shows exactly what's being sent to Segment.

### Step 5: Test Different SDK Versions

To test if the bug exists in different versions of the SDK:

1. Open `ios.xcodeproj` in Xcode (double-click the file in Finder)
2. In Xcode, click on the project name at the top of the left sidebar
3. Click on the **Package Dependencies** tab
4. Find `analytics-swift` in the list
5. Click the version number and select a different version to test
6. Click **Done**, then rebuild: `devbox run --pure build`


### Step 6: Share Your Reproduction

Once you've reproduced the bug, package it for sharing:

```bash
devbox run share
```

This command creates a zip file with everything needed. For complete instructions on uploading to Jira, sharing via email, or Slack, see the **[Sharing Reproductions](../README.md#sharing-reproductions)** section in the main repro README.

## Troubleshooting Common Issues

### "Command not found: devbox"

**Problem:** Terminal doesn't recognize the `devbox` command.

**Solution:**
1. Make sure you installed Devbox (see Step 3 in Prerequisites)
2. Close Terminal completely and open a new window
3. Try running `devbox version` - if you see a version number, it's working
4. If still not working, re-run the installation command:
   ```bash
   curl -fsSL https://get.jetify.com/devbox | bash
   ```

### "xcrun: error: SDK cannot be located"

**Problem:** Xcode Command Line Tools aren't set up correctly.

**Solution:**
```bash
sudo xcode-select --reset
xcode-select --install
```

### App Won't Build

**Problem:** The build fails with errors.

**Solution 1 - Clean and rebuild:**
```bash
devbox run --pure build:clean
devbox run --pure build
```

**Solution 2 - Make sure Xcode is installed:**
```bash
xcodebuild -version
```
If this errors, install Xcode from the App Store.

**Solution 3 - Accept Xcode license:**
Open Xcode once and accept the license agreement when prompted.

### Simulator Not Found

**Problem:** Error says simulator device not found.

**Solution - List available simulators:**
```bash
devbox run --pure ios.sh devices list
```

If no simulators are shown, create one:
```bash
devbox run --pure ios.sh devices create iphone15 --runtime 17.5
devbox run --pure ios.sh devices sync
```

### Config.swift File Missing

**Problem:** Build fails saying `Config.swift` not found.

**Solution:**
```bash
cp Config.example.swift ios/Config.swift
```

The build needs this file even if you're using the demo write key.

### Events Not Showing in Segment

**Problem:** You're tapping buttons but not seeing events in Segment.

**Checklist:**
1. Check the write key in `ios/Config.swift` is correct
2. Look at the Terminal output - do you see 📊 event logs from ConsoleLogger?
3. Open the Segment Debugger: https://app.segment.com → Your Source → Debugger
4. Try tapping the button again and wait 5-10 seconds for events to appear
5. Make sure the simulator has internet (it should by default)

### Simulator Shows Black Screen

**Problem:** The simulator opens but stays black or shows a white screen.

**Solution:**
1. Wait a moment - it can take 10-20 seconds to fully start
2. Click on the simulator window to make sure it's active
3. Restart the simulator:
   ```bash
   # Stop the current run (press Ctrl+C in Terminal if it's still running)
   devbox run --pure start:app
   ```

### "Permission Denied" Errors

**Problem:** Commands fail with permission denied errors.

**Solution:**
```bash
chmod +x scripts/*  # Make scripts executable
```

Or run commands with `bash` explicitly:
```bash
bash -c "devbox run --pure build"
```

### Can't Find Terminal

**Problem:** You're not sure how to open Terminal on macOS.

**Solution:**
1. Press `Command (⌘) + Space` to open Spotlight
2. Type "Terminal"
3. Press Enter

Or:
1. Open Finder
2. Go to Applications → Utilities → Terminal
3. Double-click Terminal

## Understanding the Plugin System

This example demonstrates two types of plugins that extend the Segment SDK:

### ConsoleLogger Plugin (Custom Plugin)

**What it does:** Prints every event to the Terminal in a readable format.

**Why it's useful:** You can see exactly what's being sent to Segment without needing to check the debugger or use network inspection tools.

**Location:** `ios/ConsoleLoggerPlugin.swift`

**Example output:**
```
📊 Track Event: Button Pressed
   Properties: {
     "button": "Track Event",
     "count": 1,
     "timestamp": "2026-04-22T10:30:00Z"
   }
```

### Amplitude Destination Plugin (Official Plugin)

**What it does:** Forwards events from Segment to Amplitude's SDK for session tracking and analytics.

**Why it's included:** It demonstrates how destination plugins work and lets you test destination-related issues.

**Configuration:**
- No Amplitude API key needed in the app code
- Events flow through Segment's cloud destination to Amplitude
- Configure the Amplitude destination in your Segment workspace at https://app.segment.com

**Features:**
- Toggleable in the UI (adds plugin when enabled)
- Automatic session tracking
- Events forwarded to Amplitude when the destination is configured in Segment

**Known limitation:** When you toggle the switch off, the plugin isn't actually removed from the SDK due to architectural constraints. This is expected behavior and can be useful for testing plugin lifecycle issues.

## How to Add Your Own Plugins

You can extend the Segment SDK by creating custom plugins or adding third-party destination plugins. Here's how:

### Adding an Official Segment Destination Plugin

Official destination plugins are available as Swift packages. For example, to add the Firebase destination:

**Step 1: Add the package dependency**
1. Open `ios.xcodeproj` in Xcode (double-click the file)
2. Select the project in the left sidebar
3. Click the **Package Dependencies** tab
4. Click the **+** button
5. Enter the package URL: `https://github.com/segment-integrations/analytics-swift-firebase`
6. Click **Add Package**
7. Select the library to add and click **Add Package** again

**Step 2: Import and add the plugin in code**

Open `ios/ContentView.swift` and add at the top:
```swift
import SegmentFirebase  // Import the plugin
```

In the `init()` method, add the plugin:
```swift
init() {
    let configuration = Configuration(writeKey: Config.segmentWriteKey)
        .flushInterval(10)

    self.analytics = Analytics(configuration: configuration)

    // Add plugins
    analytics.add(plugin: ConsoleLoggerPlugin())
    analytics.add(plugin: IDFAPlugin())
    analytics.add(plugin: FirebaseDestination())  // Add your new plugin
    
    print("🚀 Segment Analytics initialized")
}
```

**Step 3: Configure the destination in Segment**

Most destination plugins require you to also configure the destination in your Segment workspace:
1. Go to https://app.segment.com
2. Navigate to **Connections** → **Destinations**
3. Add and configure the destination (e.g., Firebase)
4. Enable it for your iOS source

**Step 4: Rebuild and test**
```bash
devbox run --pure build
devbox run --pure start:app
```

### Creating a Custom Plugin

Custom plugins let you intercept, modify, or enrich events. Here's how to create one:

**Step 1: Create a new Swift file**

Create a file like `ios/MyCustomPlugin.swift`:

```swift
import Foundation
import Segment

class MyCustomPlugin: Plugin {
    let type: PluginType = .enrichment
    weak var analytics: Analytics?
    
    func execute<T: RawEvent>(event: T?) -> T? {
        guard var workingEvent = event else { return event }
        
        // Modify the event (example: add custom property)
        if var trackEvent = workingEvent as? TrackEvent {
            trackEvent.properties?["custom_field"] = "custom_value"
            workingEvent = trackEvent as! T
        }
        
        return workingEvent
    }
}
```

**Step 2: Add the plugin in ContentView.swift**

```swift
init() {
    let configuration = Configuration(writeKey: Config.segmentWriteKey)
        .flushInterval(10)

    self.analytics = Analytics(configuration: configuration)

    // Add your custom plugin
    analytics.add(plugin: MyCustomPlugin())
    analytics.add(plugin: ConsoleLoggerPlugin())
    
    print("🚀 Segment Analytics initialized")
}
```

**Step 3: Test it**
```bash
devbox run --pure start:app
```

Tap "Track Event" and check the console output - you should see your custom field added to every track event.

### Plugin Types

The Segment SDK supports different plugin types:

**`.before` plugins:** Run before Segment processes the event
- Use for: Early validation, event filtering

**`.enrichment` plugins:** Add or modify event data
- Use for: Adding context, user properties, custom fields

**`.destination` plugins:** Send events to third-party services
- Use for: Forwarding events to analytics tools, error trackers

**`.after` plugins:** Run after Segment processes the event
- Use for: Logging, debugging, analytics

**Example plugin type usage:**
```swift
class MyPlugin: Plugin {
    let type: PluginType = .enrichment  // Change this based on when you want it to run
    weak var analytics: Analytics?
    
    func execute<T: RawEvent>(event: T?) -> T? {
        // Your plugin logic here
        return event
    }
}
```

### Available Official Destination Plugins

Segment provides official destination plugins for popular services:

- **Amplitude:** `https://github.com/segment-integrations/analytics-swift-amplitude` (included in this example)
- **Firebase:** `https://github.com/segment-integrations/analytics-swift-firebase`
- **Mixpanel:** `https://github.com/segment-integrations/analytics-swift-mixpanel`
- **Braze:** `https://github.com/segment-integrations/analytics-swift-braze`
- **AppsFlyer:** `https://github.com/segment-integrations/analytics-swift-appsflyer`

See the [Segment Analytics Swift documentation](https://github.com/segmentio/analytics-swift) for a complete list.

### Troubleshooting Plugin Issues

**Plugin not being called:**
1. Make sure you added it to analytics: `analytics.add(plugin: MyPlugin())`
2. Check that the plugin type is correct for when you want it to run
3. Verify the `execute` method returns the event (not nil)

**Can't import plugin package:**
1. Make sure you added the Swift package dependency in Xcode
2. Clean and rebuild: `devbox run --pure build:clean && devbox run --pure build`
3. Check the package URL is correct

**Events not reaching destination:**
1. Verify the destination is configured in your Segment workspace
2. Check the destination is enabled for your iOS source
3. Look at the Segment debugger to see if events are being received by Segment
4. Check the destination's specific setup requirements (some need API keys in the Segment UI)

## Why Devbox?

You might wonder why we use Devbox instead of just opening the project in Xcode directly. Here's why:

**Reproducibility:** Everyone who uses this example gets the exact same versions of tools, SDKs, and simulators. This means "it works on my machine" problems are eliminated.

**Isolation:** All build artifacts, dependencies, and configuration stay in this folder. You can have multiple projects using different versions of tools without conflicts.

**Speed for Support Teams:** Customer Success and Support engineers can run reproductions without spending hours setting up Xcode, configuring simulators, or managing SDK versions.

**Consistency Across Environments:** Developers, CI pipelines, and support engineers all use identical environments, making debugging easier.

**You can still use Xcode!** Devbox doesn't prevent you from opening `ios.xcodeproj` in Xcode. You get the best of both worlds - Xcode's powerful IDE plus Devbox's reproducible environment.

## Build Configuration Details

This example uses project-local build output for complete isolation:

**DerivedData Location:** `./DerivedData/`
All build artifacts (compiled code, temporary files, etc.) are stored in this directory.

**Why this matters:**
- Multiple reproduction cases can coexist on the same machine without interfering
- You can completely delete `DerivedData` and rebuild without affecting other projects
- It's gitignored, so large build artifacts won't bloat your repository

**To clean build artifacts:**
```bash
devbox run --pure build:clean
# Or manually: rm -rf DerivedData
```

## Plugin Configuration

This example uses a **local path include** because it's part of the mobile-devtools repository:

```json
{
  "include": [
    "path:../../../plugins/ios/plugin.json"
  ]
}
```

If you copy this example outside the repository, change `devbox.json` to use the GitHub URL:

```json
{
  "include": [
    "github:segment-integrations/mobile-devtools?dir=plugins/ios&ref=main"
  ]
}
```

This tells Devbox to fetch the iOS plugin directly from GitHub instead of looking for a local copy.

## Project Structure

Here's what each file and folder does:

```
examples/repro/swift/
├── ios/                              # Swift source code
│   ├── iosApp.swift                  # App entry point (where the app starts)
│   ├── ContentView.swift             # Main UI with buttons and demo logic
│   ├── ConsoleLoggerPlugin.swift     # Custom plugin that logs events
│   └── Config.swift                  # Your write key (gitignored, create from Config.example.swift)
├── ios.xcodeproj/                    # Xcode project file
├── iosTests/                         # Unit tests
├── iosUITests/                       # UI automation tests  
├── devbox.json                       # Devbox configuration (tools, commands)
├── devbox.lock                       # Locked versions of tools
├── devbox.d/ios/devices/             # iOS simulator definitions
├── DerivedData/                      # Build output (gitignored)
├── Config.example.swift              # Template for Config.swift
└── README.md                         # This file
```

## Related Resources

- [Segment Analytics Swift SDK Documentation](https://github.com/segmentio/analytics-swift)
- [Amplitude Destination Plugin](https://github.com/segmentio/analytics-swift-amplitude)
- [iOS Plugin Reference](../../../plugins/ios/REFERENCE.md) - Advanced configuration options
- [Devbox Documentation](https://www.jetify.com/devbox) - Learn more about Devbox

## Getting Help

**Issues with this example:**
Open an issue in the [mobile-devtools repository](https://github.com/segment-integrations/mobile-devtools/issues)

**Segment SDK bugs:**
Check the [analytics-swift issues](https://github.com/segmentio/analytics-swift/issues)

**Devbox problems:**
See the [Devbox documentation](https://www.jetify.com/devbox/docs/) or [Devbox community](https://discord.gg/jetify)

**Still stuck?**
Ask in your team's Slack channel or reach out to the Mobile SDK team.
