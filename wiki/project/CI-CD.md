# CI/CD Documentation

This document provides comprehensive information about the CI/CD workflows for the devbox mobile plugins repository.

## Overview

The repository uses GitHub Actions with three main workflows to ensure code quality and platform compatibility. The CI/CD strategy balances speed and thoroughness by running fast checks on every PR and comprehensive tests on-demand or on a schedule.

### Workflow Types

1. **PR Fast Checks** - Quick validation for every PR (30-45 minutes)
2. **Full E2E Tests** - Comprehensive platform testing (45-60 minutes per platform)
3. **MCP Publishing** - Automated semantic versioning and NPM publishing

### Design Philosophy

The CI/CD system prioritizes:
- **Fast feedback** - PRs get results in under 45 minutes
- **Platform coverage** - Tests minimum and maximum supported platform versions
- **Cost efficiency** - Android tests run on Linux, iOS only on macOS
- **Parallelization** - Matrix strategy runs tests concurrently
- **Reliability** - Caching and proper timeouts prevent flaky tests

## PR Checks Workflow (`pr-checks.yml`)

### Triggers

Runs automatically on:
- Pull requests targeting `main` branch
- Direct pushes to `main` branch

### Concurrency Control

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Automatically cancels outdated workflow runs when new commits are pushed to the same PR or branch, saving CI resources.

### Jobs

#### 1. Fast Tests (ubuntu-24.04, ~20 minutes)

Runs linting, unit tests, and integration tests without device emulation.

```bash
devbox run test:fast
```

**What it includes:**
- Shellcheck linting on all bash scripts
- GitHub workflow validation via `act --list`
- Android plugin unit tests (parallel execution via process-compose)
- iOS plugin unit tests (parallel execution via process-compose)
- Device management tests
- Cache functionality tests

**Environment:** ubuntu-24.04 (Linux)

**Artifacts uploaded:**
- `fast-test-reports` - Test results and logs from `test-results/` and `reports/`

#### 2. Android E2E (ubuntu-24.04 with KVM, ~30 minutes, matrix: min/max)

End-to-end tests with real Android emulators.

**Matrix strategy:**
```yaml
matrix:
  device: [min, max]
```

- **min** - API 21 (Android 5.0 Lollipop)
- **max** - API 36 (Android 15)

**Prerequisites:**
- KVM hardware acceleration enabled
- Gradle build cache configured

**Environment variables:**
```yaml
EMU_HEADLESS: 1          # Run emulator without GUI
BOOT_TIMEOUT: 180        # 3 minutes for emulator boot
TEST_TIMEOUT: 300        # 5 minutes for test execution
ANDROID_DEFAULT_DEVICE: ${{ matrix.device }}
TEST_TUI: false          # Disable interactive terminal UI
```

**Workflow:**
1. Enable KVM for hardware acceleration
2. Setup Gradle cache for faster builds
3. Install Devbox with package caching
4. Run E2E test: `devbox run --pure test:e2e`
5. Upload artifacts on success or failure

**Artifacts uploaded:**
- `android-{min|max}-reports` - Test reports from `reports/` and APK outputs

#### 3. iOS E2E (macos-14/15, ~25 minutes, matrix: min/max)

End-to-end tests with real iOS simulators.

**Matrix strategy:**
```yaml
matrix:
  include:
    - device: min
      os: macos-14
    - device: max
      os: macos-15
```

- **min** - iOS 15.4 on macos-14 (first Apple Silicon macOS supporting iOS 15.4)
- **max** - iOS 26.2 on macos-15 (latest macOS version)

**Prerequisites:**
- CocoaPods cache configured
- Xcode build cache configured

**Environment variables:**
```yaml
SIM_HEADLESS: 1          # Run simulator without GUI
BOOT_TIMEOUT: 120        # 2 minutes for simulator boot
TEST_TIMEOUT: 300        # 5 minutes for test execution
IOS_DEFAULT_DEVICE: ${{ matrix.device }}
TEST_TUI: false          # Disable interactive terminal UI
```

