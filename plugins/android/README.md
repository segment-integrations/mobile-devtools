# Android Devbox Plugin

This plugin provides reproducible Android development environments by:
- Pinning Android user data (AVDs, emulator configs, adb keys) to the project virtenv
- Managing Android SDK versions through Nix
- Version controlling Android configuration via lock files

## Architecture: Env Vars → Lock Files → Reproducible Builds

The plugin uses a **two-stage configuration model**:

1. **Configuration (env vars in `devbox.json`)** - Easy to edit, defines desired state
2. **Lock files (in `devbox.d/`)** - Committed to git, ensures team-wide reproducibility

### Configuration Files

```
devbox.d/segment-integrations.mobile-devtools.android/
├── flake.nix          # Nix template (from plugin, committed)
├── flake.lock         # Pins nixpkgs version (committed)
├── android.lock       # Pins Android SDK config (committed)
└── devices/
    ├── devices.lock   # Pins device definitions (committed)
    ├── min.json       # Device configs (committed)
    └── max.json
```

**Why lock files?**
- `flake.lock` → Ensures everyone uses the same nixpkgs (same Android package versions)
- `android.lock` → Makes Android SDK changes reviewable in PRs
- `devices.lock` → Pins which devices/APIs are used for testing

**Why not just env vars?**
- Env vars are easy to change but invisible in diffs
- Lock files make configuration changes explicit and reviewable
- Prevents "works on my machine" when team members have different configs

## Quickstart

```sh
# List devices
devbox run android.sh devices list

# Build + install + launch app on emulator
devbox run start:android

# Stop all emulators
devbox run stop:emu

# Reset emulator state (useful after Nix package updates)
devbox run reset:emu
```

`start:android` starts the emulator, builds the app (via `build:android` or `build` script), and installs/launches the APK matched by `ANDROID_APP_APK`.

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

Then sync the configuration:
```bash
devbox run android:sync
```

## How to Update Android SDK Versions

The Android SDK configuration uses a **two-stage model**: env vars → lock files.

### Step 1: Edit Environment Variables

Change Android SDK settings in your `devbox.json`:

```json
{
  "env": {
    "ANDROID_BUILD_TOOLS_VERSION": "36.1.0",
    "ANDROID_COMPILE_SDK": "35",
    "ANDROID_TARGET_SDK": "35",
    "ANDROID_SYSTEM_IMAGE_TAG": "google_apis"
  }
}
```

At this point, **the changes are NOT applied yet**. The old `android.lock` is still in effect.

### Step 2: Sync Configuration

Run the sync command to generate lock files:

```sh
devbox run android:sync
```

This command:
1. Generates `android.lock` from your env vars (pins Android SDK config)
2. Regenerates `devices.lock` from device JSON files (pins device APIs)
3. Syncs AVDs to match device definitions

### Step 3: Review and Commit

```sh
git diff devbox.d/       # Review what changed in lock files
git add devbox.json devbox.d/
git commit -m "chore: update Android SDK to API 35"
```

### Why This Two-Stage Model?

**Reproducibility**: Lock files ensure everyone on the team uses identical Android SDK versions, even if plugin versions differ.

**Reviewability**: Android SDK changes are visible in PRs. Reviewers can see:
- Which SDK versions changed
- Which device APIs were added/removed
- Whether nixpkgs was updated

**Explicit Updates**: Changing env vars doesn't immediately affect builds. You must explicitly sync, preventing accidental misconfigurations.

### Drift Detection

If env vars don't match the lock file, you'll see a warning on `devbox shell`:

```
⚠️  WARNING: Android configuration has changed but lock file is outdated.

Environment variables don't match android.lock:
  ANDROID_BUILD_TOOLS_VERSION: "36.1.0" (env) vs "35.0.0" (lock)

To apply changes:
  devbox run android:sync

To revert changes:
  Edit devbox.json to match the lock file
```

This prevents deploying with mismatched configurations.

## Updating nixpkgs

The `flake.lock` pins which version of nixpkgs provides Android packages. Update it separately from Android SDK versions:

```sh
cd devbox.d/segment-integrations.mobile-devtools.android/
nix flake update
```

This updates nixpkgs to the latest, which may provide:
- Newer Android SDK package versions
- Bug fixes in Nix Android packaging
- Security updates

**When to update nixpkgs:**
- Android SDK packages fail to build
- You need a newer package version not available in current nixpkgs
- Regular maintenance (e.g., monthly)

**Don't conflate**: Updating Android SDK config (env vars) vs updating nixpkgs (flake.lock) are separate concerns.

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
Use `devbox run android.sh devices select max` to update this value, then run `devbox run android:sync` to apply.

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
devbox run android:sync                       # Sync all config (android.lock + devices.lock + AVDs)
devbox run android.sh devices list
devbox run android.sh devices create pixel_api28 --api 28 --device pixel --tag google_apis
devbox run android.sh devices update pixel_api28 --api 29
devbox run android.sh devices delete pixel_api28
devbox run android.sh devices select max min  # Select specific devices (then run android:sync)
devbox run android.sh devices reset           # Reset to all devices (then run android:sync)
devbox run android.sh devices eval            # Generate devices.lock only (use android:sync instead)
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
