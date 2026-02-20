# iOS E2E Tests

This directory contains the E2E test suite for the iOS example app.

## Running Tests

From the `examples/ios` directory:

```bash
# Run complete E2E test (build → simulator → deploy → verify)
devbox run test:e2e

# Run in pure mode (fresh simulator, clean state)
devbox run --pure test:e2e

# Run with TUI for interactive monitoring
TEST_TUI=true devbox run test:e2e
```

## Test Suites

### test-suite.yaml (Main E2E Test)
Standard E2E test for single simulator:
1. **Build** - xcodebuild for iOS simulator
2. **Sync Simulators** - Ensure simulator definitions match device configs
3. **Start Simulator** - Boot iOS simulator (or reuse existing)
4. **Deploy** - Install and launch app bundle
5. **Verify** - Check app is running
6. **Cleanup** - Clean up test simulators (in pure mode)
7. **Summary** - Display results

**Duration**: 3-5 minutes (faster with warm build cache)
**Use for**: Standard CI/CD testing, development validation

## Test Behavior

### Normal Mode (Developer)
- Reuses existing simulators
- Keeps app and simulator running after test
- Fast iteration for development

```bash
devbox run test:e2e
```

### Pure Mode (CI)
- Creates fresh test-specific simulator
- Stops and cleans up everything after test
- Reproducible, isolated environment

```bash
devbox run --pure test:e2e
```

The test suite automatically detects `DEVBOX_PURE_SHELL=1` (set by `--pure`) and adjusts cleanup behavior.

## Copy to Your Project

To add testing to your own iOS project:

1. **Include the plugin:**
   ```json
   {
     "include": ["plugin:ios"]
   }
   ```

2. **Configure for your app:**
   ```json
   {
     "env": {
       "IOS_APP_PROJECT": "YourApp.xcodeproj",
       "IOS_APP_SCHEME": "YourApp",
       "IOS_APP_BUNDLE_ID": "com.yourcompany.yourapp",
       "IOS_APP_ARTIFACT": ".devbox/virtenv/ios/DerivedData/Build/Products/Debug-iphonesimulator/YourApp.app"
     }
   }
   ```

3. **Create device definitions:**
   ```bash
   mkdir -p devbox.d/ios/devices

   # Create min device (oldest supported iOS)
   devbox run ios.sh devices create min --runtime 15.4

   # Create max device (latest iOS)
   devbox run ios.sh devices create max --runtime 26.2

   # Generate lock file
   devbox run ios.sh devices eval
   ```

4. **Run plugin E2E test:**
   ```bash
   devbox run test:e2e
   ```

5. **Optional: Copy example tests:**
   ```bash
   cp -r examples/ios/tests/ your-project/tests/
   # Edit and customize for your needs
   ```

## Test Configuration

Configure via environment variables in `devbox.json`:

```json
{
  "env": {
    "IOS_APP_PROJECT": "ios.xcodeproj",
    "IOS_APP_SCHEME": "ios",
    "IOS_APP_BUNDLE_ID": "com.example.ios",
    "IOS_APP_ARTIFACT": ".devbox/virtenv/ios/DerivedData/Build/Products/Debug-iphonesimulator/ios.app",
    "IOS_DEFAULT_DEVICE": "max",
    "IOS_DOWNLOAD_RUNTIME": "0"
  }
}
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `IOS_APP_PROJECT` | Path to .xcodeproj or .xcworkspace | Required |
| `IOS_APP_SCHEME` | Xcode build scheme | Required |
| `IOS_APP_BUNDLE_ID` | App bundle identifier | Required |
| `IOS_APP_ARTIFACT` | Path to built .app bundle | Auto-detected |
| `IOS_DEFAULT_DEVICE` | Default simulator device | `max` |
| `IOS_DOWNLOAD_RUNTIME` | Auto-download missing runtimes (0/1) | `0` |
| `TEST_TUI` | Show process-compose TUI (true/false) | `false` |
| `BOOT_TIMEOUT` | Simulator boot timeout (seconds) | `120` |
| `TEST_TIMEOUT` | Overall test timeout (seconds) | `300` |

## Debugging Failed Tests

### Check Test Logs

Test logs are written to `reports/ios-e2e-logs/`:

```bash
# View all logs
ls -la reports/ios-e2e-logs/