**Workflow:**
1. Setup CocoaPods and Xcode build caches
2. Install Devbox with package caching
3. Run E2E test: `devbox run --pure test:e2e`
4. Upload artifacts on success or failure

**Artifacts uploaded:**
- `ios-{min|max}-reports` - Test reports and CoreSimulator logs

#### 4. React Native E2E (ubuntu/macos, ~45 minutes, matrix: android/ios × min/max + web)

Cross-platform React Native tests covering Android, iOS, and web.

**Matrix strategy:**
```yaml
matrix:
  include:
    # Android tests
    - platform: android, device: min, os: ubuntu-24.04
    - platform: android, device: max, os: ubuntu-24.04
    # iOS tests
    - platform: ios, device: min, os: macos-14
    - platform: ios, device: max, os: macos-15
    # Web test
    - platform: web, device: none, os: ubuntu-24.04
```

**Prerequisites (platform-specific):**
- Node.js 20 with npm cache
- Android: KVM enabled, Gradle cache
- iOS: CocoaPods cache, Xcode build cache

**Environment variables:**
```yaml
EMU_HEADLESS: ${{ matrix.platform == 'android' && '1' || '0' }}
SIM_HEADLESS: ${{ matrix.platform == 'ios' && '1' || '0' }}
BOOT_TIMEOUT: 240        # 4 minutes for device boot
TEST_TIMEOUT: 600        # 10 minutes for test execution
ANDROID_DEFAULT_DEVICE: ${{ matrix.device }}
IOS_DEFAULT_DEVICE: ${{ matrix.device }}
TEST_TUI: false
```

**Workflow:**
1. Setup Node.js with npm cache
2. Enable KVM (Android only)
3. Setup platform-specific caches (Gradle/CocoaPods/Xcode)
4. Install Devbox with package caching
5. Run platform-specific test:
   - Android: `bash tests/run-android-tests.sh` (wrapper for optimization)
   - iOS: `bash tests/run-ios-tests.sh` (wrapper for optimization)
   - Web: `devbox run test:e2e:web`
6. Upload artifacts on success or failure

**Artifacts uploaded:**
- `react-native-{platform}-{device}-reports` - Test reports, build outputs, and logs

#### 5. Status Check (ubuntu-latest)

Aggregates results from all jobs and provides summary status.

**Dependencies:**
```yaml
needs: [fast-tests, android-e2e, ios-e2e, react-native-e2e]
if: always()
```

**Outputs:**
```
📊 PR Check Results:
  Fast Tests: success
  Android E2E: success
  iOS E2E: success
  React Native E2E: success
```

Fails if any dependent job fails, preventing merge of broken code.

### Timing Expectations

- **Fast Tests**: 15-20 minutes
- **Android E2E** (per device): 25-30 minutes
- **iOS E2E** (per device): 20-25 minutes
- **React Native E2E** (per platform): 35-45 minutes
- **Total** (all jobs parallel): 30-45 minutes

## Full E2E Workflow (`e2e-full.yml`)

### Triggers

Runs on:
- **Manual dispatch** via GitHub Actions UI
- **Weekly schedule** - Mondays at 00:00 UTC

```yaml
on:
  workflow_dispatch:
    inputs:
      run_android: true
      run_ios: true
      run_react_native: true
  schedule:
    - cron: '0 0 * * 1'
```

### Platform Selection

When triggering manually, you can selectively run tests by toggling inputs:
- `run_android` - Test Android examples (default: true)
- `run_ios` - Test iOS examples (default: true)
- `run_react_native` - Test React Native example (default: true)

### Job Configurations

#### Android E2E (ubuntu-24.04, ~45 minutes, matrix: min/max)

Similar to PR checks but with extended timeouts for more thorough testing.

**Key differences from PR checks:**
- `BOOT_TIMEOUT: 240` (4 minutes vs 3 minutes)
- `TEST_TIMEOUT: 600` (10 minutes vs 5 minutes)
- `timeout-minutes: 45` (job timeout vs 30 minutes)

