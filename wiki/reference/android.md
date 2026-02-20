# Android Devbox Plugin Reference

## Files

- `.devbox/virtenv/android/android.json` — generated config (created from env vars for Nix flake evaluation)
- Device definitions in your devbox.d directory (e.g., `devbox.d/android/devices/*.json`)
- `devices/devices.lock` in your devbox.d directory — resolved API list for the SDK flake
- `.devbox/virtenv/android/scripts` — runtime scripts (added to PATH)
- `.devbox/virtenv/android/flake.nix` — SDK flake (device APIs drive evaluation)

## Device definition schema

Each device file is JSON with:
- `name` (string, required)
- `api` (number, required)
- `device` (AVD device id, required)
- `tag` (string, optional; e.g. `google_apis`, `google_apis_playstore`, `play_store`, `aosp_atd`, `google_atd`)
- `preferred_abi` (string, optional; `arm64-v8a`, `x86_64`, `x86`)

## Configuration (Environment Variables)

Configure the plugin by setting environment variables in `plugin.json`. These are automatically converted to JSON for internal use by the Nix flake.

- `ANDROID_LOCAL_SDK` — Use local SDK instead of Nix-managed SDK (0=false, 1=true)
- `ANDROID_COMPILE_SDK` — Compile SDK version (e.g., "36")
- `ANDROID_TARGET_SDK` — Target SDK version (e.g., "36")
- `ANDROID_DEVICES` — Array of device names to evaluate in flake (empty = all devices)
- `ANDROID_DEFAULT_DEVICE` — Default device name when none specified
- `ANDROID_SYSTEM_IMAGE_TAG` — System image tag (e.g., "google_apis", "google_apis_playstore")
- `ANDROID_APP_APK` — Path or glob pattern for APK (relative to project root)
- `ANDROID_BUILD_TOOLS_VERSION` — Build tools version (e.g., "36.1.0")
- `ANDROID_INCLUDE_NDK` — Include Android NDK in SDK (true/false, default: false)
- `ANDROID_NDK_VERSION` — NDK version when enabled (e.g., "27.0.12077973")
- `ANDROID_INCLUDE_CMAKE` — Include CMake in SDK (true/false, default: false)
- `ANDROID_CMAKE_VERSION` — CMake version when enabled (e.g., "3.22.1")
- `ANDROID_CMDLINE_TOOLS_VERSION` — Command-line tools version (e.g., "19.0")
- `ANDROID_BUILD_CONFIG` — Build configuration: Debug or Release (default: "Debug")
- `ANDROID_BUILD_TASK` — Gradle task override (empty = auto-derive from config, e.g., assembleDebug)

### Performance Settings
- `ANDROID_SKIP_SETUP` — Skip Android SDK downloads/evaluation during shell initialization (1=skip, 0=evaluate; default: 0)
  - Useful for iOS-only contexts in React Native projects to speed up initialization
  - When set to 1, skips Nix flake evaluation, SDK resolution, and environment configuration
  - Android commands will fail if SDK is actually needed, but iOS workflows run without delay

## Commands

### Run app

```bash
android.sh run [apk_path] [device]
```
- Builds, installs, and launches the app on the emulator
- If `apk_path` is provided, skips build step and installs provided APK
- If no arguments, builds project and auto-detects APK

**APK resolution precedence (when no explicit path):**

1. `ANDROID_APP_APK` env var — glob resolved relative to project root
2. Recursive search of project root for `*.apk` files (excludes .gradle/, build/intermediates/, node_modules/, .devbox/)
3. Recursive search of `$PWD` if different from project root (same exclusions)

**Build script detection:** Tries `build:android` first, then falls back to `build`. Define a build script in `devbox.json` using native tools (e.g., `gradle assembleDebug`).

### Emulator

- `devbox run --pure android.sh emulator start [--pure] [device]`
  - `--pure`: Start fresh emulator with wiped data (clean Android OS state for deterministic tests)
  - Without `--pure`: Reuses existing emulator if running (faster for development, preserves data)
  - Auto-detects pure mode when `DEVBOX_PURE_SHELL=1` (set by `devbox run --pure`)
  - `REUSE_EMU=1`: Override pure mode to reuse existing emulator (e.g., `devbox run --pure -e REUSE_EMU=1`)
- `devbox run --pure android.sh emulator stop`
- `devbox run --pure android.sh emulator ready`
  - Silent readiness probe: exit 0 if emulator is booted, exit 1 if not
  - Reads emulator serial from suite-namespaced state file
- `devbox run --pure android.sh emulator reset [device]`

