#!/usr/bin/env bash
# Android Plugin - Application Run
# See SCRIPTS.md for detailed documentation

set -e

if ! (return 0 2>/dev/null); then
  echo "ERROR: deploy.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${ANDROID_RUN_LOADED:-}" = "1" ] && [ "${ANDROID_RUN_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_RUN_LOADED=1
ANDROID_RUN_LOADED_PID="$$"

# Source dependencies (Layer 1 & 2 only)
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ]; then
  . "${ANDROID_SCRIPTS_DIR}/lib/lib.sh"
  . "${ANDROID_SCRIPTS_DIR}/platform/core.sh"
fi

# NOTE: This script assumes the emulator is already running.
# Layer 4 is responsible for starting the emulator before calling android_run_app.

# Run Android project build via devbox
android_run_build() {
  project_root="$1"

  if ! command -v devbox >/dev/null 2>&1; then
    echo "ERROR: devbox is required to run the project build" >&2
    return 1
  fi

  echo "Building Android project: $project_root"

  # Try platform-specific build command first, then generic
  if (cd "$project_root" && devbox run --list 2>/dev/null | grep -q "build:android"); then
    (cd "$project_root" && devbox run --pure build:android)
  elif (cd "$project_root" && devbox run --list 2>/dev/null | grep -q "build"); then
    (cd "$project_root" && devbox run --pure build)
  else
    android_log_error "deploy.sh" "No build:android or build script found in devbox.json."
    android_log_error "deploy.sh" "Define a build script using native tools (e.g., gradle assembleDebug)."
    return 1
  fi
}

# Resolve APK path from glob pattern
# Args: project_root, apk_pattern
# Returns: first matching APK path
android_resolve_apk_glob() {
  _arg_root="$1"
  _arg_pattern="$2"

  if [ -z "$_arg_pattern" ]; then
    return 1
  fi

  # Make pattern absolute if it's relative
  if [ "${_arg_pattern#/}" = "$_arg_pattern" ]; then
    _arg_pattern="${_arg_root%/}/$_arg_pattern"
  fi

  set +f
  _matched=""
  for _candidate in $_arg_pattern; do
    if [ -f "$_candidate" ]; then
      _matched="${_matched}${_matched:+
}$_candidate"
    fi
  done
  set -f

  if [ -z "$_matched" ]; then
    return 1
  fi

  _count="$(printf '%s\n' "$_matched" | wc -l | tr -d ' ')"
  if [ "$_count" -gt 1 ]; then
    android_log_warn "deploy.sh" "Multiple APKs matched pattern: $_arg_pattern; using first match"
  fi

  printf '%s\n' "$_matched" | head -n1
}

# Find APK using auto-detect precedence chain
# Args: project_root
# Precedence:
#   1. ANDROID_APP_APK env var (glob resolved relative to project_root)
#   2. Recursive search of project_root for *.apk
#   3. Recursive search of $PWD (skipped if PWD == project_root)
#   4. Error with guidance
android_find_apk() {
  _find_root="$1"

  # 1. ANDROID_APP_APK env var
  if [ -n "${ANDROID_APP_APK:-}" ]; then
    _apk="$(android_resolve_apk_glob "$_find_root" "$ANDROID_APP_APK" || true)"
    if [ -n "$_apk" ] && [ -f "$_apk" ]; then
      android_log_info "deploy.sh" "APK resolved via ANDROID_APP_APK env var: $_apk"
      printf '%s\n' "$_apk"
      return 0
    fi
  fi

  # 2. Recursive search of project_root
  _apk="$(find "$_find_root" -name '*.apk' -type f \
    -not -path '*/.gradle/*' \
    -not -path '*/build/intermediates/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/.devbox/*' \
    2>/dev/null | head -n1)"
  if [ -n "$_apk" ] && [ -f "$_apk" ]; then
    android_log_info "deploy.sh" "APK resolved via project search: $_apk"
    printf '%s\n' "$_apk"
    return 0
  fi

  # 3. Recursive search of $PWD (skip if same as project_root)
  _cwd="$(cd "$PWD" && pwd -P)"
  _root_real="$(cd "$_find_root" && pwd -P)"
  if [ "$_cwd" != "$_root_real" ]; then
    _apk="$(find "$PWD" -name '*.apk' -type f \
      -not -path '*/.gradle/*' \
      -not -path '*/build/intermediates/*' \
      -not -path '*/node_modules/*' \
      -not -path '*/.devbox/*' \
      2>/dev/null | head -n1)"
    if [ -n "$_apk" ] && [ -f "$_apk" ]; then
      android_log_info "deploy.sh" "APK resolved via directory search: $_apk"
      printf '%s\n' "$_apk"
      return 0
    fi
  fi

  # 4. Error
  android_log_error "deploy.sh" "No APK found. Searched: ANDROID_APP_APK env var, project root, current directory."
  android_log_error "deploy.sh" "Set ANDROID_APP_APK in devbox.json env, or pass a path: android.sh run /path/to/app.apk"
  android_log_error "deploy.sh" "See: plugins/android/REFERENCE.md for APK resolution details."
  return 1
}