#### iOS E2E (macos-14/15, ~45 minutes, matrix: min/max)

Similar to PR checks but with extended timeouts.

**Key differences from PR checks:**
- `BOOT_TIMEOUT: 180` (3 minutes vs 2 minutes)
- `TEST_TIMEOUT: 600` (10 minutes vs 5 minutes)
- `timeout-minutes: 45` (job timeout vs 25 minutes)

#### React Native E2E (ubuntu/macos, ~60 minutes, matrix: android/ios × min/max + web)

Similar to PR checks but with extended timeouts.

**Key differences from PR checks:**
- `BOOT_TIMEOUT: 300` (5 minutes vs 4 minutes)
- `TEST_TIMEOUT: 900` (15 minutes vs 10 minutes)
- `timeout-minutes: 60` (job timeout vs 45 minutes)

### Platform Coverage

**Android:**
- API 21 (Android 5.0 Lollipop) - Minimum supported version
- API 36 (Android 15) - Latest stable version

**iOS:**
- iOS 15.4 (on macos-14) - Minimum supported version
- iOS 26.2 (on macos-15) - Latest stable version

**React Native:**
- All Android and iOS versions above
- Web build (no device needed)

### Timing Expectations

- **Android E2E** (per device): 40-45 minutes
- **iOS E2E** (per device): 35-45 minutes
- **React Native E2E** (per platform): 50-60 minutes
- **Total** (all jobs parallel): 50-60 minutes

## MCP Publishing Workflow (`publish-mcp.yml`)

### Purpose

Automatically publishes the `devbox-mcp` NPM package using semantic-release for versioning.

### Triggers

Runs on:
- **Push to main** with changes to `plugins/devbox-mcp/**` or workflow file
- **Manual dispatch** with optional dry-run mode

```yaml
on:
  workflow_dispatch:
    inputs:
      dry_run: false
  push:
    branches: [main]
    paths:
      - 'plugins/devbox-mcp/**'
      - '.github/workflows/publish-mcp.yml'
```

### Jobs

#### 1. Test (ubuntu-24.04, ~10 minutes)

Validates the package before publishing.

```bash
devbox run test:plugin:devbox-mcp
```

**Environment:**
- Node.js 20 with npm cache
- Devbox with package caching

**Artifacts uploaded:**
- `test-reports` - Test results from `test-results/` and `reports/`

#### 2. Release (ubuntu-24.04, ~10 minutes)

Runs semantic-release to determine version and publish to NPM.

**Conditions:**
- Runs after successful tests
- Skipped if workflow is manual dispatch with `dry_run: true`
- Requires `npm-publish` environment with NPM_TOKEN secret

**Semantic Release Process:**
1. Analyzes commit messages since last release
2. Determines version bump (major/minor/patch) based on conventional commits
3. Generates CHANGELOG.md
4. Creates Git tag
5. Publishes to NPM registry
6. Creates GitHub release

**Outputs:**
- `new_release_published` - Boolean indicating if a new version was released
- `new_release_version` - Version number of the new release (e.g., "1.2.3")

**Artifacts uploaded:**
- `release-info` - Updated CHANGELOG.md (only if released)

#### 3. Dry Run (ubuntu-24.04, ~10 minutes)

Tests the release process without publishing.

**Conditions:**
- Runs after successful tests
- Only if workflow is manual dispatch with `dry_run: true`

**Process:**
```bash
npx semantic-release --dry-run
```

Shows what would happen without actually publishing or creating tags.

#### 4. Summary (ubuntu-latest)

Displays release results.

**Outputs:**
```
📦 Devbox MCP Server Publish Summary
=====================================

Tests: success
Release: success

✅ Successfully published devbox-mcp@1.2.3

NPM: https://www.npmjs.com/package/devbox-mcp/v/1.2.3
Release: https://github.com/org/repo/releases/tag/v1.2.3
```