# View specific process log
cat reports/ios-e2e-logs/build-app.log
cat reports/ios-e2e-logs/ios-simulator.log
cat reports/ios-e2e-logs/deploy-app.log
```

### Check Simulator Status

```bash
# List all simulators
xcrun simctl list devices

# Check if specific simulator is running
xcrun simctl list devices | grep "Booted"

# View simulator logs
tail -f ~/Library/Logs/CoreSimulator/*/system.log
```

### Common Issues

**Build Failures:**
- Check Xcode is properly installed: `xcode-select -p`
- Verify project path: `ls -la $IOS_APP_PROJECT`
- Check scheme exists: `xcodebuild -list -project $IOS_APP_PROJECT`
- View build log: `cat reports/ios-e2e-logs/build-app.log`

**Simulator Won't Start:**
- Check CoreSimulatorService: `launchctl list | grep CoreSimulator`
- Restart service: `killall -9 CoreSimulatorService`
- Check disk space: `df -h`
- View simulator log: `cat reports/ios-e2e-logs/ios-simulator.log`

**App Won't Install:**
- Verify app bundle exists: `ls -la $IOS_APP_ARTIFACT`
- Check simulator is booted: `xcrun simctl list devices | grep Booted`
- Check bundle ID: `defaults read "$IOS_APP_ARTIFACT/Info.plist" CFBundleIdentifier`

**Timeout Errors:**
- Increase `BOOT_TIMEOUT` for slow machines
- Increase `TEST_TIMEOUT` for large builds
- Check system resources (CPU, memory)

### Debug Mode

Enable verbose logging:

```bash
IOS_DEBUG=1 devbox run test:e2e
```

Or with process-compose debug:

```bash
devbox run test:e2e:debug
```

## Test Architecture

The test suite uses process-compose to orchestrate multiple processes:

```
build-app (phase 1)
  ↓
sync-simulators (phase 2)
  ↓
ios-simulator (phase 3) ←─┐
  ↓                       │
deploy-app (phase 4) ─────┘ depends on simulator ready
  ↓
verify-app-running (phase 5)
  ↓
cleanup (phase 6) - conditional based on DEVBOX_PURE_SHELL
  ↓
summary (phase 7)
```

### Process Dependencies

- **build-app**: No dependencies (runs first)
- **sync-simulators**: No dependencies (runs in parallel with build)
- **ios-simulator**: Depends on sync-simulators completing
- **deploy-app**: Depends on build-app completing AND simulator being healthy
- **verify-app-running**: Depends on deploy-app completing
- **cleanup**: Depends on verify completing (or failing)
- **summary**: Depends on cleanup completing

### Readiness Probes

**ios-simulator process:**
- Checks simulator boot status via `xcrun simctl bootstatus`
- Initial delay: 10 seconds
- Check interval: 5 seconds
- Timeout: 120 seconds (configurable via `BOOT_TIMEOUT`)

**deploy-app process:**
- Checks app container exists via `xcrun simctl get_app_container`
- Initial delay: 5 seconds
- Check interval: 3 seconds
- Timeout: 60 seconds

## CI Integration

The test suite is designed for CI environments:

### GitHub Actions Example

```yaml
- name: Run iOS E2E Test
  working-directory: examples/ios
  env:
    SIM_HEADLESS: 1
    BOOT_TIMEOUT: 180
    TEST_TIMEOUT: 600
    IOS_DEFAULT_DEVICE: max
    TEST_TUI: false
  run: devbox run --pure test:e2e
```

### Key CI Settings

- `devbox run --pure` ensures isolated environment
- `TEST_TUI=false` disables interactive TUI
- Longer timeouts for slower CI machines
- Headless simulator mode (via `SIM_HEADLESS=1`)

## Learn More

- Plugin tests: `plugins/tests/ios/` (plugin unit tests)
- Plugin reference: `plugins/ios/REFERENCE.md` (complete API documentation)
- Plugin scripts: `plugins/ios/SCRIPTS.md` (script architecture and internals)