**Convenience aliases:**
- `devbox run --pure start:emu [device]` (equivalent to `android.sh emulator start` without `--pure`)
- `devbox run --pure stop:emu` (equivalent to `android.sh emulator stop`)

**Behavior:**
- Without `--pure`: Checks if an emulator with the same AVD is already running and reuses it
- With `--pure`: Always starts a new emulator instance with `-wipe-data` flag (fresh Android OS)
- Emulator serial is saved to `$ANDROID_RUNTIME_DIR/${SUITE_NAME:-default}/emulator-serial.txt`

### Deploy

```bash
android.sh deploy [apk_path]
```
- Installs and launches an app on an already-running emulator (no build, no emulator start)
- If `apk_path` is provided, installs the specified APK
- If no arguments, auto-detects APK using the same resolution as `run`
- Saves app ID and activity to state files for use by `app status` and `app stop`

### App Lifecycle

```bash
android.sh app status
```
- Checks if the deployed app is running on the emulator
- Exit 0 if running, exit 1 if not

```bash
android.sh app stop
```
- Stops the deployed app via `adb shell am force-stop`

### Device management

- `devbox run --pure android.sh devices list`
- `devbox run --pure android.sh devices show <name>`
- `devbox run --pure android.sh devices create <name> --api <n> --device <id> [--tag <tag>] [--abi <abi>]`
- `devbox run --pure android.sh devices update <name> [--name <new>] [--api <n>] [--device <id>] [--tag <tag>] [--abi <abi>]`
- `devbox run --pure android.sh devices delete <name>`
- `devbox run --pure android.sh devices select <name...>`
- `devbox run --pure android.sh devices reset`
- `devbox run --pure android.sh devices eval`

### Config management

- `devbox run --pure android.sh config show`

Configuration is managed via environment variables in `devbox.json`, not via CLI commands. Run `config show` to see current values and how to override them.

## Environment variables

### Plugin directories
- `ANDROID_CONFIG_DIR` - Configuration directory
- `ANDROID_DEVICES_DIR` - Device definitions directory
- `ANDROID_SCRIPTS_DIR` - Runtime scripts directory

### Device selection
- `ANDROID_DEFAULT_DEVICE` - Default device name when none specified (set in devbox.json)
- `ANDROID_DEVICES` - Device names to evaluate in flake (comma-separated, empty = all; set in devbox.json)
- `ANDROID_DEVICE_NAME` - Override device selection at runtime (e.g., `ANDROID_DEVICE_NAME=min devbox run start:emu`)
- `TARGET_DEVICE` - Alias for ANDROID_DEVICE_NAME (legacy, prefer ANDROID_DEVICE_NAME)

### Emulator configuration
- `EMU_HEADLESS` - Run emulator headless (no GUI window)
- `EMU_PORT` - Preferred emulator port (default: 5554)
- `ANDROID_EMULATOR_PURE` - Always start fresh emulator with clean state (0/1, default: 0)
- `ANDROID_SKIP_CLEANUP` - Skip offline emulator cleanup during startup (0/1, default: 0)
  - Set to 1 in multi-emulator scenarios to prevent cleanup from killing emulators that are still booting
- `ANDROID_DISABLE_SNAPSHOTS` - Disable snapshot boots, force cold boot (0/1, default: 0)
- `ANDROID_SKIP_SETUP` - Skip all Android setup and SDK evaluation (0/1, default: 0)
  - Useful in React Native plugin when running iOS-only workflows to avoid downloading Android SDK
  - Set before shell initialization: `devbox run -e ANDROID_SKIP_SETUP=1 build:ios`
  - With --pure flag: `devbox run --pure -e ANDROID_SKIP_SETUP=1 build:ios`
  - Or set in test suite environment sections (process-compose spawns new shells)
  - Cannot be set within script definitions (too late, init hook already ran)

### Runtime state
- `ANDROID_RUNTIME_DIR` - Directory for runtime state files (default: `.devbox/virtenv/android`)
- `SUITE_NAME` - Test suite name for state isolation (default: "default")
  - Each suite gets its own subdirectory under `$ANDROID_RUNTIME_DIR/$SUITE_NAME/`
  - State files: `emulator-serial.txt`, `app-id.txt`, `app-activity.txt`
  - Set in process-compose environment blocks for parallel test execution

### App configuration
- `ANDROID_APP_APK` - Path or glob pattern for APK (relative to project root; empty = auto-detect)
- `ANDROID_BUILD_CONFIG` - Build configuration: Debug or Release (default: Debug)
- `ANDROID_BUILD_TASK` - Gradle task override (empty = auto-derive from config)