### Semantic Versioning

The workflow uses conventional commits to determine version bumps:

- `feat:` - Minor version bump (1.0.0 → 1.1.0)
- `fix:` - Patch version bump (1.0.0 → 1.0.1)
- `BREAKING CHANGE:` - Major version bump (1.0.0 → 2.0.0)
- `docs:`, `chore:`, etc. - No version bump (no release)

## Optimization Strategies

### Device Filtering

Both workflows test only `min` and `max` devices to minimize CI time while maintaining platform coverage.

**Configuration in device lock files:**
```bash
# examples/android/devbox.d/android/devices/devices.lock
min:abc123...
max:def456...
```

Lock files are committed to the repository and limit which SDK versions are evaluated by Nix.

### Platform-Specific Skipping

Android and iOS initialization scripts check for platform-specific skip flags:

```bash
# Skip expensive operations in CI
if [ "${ANDROID_SKIP_SETUP:-0}" = "1" ]; then
  # Skip SDK component downloads
fi

if [ "${IOS_SKIP_SETUP:-0}" = "1" ]; then
  # Skip Xcode setup
fi
```

These flags are not currently used in workflows but are available for optimization.

### Caching Strategy

All workflows use comprehensive caching to speed up builds:

#### Devbox Cache
- **Action:** `jetify-com/devbox-install-action@v0.14.0`
- **Config:** `enable-cache: true`
- **Caches:** Nix store, devbox packages, shell environments
- **Speedup:** 5-10 minutes per run

#### Gradle Cache (Android)
```yaml
uses: actions/cache@v4
with:
  path: |
    ~/.gradle/caches
    ~/.gradle/wrapper
  key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
  restore-keys: ${{ runner.os }}-gradle-
```
- **Speedup:** 2-5 minutes per build

#### CocoaPods Cache (iOS)
```yaml
uses: actions/cache@v4
with:
  path: |
    ~/.cocoapods/repos
    ~/Library/Caches/CocoaPods
  key: ${{ runner.os }}-pods-${{ hashFiles('**/Podfile.lock') }}
  restore-keys: ${{ runner.os }}-pods-
```
- **Speedup:** 1-3 minutes per build

#### Xcode Build Cache (iOS)
```yaml
uses: actions/cache@v4
with:
  path: ~/Library/Developer/Xcode/DerivedData
  key: ${{ runner.os }}-xcode-${{ hashFiles('**/*.xcodeproj/**', '**/*.xcworkspace/**') }}
  restore-keys: ${{ runner.os }}-xcode-
```
- **Speedup:** 3-7 minutes per build

#### Node.js/npm Cache (React Native)
```yaml
uses: actions/setup-node@v4
with:
  node-version: '20'
  cache: 'npm'
  cache-dependency-path: examples/react-native/package-lock.json
```
- **Speedup:** 1-2 minutes per build

### Matrix Parallelization

Both workflows use matrix strategies to run tests in parallel:

```yaml
strategy:
  fail-fast: false
  matrix:
    device: [min, max]
```

**Benefits:**
- Tests complete in time of slowest job, not sum of all jobs
- `fail-fast: false` allows all tests to complete even if one fails
- Clear visibility into which specific configurations fail

### Lock Files for SDK Optimization

Device lock files contain checksums of device definitions:

```
min:1a2b3c4d5e6f7g8h9i0j
max:9i8h7g6f5e4d3c2b1a0j
```

**Benefits:**
- Nix only evaluates SDK versions for devices in the lock file
- Skips evaluation of unused intermediate API levels
- Reduces Nix flake evaluation time by 50-70%

**Maintenance:**
```bash
# Regenerate after adding/removing devices
devbox run --pure android.sh devices eval
devbox run --pure ios.sh devices eval
```

## Running CI Locally

### Using act

The `act` tool runs GitHub Actions workflows locally using Docker.

**Installation:**
```bash
# Add to your devbox environment
devbox add act

# Or install globally
brew install act  # macOS
```

