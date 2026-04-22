# Bug Reproduction Examples

Pre-configured, minimal apps for reproducing Segment SDK issues. These examples help customer support, CSMs, and engineers quickly reproduce and diagnose bugs in a consistent environment.

## Available Examples

### [Swift/iOS](./swift/)

Fully-configured iOS app for reproducing Segment Analytics Swift SDK issues.

**Includes:** Amplitude destination, ConsoleLogger, interactive UI

**Quick links:**
- [Prerequisites & Installation](./swift/README.md#prerequisites-and-installation) - Installing Xcode and Devbox
- [Quick Start](./swift/README.md#quick-start---run-the-app) - Running the app
- [Creating Bug Reproductions](./swift/README.md#how-to-create-bug-reproductions) - Workflow for reproducing issues
- [Full Documentation](./swift/README.md) - Complete guide

## Purpose

### For Customer Support and CSMs

When a customer reports a bug:
1. Use an example that matches their SDK (Swift, Android, React Native)
2. Modify the code to replicate their exact use case
3. Run the reproduction to confirm the issue
4. Share the packaged reproduction with engineering (one command!)
5. Test fixes across different SDK versions

No need to set up development environments from scratch - everything is pre-configured.

### For Customers

Use these examples as templates when reporting issues:
1. Clone this repository
2. Modify the example to demonstrate the bug
3. Share it with support
4. Everyone sees identical behavior (reproducible environment)

This eliminates "works on my machine" problems.

### For Engineering

- Validate bug reports with exact reproduction steps
- Test fixes across different SDK versions
- Create regression tests
- Verify behavior is consistent across platforms

## Why Devbox?

**Reproducibility:** Everyone runs the exact same toolchain. No "works on my machine" problems.

**Isolation:** Each example has its own build directory and configuration. Multiple reproductions can coexist without conflicts.

**Speed:** Run reproductions in minutes without manual environment setup.

**Consistency:** CI, developers, and support all use identical environments.

**Simplicity:** One command (`devbox run --pure start:app`) to build and launch.

## General Workflow

This is the conceptual workflow for using any reproduction example. See the specific example's README for detailed commands.

### 1. Choose an Example

Pick the example matching the customer's SDK:
- `swift/` - iOS apps using Analytics Swift SDK
- (Future: `android/`, `react-native/`, etc.)

### 2. Set Up Your Environment

Each example's README has specific installation instructions. Generally you need:
- Platform tools (Xcode for iOS, Android Studio for Android, etc.)
- Devbox (handles SDKs, simulators, dependencies)

### 3. Modify the Code

Update the example to match the customer's issue:
- Replicate their SDK configuration
- Use their event names and properties
- Add/remove plugins they're using
- Match their SDK version

### 4. Reproduce the Issue

Run the example and observe the behavior:
```bash
devbox run --pure start:app
```

Watch console output for debugging information. The examples include logging plugins that show exactly what's being sent to Segment.

### 5. Test Across SDK Versions

Change the SDK version in the package configuration and rebuild:
- Identify when the bug was introduced
- Verify fixes work across versions
- Test with customer's exact SDK version

### 6. Share the Reproduction

Package everything for sharing using the built-in share command:
```bash
devbox run share
```

This automatically:
- ✅ Commits your changes (no Git knowledge needed)
- ✅ Creates a zip archive with timestamp and commit hash
- ✅ Excludes build artifacts (keeps file small)
- ✅ Includes setup instructions
- ✅ Shows where the file is saved
- ✅ Copies path to clipboard (macOS)

## Sharing Reproductions

Every example includes a `share` command that packages reproductions for easy sharing via Jira, email, or Slack.

### Quick Share

```bash
cd swift  # or another example
# Make your changes to reproduce the issue
devbox run share
```

**Output:**
```
✅ Archive created successfully!

Archive Details:
  Name:     swift-repro-a1b2c3d-20260422-143052.zip
  Size:     2.3M
  Location: ~/mobile-devtools/shared-repros/swift-repro-a1b2c3d-20260422-143052.zip
  Commit:   a1b2c3d

Next Steps:
1️⃣  Upload to Jira: Drag and drop the zip onto the issue
2️⃣  Or share via email: Attach the zip file
3️⃣  Or post to Slack: Drag into your message
```

### What's In The Archive

Each package contains:
- All source code showing the issue
- Project configuration (devbox.json, etc.)
- Setup instructions (REPRO-INFO.txt)
- Git patch showing your exact changes

Excludes:
- Build artifacts (DerivedData, build/, etc.)
- Git history
- Devbox cache
- Dependencies (node_modules, Pods, etc.)

Files are typically 2-5 MB - small enough to attach anywhere.

### How to Share

**Jira (Recommended):**
1. Open the Jira issue
2. Drag the zip file onto the issue page
3. Add a comment:
   ```
   Reproduction attached (commit: a1b2c3d)
   
   Changes: Modified identify call to match customer setup
   SDK version: 1.6.2
   
   To run: Extract and run "devbox run --pure start:app"
   ```

**Email:**
- Attach the zip file
- Include the commit hash in your message
- Describe what you changed

**Slack:**
- Drag the zip into the relevant channel
- Include Jira issue link
- Brief description of the issue

### For Recipients

Anyone receiving a reproduction can run it immediately:

```bash
# Extract
unzip swift-repro-a1b2c3d-20260422-143052.zip
cd swift-repro-a1b2c3d-20260422-143052

# Install Devbox if needed (one-time)
curl -fsSL https://get.jetify.com/devbox | bash

# Run
devbox run --pure start:app
```

Everything needed is included. No manual setup required.

## What Makes These Examples Special

**Minimal:** Only the essential code to demonstrate SDK functionality. No clutter.

**Interactive:** UI buttons trigger SDK methods. Immediate visual feedback.

**Secure:** API keys in gitignored files. Safe to commit reproductions without exposing credentials.

**Isolated:** Project-local build artifacts. Multiple reproductions coexist without conflicts.

**Debuggable:** Custom logging plugins show all SDK activity in the console.

**Pure Environment:** The `--pure` flag ensures clean, isolated execution with no system interference.

**One-Command Sharing:** Built-in `share` command packages reproductions - no Git knowledge required.

## Adding New Examples

When adding a new platform or SDK:

**Required Structure:**
1. Create directory: `examples/repro/{platform}/`
2. Include mobile-devtools plugin in `devbox.json`
3. Add interactive UI with basic SDK operations (track, identify, screen, etc.)
4. Include custom logging plugin for console debugging
5. Use gitignored config files for API keys
6. Configure project-local build output
7. Add `scripts/share.sh` (copy from Swift example)
8. Add `share` command to `devbox.json` scripts section

**Required Documentation:**
- `README.md` with platform-specific setup instructions
- Prerequisites (platform tools + Devbox)
- Quick start guide
- Troubleshooting section

**Follow the Swift example pattern** - it demonstrates the complete structure.

## Getting Started

1. **Choose your example:** Go to the example directory for your SDK (e.g., `cd swift`)
2. **Follow that README:** Each example has complete, platform-specific setup instructions
3. **Run the app:** Usually just `devbox run --pure start:app`
4. **Make changes:** Modify code to reproduce the customer issue
5. **Share it:** Run `devbox run share` and upload to Jira

Each example's README is self-contained with everything you need.

## Support and Resources

**For reproduction examples:**
- Issues: [mobile-devtools issues](https://github.com/segment-integrations/mobile-devtools/issues)
- Tag: `reproduction-examples`

**For Segment SDK bugs:**
- Create reproduction using these examples
- Open issue in SDK repository
- Attach reproduction zip file

**For Devbox:**
- [Devbox Documentation](https://www.jetify.com/devbox/docs/)
- [Devbox Repository](https://github.com/jetify-com/devbox)

## Related Resources

- [iOS Plugin Reference](../../plugins/ios/REFERENCE.md)
- [Android Plugin Reference](../../plugins/android/REFERENCE.md)
- [React Native Plugin Reference](../../plugins/react-native/REFERENCE.md)
- [Segment Analytics Swift SDK](https://github.com/segmentio/analytics-swift)
