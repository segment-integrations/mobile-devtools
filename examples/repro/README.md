# Bug Reproduction Examples

This directory contains pre-configured, minimal apps for reproducing Segment SDK issues. These examples are designed for customer support, CSMs, and developers who need to quickly reproduce and diagnose bugs.

## Available Examples

### [Swift/iOS](./swift/)

Fully-configured iOS app for reproducing Segment Analytics Swift SDK issues.

**What's included:**
- Segment Analytics Swift SDK (v1.6.2+)
- Amplitude destination plugin (v1.2.0+)
- ConsoleLogger custom plugin for debugging
- Interactive UI with track, identify, and screen buttons
- Gitignored config file for API keys
- Project-local build isolation

**Quick start:**
```bash
cd swift
devbox run --pure start:app
```

## Purpose

These examples serve multiple audiences:

### For Customer Support and CSMs

When a customer reports a bug, you can:
1. Modify the example to match the customer's use case
2. Run `devbox run --pure start:app` to reproduce the issue
3. Share the reproduction with engineering
4. Test fixes across different SDK versions

No Xcode configuration needed. No manual simulator setup. Just run the command.

### For Customers

Customers can use these as templates when reporting issues:
1. Clone this repository
2. Modify the example to demonstrate their bug
3. Share the modified code with support
4. Everyone sees the same behavior (reproducible environment)

### For Engineering

Use these examples to:
- Validate bug reports with exact reproduction steps
- Test fixes across different SDK versions
- Create regression tests
- Verify behavior across iOS/Android platforms

## Why Devbox?

**Reproducibility:** Everyone runs the exact same toolchain (Xcode, SDKs, simulators). No "works on my machine" problems.

**Isolation:** Each example has its own build directory and configuration. No global state pollution.

**Speed:** CSMs and support engineers can reproduce issues in seconds, without manual Xcode installation or simulator setup.

**Consistency:** CI, developers, and support all use identical environments.

**Simplicity:** One command (`devbox run --pure start:app`) builds and launches the app. No prerequisite knowledge required.

## Prerequisites

The only requirement is [Devbox](https://www.jetify.com/devbox/docs/installing_devbox/):

```bash
# macOS/Linux
curl -fsSL https://get.jetify.com/devbox | bash

# Verify installation
devbox version
```

Devbox handles all other dependencies (Xcode, SDKs, simulators, etc.).

## General Workflow

### 1. Start with a Clean Example

```bash
cd swift  # or another example
devbox run --pure build:clean
```

### 2. Configure for the Customer

Update the config file with customer-specific details:
```bash
# Swift example
cp Config.example.swift ios/Config.swift
# Edit ios/Config.swift with customer's write key
```

### 3. Modify the Code

Update the example to match the customer's issue:
- Change event names
- Adjust properties
- Add/remove plugins
- Replicate their SDK configuration

### 4. Reproduce the Issue

```bash
devbox run --pure start:app
```

Watch the console output for debugging information.

### 5. Test Across SDK Versions

Each example includes package managers (SPM for Swift, Gradle for Android) that let you test different SDK versions:
- Update the version in the package configuration
- Rebuild and retest
- Identify when the bug was introduced

### 6. Share the Reproduction

Commit your changes and share:
```bash
git add .
git commit -m "Reproduce: customer issue description"
git push origin reproduce-customer-issue
```

Now the customer, support, and engineering all have the exact same reproduction environment.

## What Makes These Examples Special

**Minimal:** Only the essential code to demonstrate SDK functionality. No clutter, no distractions.

**Interactive:** UI buttons to trigger SDK methods. Immediate feedback via console logging.

**Secure:** API keys stored in gitignored config files. Safe to commit reproductions without exposing credentials.

**Isolated:** Project-local build artifacts. Multiple reproductions can coexist without conflicts.

**Debuggable:** Custom plugins log all SDK activity to the console. See exactly what's being sent to Segment.

**Pure Mode:** The `--pure` flag ensures a clean environment with no inherited state from your system.

## Adding New Examples

When adding a new platform or SDK:

1. Create a new directory (e.g., `android/`, `react-native/`)
2. Include the mobile-devtools plugin (`devbox.json`)
3. Add interactive UI with basic SDK operations
4. Include a custom logging plugin for debugging
5. Use gitignored config files for API keys
6. Configure project-local build output
7. Document the quick start workflow

Follow the pattern established by the Swift example.

## Support and Issues

**For these reproduction examples:**
- Open an issue in this repository
- Tag with `reproduction-examples`

**For Segment SDK bugs:**
- Use the reproductions from this directory
- Open issues in the respective SDK repositories
- Include a link to your reproduction branch

**For Devbox issues:**
- Check the [Devbox documentation](https://www.jetify.com/devbox/docs/)
- Open issues in the [Devbox repository](https://github.com/jetify-com/devbox)

## Related Resources

- [iOS Plugin Reference](../../plugins/ios/REFERENCE.md)
- [Android Plugin Reference](../../plugins/android/REFERENCE.md)
- [React Native Plugin Reference](../../plugins/react-native/REFERENCE.md)
- [Devbox Documentation](https://www.jetify.com/devbox)
- [Segment Analytics Swift SDK](https://github.com/segmentio/analytics-swift)