**Prerequisites:**
- Docker installed and running
- Sufficient disk space (~20GB for Android, ~30GB for iOS)

### Running Specific Jobs

```bash
# Fast tests (no emulation)
act -j fast-tests

# Android E2E tests
act -j android-e2e

# iOS E2E tests (requires macOS)
act -j ios-e2e

# React Native E2E tests
act -j react-native-e2e

# Status check
act -j status-check
```

### Running Entire Workflows

```bash
# PR checks workflow
act -W .github/workflows/pr-checks.yml

# Full E2E workflow
act -W .github/workflows/e2e-full.yml

# MCP publishing workflow (dry run only locally)
act -W .github/workflows/publish-mcp.yml
```

### Testing Workflow Changes

```bash
# Validate workflow syntax without running
act --list

# List all jobs in workflow
act -W .github/workflows/pr-checks.yml --list

# Run with specific event trigger
act pull_request -W .github/workflows/pr-checks.yml

# Run with specific matrix values
act -j android-e2e -e matrix='{"device":"min"}'
```

### Limitations

**iOS tests cannot run locally:**
- macOS simulators require macOS host (not Linux)
- act runs on Linux Docker containers
- Use GitHub Actions runners for iOS testing

**Secrets and environment variables:**
```bash
# Pass secrets via file
act -s GITHUB_TOKEN=your_token

# Or via environment file
echo "GITHUB_TOKEN=your_token" > .secrets
act --secret-file .secrets
```

**Resource requirements:**
- Android tests need KVM support (Linux only)
- Each test may require 10-20GB disk space
- Ensure Docker has sufficient memory (8GB+)

## Debugging CI Failures

### Accessing Workflow Logs

1. Go to **Actions** tab in GitHub repository
2. Select the failed workflow run
3. Click on the failed job name
4. Expand the failed step to view logs

### Downloading Artifacts

All workflows upload artifacts on failure for debugging.

**To download:**
1. Navigate to the failed workflow run
2. Scroll to **Artifacts** section at the bottom
3. Click artifact name to download (e.g., `android-min-reports`)

**Artifact contents:**
- `test-results/` - Process-compose logs, per-process outputs
- `reports/` - Application logs, test reports
- `app/build/outputs/` (Android) - APK files, build logs
- `ios/build/` (iOS) - App bundles, build logs
- `~/Library/Logs/CoreSimulator/` (iOS) - Simulator logs

### Common Failure Patterns

#### Emulator Boot Timeout

**Symptom:**
```
ERROR: Emulator failed to boot within 180 seconds
```

**Possible causes:**
- KVM not enabled (Android on Linux)
- Insufficient system resources
- Emulator image download failure
- API level incompatibility

**Debug steps:**
1. Check `android-emulator.log` in artifacts
2. Verify KVM is enabled: `ls -l /dev/kvm`
3. Check system resources: `free -h`, `df -h`
4. Try manually: `EMU_HEADLESS=1 devbox run start:emu min`

**Fix:**
- Increase `BOOT_TIMEOUT` in workflow
- Verify device definition in `devices/min.json`
- Check Nix flake SDK composition

#### Build Failure

**Symptom:**
```
ERROR: Build failed with exit code 1
```

**Possible causes:**
- Missing dependencies
- Gradle/Xcode version incompatibility
- Source code compilation errors
- Cache corruption

**Debug steps:**
1. Check `build-app.log` in artifacts
2. Look for compilation errors in logs
3. Check dependency resolution issues
4. Try locally: `devbox run build` in the appropriate example project

**Fix:**
- Update dependencies in `build.gradle` or `Podfile`
- Clear cache: delete workflow caches in Settings → Actions → Caches
- Fix source code errors
- Update build tools version

#### App Deployment Failure

**Symptom:**
```
ERROR: Failed to install app on device
```

**Possible causes:**
- ADB connection issues (Android)
- Simulator not ready (iOS)
- APK/app bundle not found
- Incompatible target device

