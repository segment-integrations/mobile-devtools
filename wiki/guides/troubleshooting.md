# Troubleshooting Guide

Comprehensive troubleshooting guide for common issues across Android, iOS, and React Native development with Devbox plugins.

## Quick Reference

Use Ctrl/Cmd+F to search for specific error messages or symptoms.

**Common error patterns:**
- `ANDROID_SDK_ROOT not set` → [SDK Not Found](#android-sdk-not-found)
- `Xcode developer directory not found` → [Xcode Not Found](#xcode-not-found)
- `Runtime iOS X.X not found` → [Simulator Runtime Missing](#ios-simulator-runtime-missing)
- `Emulator won't start` → [Emulator Won't Start](#android-emulator-wont-start)
- `CoreSimulatorService connection became invalid` → [CoreSimulatorService Issues](#ios-coresimulatorservice-issues)
- `Metro port already in use` → [Metro Port Conflicts](#metro-port-conflicts)
- `Lock file checksum mismatch` → [Lock File Out of Sync](#lock-file-out-of-sync)
- `APK installation failed` → [App Installation Fails](#android-app-installation-fails)

## Installation and Setup Issues

### Devbox Shell Initialization Slow

**Symptom**: `devbox shell` takes several minutes to start.

**Root cause**: Android SDK flake evaluation or iOS setup evaluating all devices.

**Solutions**:

1. Limit devices to evaluate (most effective):
   ```json
   {
     "env": {
       "ANDROID_DEVICES": "min,max",
       "IOS_DEVICES": "min,max"
     }
   }
   ```

2. Skip unused platforms in React Native:
   ```json
   {
     "env": {
       "ANDROID_SKIP_SETUP": "1",
       "IOS_SKIP_SETUP": "1"
     }
   }
   ```

3. Regenerate lock files:
   ```bash
   devbox run android.sh devices eval
   devbox run ios.sh devices eval
   ```

**Prevention**: Always commit lock files to version control for fast CI builds.


### Plugin Not Found or Not Loading

**Symptom**: Plugin commands not available or initialization hooks not running.

**Root cause**: Incorrect plugin path in `devbox.json` or missing `include` directive.

**Solutions**:

1. Verify plugin inclusion in `devbox.json`:
   ```json
   {
     "include": [
       "github:segment-integrations/devbox-plugins?dir=plugins/android",
       "github:segment-integrations/devbox-plugins?dir=plugins/ios"
     ]
   }
   ```

2. Check plugin is loaded:
   ```bash
   devbox shell
   echo $ANDROID_SCRIPTS_DIR
   echo $IOS_SCRIPTS_DIR
   ```

3. Regenerate virtenv:
   ```bash
   devbox run devbox_sync
   ```

### Environment Variables Not Set

**Symptom**: Commands fail with "variable not set" errors.

**Root cause**: Environment not sourced or virtenv stale.

**Solutions**:

1. Source the environment manually:
   ```bash
   . ${ANDROID_RUNTIME_DIR}/scripts/init/setup.sh
   . ${IOS_RUNTIME_DIR}/scripts/init/setup.sh
   ```

2. Regenerate virtenv:
   ```bash
   devbox run devbox_sync
   ```

3. Verify environment:
   ```bash
   devbox run android.sh info
   devbox run ios.sh info
   ```

## SDK and Tooling Issues

### Android SDK Not Found

**Symptom**: Error message "ANDROID_SDK_ROOT not set" or SDK tools not found.

**Root cause**: Android environment not initialized or using `devbox shell` instead of `devbox run`.

**Solutions**:

1. Use `devbox run` instead of `devbox shell`:
   ```bash
   # Correct
   devbox run android.sh devices list

   # Incorrect
   devbox shell
   android.sh devices list  # May not work
   ```

2. Source the Android environment in shell:
   ```bash
   devbox shell
   . ${ANDROID_RUNTIME_DIR}/scripts/init/setup.sh
   ```

3. Verify SDK installation:
   ```bash
   devbox run android.sh info
   ```

4. Check `ANDROID_SDK_ROOT`:
   ```bash
   echo $ANDROID_SDK_ROOT
   ls -la $ANDROID_SDK_ROOT
   ```

5. Regenerate the environment:
   ```bash
   devbox run devbox_sync
   ```

**Prevention**: Always use `devbox run` for commands, or source environment in interactive shells.

### Xcode Not Found

**Symptom**: "Xcode developer directory not found" or Xcode tools unavailable.

**Root cause**: Xcode not installed or `xcode-select` path incorrect.

**Solutions**:

1. Check if Xcode is installed:
   ```bash
   xcode-select -p
   ```

2. Install Xcode from the App Store, then set the active developer directory:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

3. Or install command-line tools only:
   ```bash
   xcode-select --install
   ```

4. Set explicit path in `devbox.json`:
   ```json
   {
     "env": {
       "IOS_DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer"
     }
   }
   ```

5. Clear Xcode cache and rediscover:
   ```bash
   rm -f .devbox/virtenv/ios/.xcode_dev_dir.cache
   devbox run ios.sh info
   ```

**Prevention**: Install Xcode before using iOS plugin.


### Build Tools Version Mismatch

**Symptom**: Gradle build fails with "SDK Build Tools version X not found".

**Root cause**: `build.gradle` specifies build tools version not in Nix SDK.

**Solutions**:

1. Check available build tools:
   ```bash
   devbox run android.sh info
   ```

2. Update build tools version in `devbox.json`:
   ```json
   {
     "env": {
       "ANDROID_BUILD_TOOLS_VERSION": "36.1.0"
     }
   }
   ```

3. Sync Gradle configuration with SDK version in `app/build.gradle`:
   ```gradle
   android {
       compileSdk 36
       buildToolsVersion "36.1.0"
   }
   ```

4. Regenerate environment:
   ```bash
   devbox run devbox_sync
   ```

**Prevention**: Keep `devbox.json` and `build.gradle` versions synchronized.

### iOS Simulator Runtime Missing

**Symptom**: "Runtime iOS X.X not found" or simulator won't start due to missing runtime.

**Root cause**: iOS runtime not installed via Xcode.

**Solutions**:

1. List available runtimes:
   ```bash
   xcrun simctl list runtimes
   ```

2. Download runtime via Xcode Settings:
   - Open Xcode
   - Go to Settings > Platforms
   - Click "+" to download iOS Simulator runtimes

3. Enable auto-download in `devbox.json`:
   ```json
   {
     "env": {
       "IOS_DOWNLOAD_RUNTIME": "1"
     }
   }
   ```

4. Or download via command line:
   ```bash
   xcodebuild -downloadPlatform iOS
   ```

5. Skip devices with missing runtimes:
   ```bash
   devbox run ios.sh devices sync
   ```

**Prevention**: Install iOS runtimes before creating device definitions.

## Emulator and Simulator Issues

### Android Emulator Won't Start

**Symptom**: Emulator fails to start or times out during boot.

**Root cause**: Hardware acceleration unavailable, snapshot corruption, or resource constraints.

**Solutions**:

1. Check if hardware acceleration is available:
   ```bash
   devbox run emulator -accel-check
   ```

2. Try starting with snapshot disabled:
   ```bash
   ANDROID_DISABLE_SNAPSHOTS=1 devbox run start:emu
   ```

3. Reset emulator state:
   ```bash
   devbox run android.sh emulator reset max
   ```

4. Increase boot timeout:
   ```bash
   BOOT_TIMEOUT=180 devbox run start:emu
   ```

5. Check system resources:
   ```bash
   top  # or htop
   ```

6. View emulator logs:
   ```bash
   tail -f reports/logs/*.log
   ```

7. Try headless mode:
   ```bash
   EMU_HEADLESS=1 devbox run start:emu
   ```

**Prevention**: Ensure virtualization is enabled in BIOS and sufficient RAM available (4GB+ recommended).


### iOS CoreSimulatorService Issues

**Symptom**: "CoreSimulatorService connection became invalid" or simulators won't start.

**Root cause**: CoreSimulatorService crashed or corrupted state.

**Solutions**:

1. Restart CoreSimulatorService:
   ```bash
   killall -9 CoreSimulatorService
   ```

2. Check service status:
   ```bash
   launchctl list | grep CoreSimulator
   ```

3. Kickstart the service:
   ```bash
   launchctl kickstart -k gui/$UID/com.apple.CoreSimulatorService
   ```

4. Open Simulator app to initialize:
   ```bash
   open -a Simulator
   ```

5. Check simulator device state:
   ```bash
   xcrun simctl list devices
   ```

6. Delete and recreate simulator:
   ```bash
   xcrun simctl delete "Device Name"
   devbox run ios.sh devices sync
   ```

**Prevention**: Restart CoreSimulatorService periodically if simulators are unstable.

### Simulator Won't Boot

**Symptom**: iOS simulator times out during boot or fails to start.

**Root cause**: Resource constraints, disk space, or runtime issues.

**Solutions**:

1. Increase boot timeout:
   ```bash
   BOOT_TIMEOUT=180 devbox run start:sim
   ```

2. Check system resources:
   ```bash
   top  # or htop
   ```

3. View simulator logs:
   ```bash
   tail -f ~/Library/Logs/CoreSimulator/*/system.log
   ```

4. Check disk space:
   ```bash
   df -h
   ```

5. Restart your Mac if simulators are consistently failing.

6. Delete simulator and recreate:
   ```bash
   xcrun simctl delete "Device Name"
   devbox run ios.sh devices sync
   ```

**Prevention**: Ensure sufficient disk space (10GB+ free) and RAM (8GB+ recommended).

### Multiple Emulators Conflict

**Symptom**: Multiple Android emulators running on the same port or conflicting.

**Root cause**: Port collision or improper cleanup.

**Solutions**:

1. Stop all emulators:
   ```bash
   devbox run stop:emu
   ```

2. Specify different ports for each emulator:
   ```bash
   EMU_PORT=5554 devbox run start:emu device1
   EMU_PORT=5556 devbox run start:emu device2
   ```

3. Use device serials explicitly:
   ```bash
   ANDROID_SERIAL=emulator-5554 devbox run start:app
   ```

4. List running emulators:
   ```bash
   adb devices
   ```

**Prevention**: Use `devbox run --pure` for isolated testing or specify unique ports.

## Build Failures

### Android Build Fails with Gradle Errors

**Symptom**: Gradle build fails with dependency or configuration errors.

**Root cause**: Gradle cache corruption, version mismatch, or missing dependencies.

**Solutions**:

1. Clean Gradle build:
   ```bash
   cd android && gradle clean
   devbox run build
   ```

2. Clear Gradle cache:
   ```bash
   rm -rf ~/.gradle/caches/
   rm -rf android/.gradle/
   ```

3. Verify environment:
   ```bash
   devbox run android.sh info
   ```

4. Check Gradle wrapper version:
   ```bash
   cd android && ./gradlew --version
   ```

5. Update Gradle dependencies:
   ```bash
   cd android && ./gradlew --refresh-dependencies
   ```

**Prevention**: Keep Gradle and plugin versions up to date.


### iOS Build Fails with Xcode Errors

**Symptom**: Xcode build fails with signing, provisioning, or linker errors.

**Root cause**: Code signing issues, Nix environment conflicts, or stale derived data.

**Solutions**:

1. Clean derived data:
   ```bash
   rm -rf .devbox/virtenv/ios/DerivedData
   ```

2. Reinstall CocoaPods:
   ```bash
   cd ios && pod install --repo-update
   ```

3. Rebuild:
   ```bash
   devbox run build
   ```

4. Check code signing:
   ```bash
   defaults read "$IOS_APP_ARTIFACT/Info.plist" CFBundleIdentifier
   ```

5. Strip Nix flags (plugin does this automatically):
   ```bash
   env -u LD -u LDFLAGS -u NIX_LDFLAGS xcodebuild ...
   ```

**Prevention**: Use automatic code signing and keep CocoaPods updated.

### Build Fails with Nix Environment Conflicts

**Symptom**: Build errors related to linker flags or Nix environment variables.

**Root cause**: Nix environment variables interfering with native toolchains.

**Solutions**:

1. The iOS plugin automatically strips Nix flags. Verify in build logs:
   ```bash
   cat reports/logs/build-app.log | grep "LD"
   ```

2. For Android, ensure Gradle uses project JDK:
   ```properties
   # In android/gradle.properties
   org.gradle.java.home=/path/to/jdk
   ```

3. Use `devbox run --pure` for isolated builds:
   ```bash
   devbox run --pure build-android
   devbox run --pure build-ios
   ```

**Prevention**: Plugins handle Nix environment cleanup automatically.

## Deployment and App Installation Issues

### Android App Installation Fails

**Symptom**: Error installing APK on emulator.

**Root cause**: APK path incorrect, app already installed, or emulator not ready.

**Solutions**:

1. Verify APK path is correct:
   ```bash
   echo $ANDROID_APP_APK
   ls -l $ANDROID_APP_APK
   ```

2. Check if app is already installed:
   ```bash
   adb shell pm list packages | grep your.package.name
   ```

3. Uninstall existing version:
   ```bash
   adb uninstall com.example.myapp
   ```

4. Check emulator is fully booted:
   ```bash
   adb shell getprop sys.boot_completed
   # Should return "1"
   ```

5. Wait for emulator boot:
   ```bash
   adb wait-for-device
   ```

6. Try manual installation:
   ```bash
   adb install -r $ANDROID_APP_APK
   ```

**Prevention**: Always wait for emulator to fully boot before installing apps.

### iOS App Installation Fails

**Symptom**: Error installing app on simulator or app doesn't launch.

**Root cause**: Bundle path incorrect, simulator not booted, or bundle ID mismatch.

**Solutions**:

1. Verify app bundle exists:
   ```bash
   ls -la $IOS_APP_ARTIFACT
   ```

2. Check simulator is booted:
   ```bash
   xcrun simctl list devices | grep Booted
   ```

3. Verify bundle ID:
   ```bash
   defaults read "$IOS_APP_ARTIFACT/Info.plist" CFBundleIdentifier
   ```

4. Check app bundle structure:
   ```bash
   ls -la "$IOS_APP_ARTIFACT/"
   # Should contain: Info.plist, executable, etc.
   ```

5. Try manual installation:
   ```bash
   xcrun simctl install booted "$IOS_APP_ARTIFACT"
   ```

6. Launch manually:
   ```bash
   xcrun simctl launch booted "$IOS_APP_BUNDLE_ID"
   ```

**Prevention**: Verify bundle ID matches between Xcode project and `devbox.json`.

### App Crashes Immediately After Launch

**Symptom**: App installs but crashes on launch.

**Root cause**: Runtime errors, missing dependencies, or architecture mismatch.

**Solutions**:

1. View app logs (Android):
   ```bash
   adb logcat | grep "$(basename $ANDROID_APP_ID)"
   ```

2. View app logs (iOS):
   ```bash
   xcrun simctl spawn booted log stream --predicate 'process == "YourApp"'
   ```

3. Check architecture compatibility (Android):
   ```bash
   unzip -l $ANDROID_APP_APK | grep lib/
   ```

4. Debug in development mode:
   ```bash
   BUILD_CONFIG=Debug devbox run start:app
   BUILD_CONFIG=Debug devbox run start:ios
   ```

5. Check for missing native libraries or frameworks.

**Prevention**: Test builds in Debug configuration before Release builds.


## Metro Bundler Issues (React Native)

### Metro Port Conflicts

**Symptom**: "Metro port already in use" or "EADDRINUSE: address already in use".

**Root cause**: Metro already running on the port or port not released.

**Solutions**:

1. Check what's using the port:
   ```bash
   lsof -ti:8081
   lsof -ti:8091
   ```

2. Stop Metro for specific suite:
   ```bash
   metro.sh stop android
   metro.sh stop ios
   ```

3. Kill process on port:
   ```bash
   lsof -ti:8081 | xargs kill -9
   ```

4. Clean all Metro state:
   ```bash
   metro.sh clean android
   metro.sh clean ios
   rm -rf .devbox/virtenv/react-native/metro/
   ```

5. Use dynamic port allocation (default behavior):
   ```bash
   # Metro automatically allocates ports 8091-8199
   devbox run start:android
   ```

**Prevention**: Always use `metro.sh stop` to clean up Metro processes.

### App Not Updating with Hot Reload

**Symptom**: Code changes don't appear in app or hot reload fails.

**Root cause**: Metro cache stale or connection lost.

**Solutions**:

1. Check Metro is running:
   ```bash
   metro.sh status android
   ```

2. Check Metro logs for errors:
   ```bash
   tail -f reports/react-native-android-dev-logs/metro-bundler.log
   ```

3. Force reload in app:
   - Android: Press `R` twice or `Ctrl/Cmd + M` to open Dev Menu
   - iOS: Press `R` in simulator

4. Restart Metro with cache reset:
   ```bash
   metro.sh stop android
   metro.sh start android --reset-cache
   ```

5. Check Metro port configuration:
   ```bash
   cat .devbox/virtenv/react-native/metro/port-android.txt
   cat .devbox/virtenv/react-native/metro/env-android.sh
   ```

**Prevention**: Keep Metro running during development and avoid port conflicts.

### Metro Connection Timeout

**Symptom**: App shows "Could not connect to development server" or times out connecting to Metro.

**Root cause**: Metro not started, wrong port, or network configuration.

**Solutions**:

1. Verify Metro is running:
   ```bash
   metro.sh health android android
   # Exit code 0 = healthy, non-zero = unhealthy
   ```

2. Check Metro port:
   ```bash
   cat .devbox/virtenv/react-native/metro/port-android.txt
   ```

3. Test Metro connectivity:
   ```bash
   curl http://localhost:$(cat .devbox/virtenv/react-native/metro/port-android.txt)/status
   ```

4. Restart Metro:
   ```bash
   metro.sh stop android
   metro.sh start android
   ```

5. Check app is using correct Metro port (view app logs).

**Prevention**: Wait for Metro to fully start before launching app.

## Lock File and Device Sync Issues

### Lock File Out of Sync

**Symptom**: "Warning: devices.lock may be stale" or checksum mismatch.

**Root cause**: Device definitions changed but lock file not regenerated.

**Solutions**:

1. Regenerate lock file (Android):
   ```bash
   devbox run android.sh devices eval
   ```

2. Regenerate lock file (iOS):
   ```bash
   devbox run ios.sh devices eval
   ```

3. Commit updated lock file:
   ```bash
   git add devbox.d/*/devices/devices.lock
   git commit -m "chore: update device lock files"
   ```

**Prevention**: Always regenerate lock files after creating, updating, or deleting devices.

### Device Definitions Not Applied

**Symptom**: AVD/simulator doesn't match device definition or uses old configuration.

**Root cause**: Devices not synced after definition changes.

**Solutions**:

1. Sync AVDs with definitions (Android):
   ```bash
   devbox run android.sh devices sync
   ```

2. Sync simulators with definitions (iOS):
   ```bash
   devbox run ios.sh devices sync
   ```

3. View sync results to see what changed:
   - Matched: Already correct
   - Recreated: Deleted and recreated
   - Created: Newly created
   - Skipped: Missing runtime or dependency

4. Regenerate lock file after sync:
   ```bash
   devbox run android.sh devices eval
   devbox run ios.sh devices eval
   ```

**Prevention**: Run sync after pulling device definition changes from version control.

### Device Creation Fails

**Symptom**: Cannot create device or device creation reports errors.

**Root cause**: Invalid parameters, missing runtime, or system resource limits.

**Solutions**:

1. Verify parameters are correct (Android):
   ```bash
   # Check valid device profiles
   avdmanager list device

   # Check valid API levels
   sdkmanager --list | grep "system-images"
   ```

2. Verify runtime available (iOS):
   ```bash
   xcrun simctl list runtimes
   ```

3. Check device name doesn't conflict:
   ```bash
   # Android
   devbox run android.sh devices list

   # iOS
   devbox run ios.sh devices list
   ```

4. Ensure sufficient disk space:
   ```bash
   df -h
   ```

5. View detailed error logs:
   ```bash
   ANDROID_DEBUG=1 devbox run android.sh devices create ...
   IOS_DEBUG=1 devbox run ios.sh devices create ...
   ```

**Prevention**: Verify runtimes are installed before creating device definitions.


## Performance Issues

### Slow Shell Initialization

**Symptom**: `devbox shell` takes multiple minutes to initialize.

**Root cause**: Evaluating too many devices or slow Nix flake evaluation.

**Solutions**:

1. Limit devices to evaluate:
   ```json
   {
     "env": {
       "ANDROID_DEVICES": "min,max",
       "IOS_DEVICES": "min,max"
     }
   }
   ```

2. Skip unused platforms:
   ```json
   {
     "env": {
       "ANDROID_SKIP_SETUP": "1",
       "IOS_SKIP_SETUP": "1"
     }
   }
   ```

3. Commit lock files for faster CI:
   ```bash
   git add devbox.d/*/devices/*.lock*
   git commit -m "chore: add device lock files"
   ```

4. Clear Nix cache if corrupted:
   ```bash
   nix-collect-garbage -d
   ```

**Prevention**: Always use lock files and limit device evaluation.

### Slow Build Times

**Symptom**: Builds take longer than expected.

**Root cause**: No build cache, large project, or resource constraints.

**Solutions**:

1. Enable Gradle build cache (Android):
   ```properties
   # In android/gradle.properties
   org.gradle.caching=true
   org.gradle.parallel=true
   ```

2. Use incremental builds:
   ```bash
   # Don't clean between builds
   devbox run build
   # Subsequent builds are faster
   ```

3. Increase Gradle memory (Android):
   ```properties
   # In android/gradle.properties
   org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m
   ```

4. Check system resources:
   ```bash
   top  # Ensure CPU/memory available
   ```

5. Use Debug builds in development:
   ```bash
   BUILD_CONFIG=Debug devbox run build
   ```

**Prevention**: Keep build caches and use incremental builds.

### Emulator Performance Issues

**Symptom**: Emulator runs slowly or lags.

**Root cause**: No hardware acceleration, insufficient resources, or snapshot issues.

**Solutions**:

1. Verify hardware acceleration:
   ```bash
   devbox run emulator -accel-check
   ```

2. Use headless mode to save resources:
   ```bash
   EMU_HEADLESS=1 devbox run start:emu
   ```

3. Disable snapshots for better performance:
   ```bash
   ANDROID_DISABLE_SNAPSHOTS=1 devbox run start:emu
   ```

4. Allocate more RAM to emulator (edit device JSON):
   ```json
   {
     "name": "my_device",
     "ram": "4096"
   }
   ```

5. Close other resource-intensive applications.

**Prevention**: Ensure virtualization enabled in BIOS and sufficient RAM allocated.

## Debugging Techniques

### Enable Debug Logging

Enable verbose logging to diagnose issues:

```bash
# Platform-specific debug
ANDROID_DEBUG=1 devbox shell
IOS_DEBUG=1 devbox shell

# Global debug
DEBUG=1 devbox shell

# Debug during tests
ANDROID_DEBUG=1 devbox run test:e2e
IOS_DEBUG=1 devbox run test:e2e

# Combined
DEBUG=1 ANDROID_DEBUG=1 IOS_DEBUG=1 devbox shell
```

Debug logs show:
- Environment variable resolution
- SDK/Xcode path discovery
- Device configuration loading
- Emulator/simulator startup commands
- App deployment steps
- Metro bundler operations

### View Test Logs

Test logs are written to `reports/` directory:

```bash
# List all logs
ls -la reports/logs/
ls -la reports/android-e2e-logs/
ls -la reports/ios-e2e-logs/
ls -la reports/react-native-*-logs/

# View specific process log
cat reports/logs/build-app.log
cat reports/logs/emulator.log
cat reports/logs/simulator.log
cat reports/logs/deploy-app.log
cat reports/logs/metro-bundler.log
```

### Check Process Status

Monitor running processes:

```bash
# Android emulator
adb devices
ps aux | grep emulator

# iOS simulator
xcrun simctl list devices | grep Booted
ps aux | grep Simulator

# Metro bundler
lsof -ti:8081
metro.sh status android
metro.sh status ios

# General process monitoring
top
htop  # if installed
```

### Verify Configuration

Check current configuration:

```bash
# Android
devbox run android.sh config show
devbox run android.sh info

# iOS
devbox run ios.sh config show
devbox run ios.sh info

# Environment variables
env | grep ANDROID
env | grep IOS
env | grep METRO
```

### Interactive Diagnostics

Run diagnostics to check setup:

```bash
# iOS diagnostics
devbox run doctor

# Manual checks
which adb
which emulator
which xcodebuild
which xcrun
```

### Test in Isolation

Use `--pure` flag for isolated, reproducible testing:

```bash
# Pure mode ensures clean state
devbox run --pure test:e2e:android
devbox run --pure test:e2e:ios

# Pure mode for manual testing
devbox run --pure start-emu
devbox run --pure start-sim
```

Pure mode:
- Fresh environment without previous state
- Isolated from system configuration
- Reproducible results
- Automatic cleanup after completion

### Common Debug Workflow

Standard debugging approach:

1. Enable debug logging:
   ```bash
   DEBUG=1 ANDROID_DEBUG=1 devbox run start:app
   ```

2. Check environment:
   ```bash
   devbox run android.sh info
   ```

3. View logs:
   ```bash
   tail -f reports/logs/*.log
   ```

4. Test in isolation:
   ```bash
   devbox run --pure start-android
   ```

5. Verify configuration:
   ```bash
   devbox run android.sh config show
   ```

## Getting Help

If issues persist after troubleshooting:

1. **Check documentation**:
   - [Android Reference](../reference/android.md)
   - [iOS Reference](../reference/ios.md)
   - [React Native Reference](../reference/react-native.md)

2. **Review example projects**:
   - `examples/android/` - Working Android setup
   - `examples/ios/` - Working iOS setup
   - `examples/react-native/` - Working React Native setup

3. **Enable debug logging and collect information**:
   ```bash
   DEBUG=1 devbox run your-command 2>&1 | tee debug.log
   ```

4. **Report issues with**:
   - Error messages and stack traces
   - Debug logs
   - `devbox.json` configuration
   - Platform and version information
   - Steps to reproduce

5. **Community support**:
   - GitHub Issues: Report bugs or request features
   - Discord: Join the Jetify community
   - Devbox Documentation: [jetify.com/devbox/docs](https://www.jetify.com/devbox/docs/)

## Related Guides

- [Android Development Guide](android-guide.md)
- [iOS Development Guide](ios-guide.md)
- [React Native Development Guide](react-native-guide.md)
- [Device Management Guide](device-management.md)
- [Testing Guide](testing.md)
- [Quick Start](quick-start.md)
