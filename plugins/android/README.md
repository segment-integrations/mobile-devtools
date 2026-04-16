# Android Devbox Plugin

This plugin pins Android user data (AVDs, emulator configs, adb keys) to the project virtenv so
shells are pure and do not touch global `~/.android` state.

Runtime scripts live in the virtenv (`.devbox/virtenv/android/scripts`) and are added to PATH when
the plugin activates.

Configuration is managed via environment variables in `plugin.json`. The plugin automatically generates
a JSON file in the virtenv for Nix flake evaluation. Set env vars to configure SDK versions, default
device selection, or enable `ANDROID_LOCAL_SDK`.

The Android SDK flake lives under `devbox.d/android/` and exposes `android-sdk*` outputs.

## Quickstart

```sh
# List devices
devbox run android.sh devices list

# Build + install + launch app on emulator
devbox run start-android

# Stop all emulators
devbox run stop-emu

# Reset emulator state (useful after Nix package updates)
devbox run reset-emu
```

`start-android` starts the emulator, builds the app (via `build-android`), and installs/launches the APK matched by `ANDROID_APP_APK`.

## Configuring SDK Versions

The plugin provides sensible defaults (API 35, build-tools 35.0.0), but you can configure SDK versions to match your project needs.

### Option 1: Use Plugin Defaults (Recommended)

Update your `android/build.gradle` to read from environment variables:

```gradle
buildscript {
    ext {
        def compileSdkEnv = System.getenv("ANDROID_COMPILE_SDK") ?: System.getenv("ANDROID_MAX_API") ?: "35"
        def targetSdkEnv = System.getenv("ANDROID_TARGET_SDK") ?: System.getenv("ANDROID_MAX_API") ?: "35"
        buildToolsVersion = System.getenv("ANDROID_BUILD_TOOLS_VERSION") ?: "35.0.0"
        
        compileSdkVersion = compileSdkEnv.toInteger()
        targetSdkVersion = targetSdkEnv.toInteger()
        
        def ndkVersionEnv = System.getenv("ANDROID_NDK_VERSION")
        if (ndkVersionEnv) {
            ndkVersion = ndkVersionEnv
        }
    }
}
```

This approach ensures your build always uses the SDK versions provided by the plugin.

### Option 2: Override Plugin Defaults

Set in your `devbox.json`:

```json
{
  "include": ["github:segment-integrations/mobile-devtools?dir=plugins/android"],
  "env": {
    "ANDROID_MAX_API": "33",
    "ANDROID_BUILD_TOOLS_VERSION": "33.0.0"
  }
}
```

Then regenerate the device lock file:
```bash
devbox run android.sh devices eval
```

### Troubleshooting SDK Version Mismatches

If your `android/build.gradle` has hardcoded SDK versions that don't match the plugin, you'll see build failures like:

```
Failed to install the following SDK components:
  platforms;android-33 Android SDK Platform 33
The SDK directory is not writable (/nix/store/...)
```

**Diagnosis:**

Run the doctor command to check for mismatches:
```bash
devbox run android.sh doctor
```

The doctor will:
- Show which SDK versions the plugin provides
- Detect hardcoded versions in your build.gradle
- Provide specific fix instructions

**Why this happens:**

The Android SDK is provided via the Nix store (immutable), so Gradle cannot download additional SDK versions. Your build.gradle must use the SDK versions that the plugin provides.

## Reference

See `devbox/plugins/android/REFERENCE.md` for the full command and config reference.

## Device definitions

Device definitions live in `devbox.d/android/devices/*.json`. Each file can include:
- `name` (string)
- `api` (number, required)
- `device` (AVD device id, required)
- `tag` (e.g. `google_apis`, `google_apis_playstore`, `play_store`, `aosp_atd`, `google_atd`)
- `preferred_abi` (e.g. `arm64-v8a`, `x86_64`, `x86`)

Default devices are `min.json` and `max.json`.

## Selecting devices for evaluation

The flake evaluates all device APIs by default. To restrict it, set `ANDROID_DEVICES` in your `devbox.json`:
```json
{"env": {"ANDROID_DEVICES": "max"}}
```
Use `devbox run android.sh devices select max` to update this value.

**Note:** The Android flake lock is automatically updated when device definitions change, ensuring system images stay in sync.

## Commands

Emulator commands:
```sh
devbox run start-android        # Build, install, and launch app on emulator
devbox run stop-emu             # Stop all running emulators
devbox run reset-emu            # Stop and reset all emulators (cleans AVD state)
devbox run reset-emu-device max # Reset a specific device
```

Device management:
```sh
devbox run android.sh devices list
devbox run android.sh devices create pixel_api28 --api 28 --device pixel --tag google_apis
devbox run android.sh devices update pixel_api28 --api 29
devbox run android.sh devices delete pixel_api28
devbox run android.sh devices select max min  # Select specific devices
devbox run android.sh devices reset           # Reset to all devices
devbox run android.sh devices eval            # Generate devices.lock
```

Build commands:
```sh
devbox run build-android        # Build with info logging
devbox run build-android-debug  # Build with full debug output
devbox run gradle-clean         # Clean build artifacts
```

Config and diagnostic commands:
```sh
devbox run android.sh config show
devbox run android.sh config set ANDROID_DEFAULT_DEVICE=max
devbox run android.sh config reset
devbox run android.sh info      # Show resolved SDK info
devbox run android.sh doctor    # Diagnose SDK version mismatches
```

## Environment variables

- `ANDROID_CONFIG_DIR` — project config directory (`devbox.d/android`)
- `ANDROID_DEVICES_DIR` — device definitions directory
- `ANDROID_SCRIPTS_DIR` — runtime scripts directory (`.devbox/virtenv/android/scripts`)
- `ANDROID_DEFAULT_DEVICE` — used when no device name is provided
- `EVALUATE_DEVICES` — list of device names to evaluate in the flake (empty means all)
- `ANDROID_APP_APK` — APK path or glob pattern (relative to project root) used for install/launch