**Debug steps:**
1. Check `deploy-app.log` in artifacts
2. Verify emulator is running: check `android-emulator.log`
3. Check APK/app path: verify `ANDROID_APP_APK` or `IOS_APP_ARTIFACT`
4. Try manually: `adb install app.apk` or `xcrun simctl install booted app.app`

**Fix:**
- Increase `BOOT_TIMEOUT` to ensure device is ready
- Verify app artifact path in configuration
- Check device compatibility with app requirements

#### Test Execution Timeout

**Symptom:**
```
ERROR: Test execution exceeded 300 seconds
```

**Possible causes:**
- Test suite is slow
- App is unresponsive
- Device performance issues
- Infinite loop in test code

**Debug steps:**
1. Check test logs in artifacts
2. Identify which test is hanging
3. Try locally with debug logging: `DEBUG=1 devbox run test:e2e`
4. Profile test execution time

**Fix:**
- Increase `TEST_TIMEOUT` in workflow
- Optimize slow tests
- Fix hanging test code
- Add timeout assertions in tests

### Reproducing Locally

#### Android Issues

```bash
cd examples/android

# Reproduce exact CI environment
EMU_HEADLESS=1 \
BOOT_TIMEOUT=180 \
TEST_TIMEOUT=300 \
ANDROID_DEFAULT_DEVICE=min \
TEST_TUI=false \
devbox run --pure test:e2e

# Or with interactive UI for debugging
BOOT_TIMEOUT=180 \
TEST_TIMEOUT=300 \
ANDROID_DEFAULT_DEVICE=min \
devbox run test:e2e
```

#### iOS Issues

```bash
cd examples/ios

# Reproduce exact CI environment
SIM_HEADLESS=1 \
BOOT_TIMEOUT=120 \
TEST_TIMEOUT=300 \
IOS_DEFAULT_DEVICE=min \
TEST_TUI=false \
devbox run --pure test:e2e

# Or with interactive UI for debugging
BOOT_TIMEOUT=120 \
TEST_TIMEOUT=300 \
IOS_DEFAULT_DEVICE=min \
devbox run test:e2e
```

#### React Native Issues

```bash
cd examples/react-native

# Android
EMU_HEADLESS=1 \
BOOT_TIMEOUT=240 \
TEST_TIMEOUT=600 \
ANDROID_DEFAULT_DEVICE=min \
bash tests/run-android-tests.sh

# iOS
SIM_HEADLESS=1 \
BOOT_TIMEOUT=240 \
TEST_TIMEOUT=600 \
IOS_DEFAULT_DEVICE=min \
bash tests/run-ios-tests.sh

# Web
devbox run test:e2e:web
```

### Examining Logs

**Process-compose logs** (when using orchestrated tests):
```bash
# Download artifact and extract
tar -xzf android-min-reports.tar.gz

# View specific process logs
cat reports/logs/android-emulator.log  # Device boot
cat reports/logs/build-app.log         # Build output
cat reports/logs/deploy-app.log        # Deployment
cat reports/logs/verify-app.log        # App verification
```

**Traditional logs:**
```bash
# Android emulator logs
cat reports/logs/emulator.log

# Android build logs
cat examples/android/app/build/outputs/logs/build.log

# iOS simulator logs
cat ~/Library/Logs/CoreSimulator/*/system.log

# iOS build logs
cat reports/logs/xcodebuild.log
```

## Adding New Workflows

### Workflow File Structure

GitHub Actions workflows are YAML files in `.github/workflows/`:

```yaml
name: Workflow Name

on:
  # Triggers
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  job-name:
    name: Job Display Name
    runs-on: ubuntu-24.04
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - name: Install Devbox
        uses: jetify-com/devbox-install-action@v0.14.0
        with:
          enable-cache: true

      - name: Run tests
        run: devbox run test

      - name: Upload artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: reports/
```

### Job Dependencies

Use `needs` to create job dependencies:

```yaml
jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - run: echo "Building..."

  test:
    needs: build  # Waits for build to succeed
    runs-on: ubuntu-24.04
    steps:
      - run: echo "Testing..."

  deploy:
    needs: [build, test]  # Waits for both
    if: always()          # Runs even if test fails
    runs-on: ubuntu-24.04
    steps:
      - run: echo "Deploying..."
```

### Matrix Strategy

Use matrices to run tests in parallel across configurations:

```yaml
jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        platform: [android, ios]
        device: [min, max]
        include:
          - platform: android
            os: ubuntu-24.04
          - platform: ios
            os: macos-15
    runs-on: ${{ matrix.os }}
    steps:
      - run: echo "Testing ${{ matrix.platform }} on ${{ matrix.device }}"
```

### Secrets Management

Store sensitive values as repository secrets:

**Adding secrets:**
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add name and value

**Using secrets in workflows:**
```yaml
steps:
  - name: Deploy
    env:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
      API_KEY: ${{ secrets.API_KEY }}
    run: npm publish
```

**Protected environments:**
```yaml
jobs:
  publish:
    environment:
      name: production
      url: https://npmjs.com/package/devbox-mcp
    steps:
      - run: npm publish
```

### Best Practices

**Use concurrency control:**
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

**Set reasonable timeouts:**
```yaml
jobs:
  test:
    timeout-minutes: 30  # Prevent infinite hangs
```

**Upload artifacts on failure:**
```yaml
- name: Upload logs
  if: always()  # Run even if previous steps failed
  uses: actions/upload-artifact@v4
  with:
    name: logs
    path: reports/
```

**Use caching:**
```yaml
- name: Cache dependencies
  uses: actions/cache@v4
  with:
    path: ~/.gradle/caches
    key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*') }}
```

**Validate workflows locally:**
```bash
# Check syntax
act --list

# Run specific job
act -j test
```

**Follow naming conventions:**
- Workflow files: `{purpose}.yml` (e.g., `pr-checks.yml`)
- Job names: `{action}-{target}` (e.g., `test-android`)
- Step names: Descriptive actions (e.g., "Install dependencies")

**Document in README:**
Update `.github/workflows/README.md` when adding new workflows with:
- Purpose and triggers
- Job descriptions
- Timing expectations
- Environment requirements

## Cost Considerations

### Runner Pricing (GitHub-hosted)

- **Linux** (ubuntu-latest): $0.008/minute
- **macOS** (macos-latest): $0.08/minute
- **Windows** (windows-latest): $0.016/minute

### Current Workflow Costs (estimated per run)

**PR Checks:**
- Fast Tests (Linux, 20 min): $0.16
- Android E2E (Linux, 2×30 min): $0.48
- iOS E2E (macOS, 2×25 min): $8.00
- React Native E2E (Linux+macOS, 5×45 min): ~$12.00
- **Total per PR**: ~$20.64

**Full E2E:**
- Similar to PR checks but longer timeouts
- **Total per run**: ~$25-30

**MCP Publishing:**
- Test + Release (Linux, 2×10 min): $0.16
- **Total per release**: ~$0.16

### Optimization Impact

**Running Android on Linux vs macOS:**
- Linux: $0.008/minute
- macOS: $0.08/minute
- **Savings**: 10x cost reduction for Android tests

**Using matrix parallelization:**
- Without: 2 jobs × 30 min = 60 min total
- With: max(30 min, 30 min) = 30 min total
- **Savings**: 50% time reduction, same cost

**Using caching:**
- First run: Full build (40 min)
- Cached run: Partial build (25 min)
- **Savings**: 37% time reduction

### Free Tier Limits

GitHub provides free minutes for public repositories:
- **Public repos**: Unlimited free minutes
- **Private repos**: 2,000 free minutes/month (then $0.008/minute for Linux)

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Devbox Install Action](https://github.com/jetify-com/devbox-install-action)
- [act - Local GitHub Actions](https://github.com/nektos/act)
- [Semantic Release](https://semantic-release.gitbook.io/)