# Find aapt tool from Android SDK (PATH > SDK/build-tools)
android_resolve_aapt() {
  # Priority 1: aapt in PATH
  if command -v aapt >/dev/null 2>&1; then
    printf '%s\n' "aapt"
    return 0
  fi

  # Priority 2 & 3: Search in SDK build-tools
  if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
    # Try specific version if set
    if [ -n "${ANDROID_BUILD_TOOLS_VERSION:-}" ]; then
      aapt_path="${ANDROID_SDK_ROOT%/}/build-tools/${ANDROID_BUILD_TOOLS_VERSION}/aapt"
      if [ -x "$aapt_path" ]; then
        printf '%s\n' "$aapt_path"
        return 0
      fi
    fi

    # Try to find latest version
    aapt_path="$(find "${ANDROID_SDK_ROOT%/}/build-tools" -type f -name aapt 2>/dev/null | sort | tail -n1)"
    if [ -n "$aapt_path" ] && [ -x "$aapt_path" ]; then
      printf '%s\n' "$aapt_path"
      return 0
    fi
  fi

  return 1
}

# Extract app metadata from APK using aapt
android_extract_apk_metadata() {
  apk_path="$1"

  # Find aapt tool
  aapt_tool="$(android_resolve_aapt || true)"
  if [ -z "$aapt_tool" ]; then
    echo "ERROR: Unable to locate aapt tool" >&2
    echo "       Ensure Android build-tools are installed" >&2
    return 1
  fi

  # Dump APK badging
  apk_badging="$("$aapt_tool" dump badging "$apk_path" 2>/dev/null || true)"
  if [ -z "$apk_badging" ]; then
    echo "ERROR: Failed to read APK metadata from: $apk_path" >&2
    return 1
  fi

  # Extract package name
  package_name="$(printf '%s\n' "$apk_badging" | awk -F"'" '/package: name=/{print $2; exit}')"
  package_name="$(printf '%s' "$package_name" | tr -d '\r' | awk '{print $1}')"

  # Extract launchable activity
  activity_name="$(printf '%s\n' "$apk_badging" | awk -F"'" '/launchable-activity: name=/{print $2; exit}')"
  activity_name="$(printf '%s' "$activity_name" | tr -d '\r' | awk '{print $1}')"

  # Validate extraction
  if [ -z "$package_name" ]; then
    echo "ERROR: Unable to read package name from APK: $apk_path" >&2
    return 1
  fi

  if [ -z "$activity_name" ]; then
    echo "ERROR: Unable to resolve launchable activity for package: $package_name" >&2
    return 1
  fi

  # Return metadata (two lines)
  printf '%s\n' "$package_name"
  printf '%s\n' "$activity_name"
}

# Resolve full activity component name (normalize various formats)
android_resolve_activity_component() {
  package_name="$1"
  activity_name="$2"

  # If activity already contains a slash, use as-is
  case "$activity_name" in
    */*)
      printf '%s\n' "$activity_name"
      return 0
      ;;
  esac

  # Otherwise, build component name
  case "$activity_name" in
    .*)
      # Relative activity (e.g., ".MainActivity")
      printf '%s/%s\n' "$package_name" "$activity_name"
      ;;
    "$package_name"*)
      # Full package prefix (e.g., "com.example.app.MainActivity")
      printf '%s/%s\n' "$package_name" "$activity_name"
      ;;
    *)
      # Simple name (e.g., "MainActivity")
      printf '%s/%s\n' "$package_name" "$activity_name"
      ;;
  esac
}

# Install APK on emulator
android_install_apk() {
  apk_path="$1"
  emulator_serial="$2"

  echo "Installing APK: $(basename "$apk_path")"

  adb -s "$emulator_serial" wait-for-device
  adb -s "$emulator_serial" install -r "$apk_path" >/dev/null

  echo "✓ APK installed"
}

# Launch app on emulator via activity manager
android_launch_app() {
  package_name="$1"
  activity_name="$2"
  emulator_serial="$3"

  echo "Launching app: $package_name"

  # Build full component name
  component_name="$(android_resolve_activity_component "$package_name" "$activity_name")"

  android_debug_log "Launch component: $component_name"

  # Launch via activity manager
  if ! adb -s "$emulator_serial" shell am start -n "$component_name" >/dev/null 2>&1; then
    android_log_error "deploy.sh" "Failed to launch app: $component_name"
    android_log_error "deploy.sh" "Verify the package name and activity are correct."
    return 1
  fi

  echo "✓ App launched via activity manager"

  # Wait a moment for the app process to start
  sleep 2

  # Verify app process is running
  # CI emulators can be slow — adb shell pidof takes 1-2s per call and app
  # startup may need 10-20s on cold boot. Use 15 attempts × 2s = ~32s window.
  max_attempts=15
  attempt=0
  while [ $attempt -lt $max_attempts ]; do
    if adb -s "$emulator_serial" shell pidof "$package_name" >/dev/null 2>&1; then
      echo "✓ App process running"
      return 0
    fi
    attempt=$((attempt + 1))
    if [ $attempt -lt $max_attempts ]; then
      sleep 2
    fi
  done

  android_log_error "deploy.sh" "App process not detected after ${max_attempts} attempts"
  android_log_error "deploy.sh" "Check logcat for crash details: adb -s $emulator_serial logcat -d | grep $package_name"
  return 1
}

# Run Android app (build, install, launch)
# Usage: android_run_app [--apk <path>] [--device <name>] [<device>]
#   --apk <path>    - Path to APK file. If provided, skips build step.
#   --device <name> - Device name. If omitted, uses ANDROID_DEFAULT_DEVICE.
#   Bare positional arg is treated as device name for convenience.
android_run_app() {
  apk_arg=""
  device_choice=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --apk)
        apk_arg="${2:-}"
        shift 2
        ;;
      --device)
        device_choice="${2:-}"
        shift 2
        ;;
      *)
        # Bare positional arg: treat as device name for convenience
        if [ -z "$device_choice" ]; then
          device_choice="$1"
        fi
        shift
        ;;
    esac
  done

  # ---- Resolve Device Selection ----

  # Use provided device, or fall back to environment variables
  if [ -z "$device_choice" ] && [ -n "${ANDROID_DEFAULT_DEVICE:-}" ]; then
    device_choice="$ANDROID_DEFAULT_DEVICE"
  fi
  if [ -z "$device_choice" ]; then
    device_choice="${TARGET_DEVICE:-}"
  fi

  # ---- Start Deployment ----
  # NOTE: Emulator should already be running (started by layer 4)

  echo "================================================"
  echo "Android App Deployment"
  echo "================================================"
  echo ""

  # ---- Resolve APK Path ----

  if [ -n "$apk_arg" ]; then
    # APK provided as argument - use it directly
    apk_path="$apk_arg"

    # Make absolute if relative
    if [ "${apk_path#/}" = "$apk_path" ]; then
      apk_path="$PWD/$apk_path"
    fi

    if [ ! -f "$apk_path" ]; then
      echo "ERROR: APK not found: $apk_path" >&2
      exit 1
    fi

    echo "Using provided APK: $(basename "$apk_path")"
  else
    # No APK provided - build and locate

    # ---- Resolve Project Root ----

    project_root="${DEVBOX_PROJECT_ROOT:-${DEVBOX_PROJECT_DIR:-${DEVBOX_WD:-$PWD}}}"
    if [ -z "$project_root" ] || [ ! -d "$project_root" ]; then
      echo "ERROR: Unable to resolve project root for Android build" >&2
      exit 1
    fi

    echo ""
    echo "Project root: $project_root"

    # ---- Build App ----

    echo ""
    android_run_build "$project_root"

    # ---- Find APK ----

    echo ""
    echo "Locating APK..."

    apk_path="$(android_find_apk "$project_root" || true)"

    if [ -z "$apk_path" ] || [ ! -f "$apk_path" ]; then
      exit 1
    fi

    echo "Found APK: $(basename "$apk_path")"
  fi

  # ---- Extract Metadata ----

  echo ""
  echo "Extracting app metadata..."

  apk_metadata="$(android_extract_apk_metadata "$apk_path")"
  package_name="$(printf '%s\n' "$apk_metadata" | sed -n '1p')"
  activity_name="$(printf '%s\n' "$apk_metadata" | sed -n '2p')"

  echo "  Package: $package_name"
  echo "  Activity: $activity_name"

  # Save extracted metadata for other processes (test scripts, etc.)
  # This enables auto-detection of ANDROID_APP_ID without manual configuration
  runtime_dir="${ANDROID_RUNTIME_DIR:-${ANDROID_USER_HOME:-}}"
  if [ -n "$runtime_dir" ]; then
    mkdir -p "$runtime_dir"
    echo "$package_name" > "$runtime_dir/app-id.txt"
    echo "$activity_name" > "$runtime_dir/app-activity.txt"
  fi

  # ---- Deploy to Emulator ----

  emulator_serial="${ANDROID_EMULATOR_SERIAL:-emulator-${EMU_PORT:-5554}}"

  echo ""
  echo "Deploying to: $emulator_serial"
  echo ""

  # Stop and uninstall existing app to avoid signature conflicts
  if adb -s "$emulator_serial" shell pm list packages 2>/dev/null | grep -q "package:${package_name}$"; then
    echo "Removing existing install: $package_name"
    adb -s "$emulator_serial" shell am force-stop "$package_name" 2>/dev/null || true
    adb -s "$emulator_serial" uninstall "$package_name" >/dev/null 2>&1 || true
  fi

  android_install_apk "$apk_path" "$emulator_serial"
  echo ""
  android_launch_app "$package_name" "$activity_name" "$emulator_serial"

  echo ""
  echo "================================================"
  echo "✓ Deployment complete!"
  echo "================================================"
}
