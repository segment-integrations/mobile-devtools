#!/usr/bin/env sh
# Android Plugin - Main CLI Entry Point
#
# This is the primary command-line interface for Android plugin operations.
# It routes commands to appropriate handlers.
#
# User-Overridable Variables:
#   ANDROID_CONFIG_DIR - Android configuration directory (default: devbox.d/android)
#   ANDROID_SCRIPTS_DIR - Scripts directory

set -eu

# ============================================================================
# Initialize Android Environment
# ============================================================================
# Auto-setup SDK if not already done (e.g., when called from process-compose)
if [ -z "${ANDROID_SDK_ROOT:-}" ] && [ -n "${ANDROID_SCRIPTS_DIR:-}" ]; then
  if [ -f "${ANDROID_SCRIPTS_DIR}/init/setup.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/init/setup.sh"
  fi
fi

# ============================================================================
# Usage and Help
# ============================================================================

usage() {
  cat >&2 <<'USAGE'
Usage: android.sh <command> [args]

Commands:
  build [flags]                    Auto-detect and build Gradle project
  deploy [apk_path]                Install and launch app on running emulator
  devices <command> [args]         Manage device definitions
  info                             Display resolved SDK information
  config <command>                 Manage configuration
  emulator start [device]          Start Android emulator
  emulator stop                    Stop running emulator
  emulator ready                   Check if emulator is booted (readiness probe)
  emulator reset                   Reset all emulator AVDs
  app status                       Check if deployed app is running
  app stop                         Stop the deployed app
  run [apk_path] [device]          Build, install, and launch app on emulator

Build flags:
  --config Debug|Release           Build configuration (default: Debug)
  --task gradle_task               Gradle task override
  --quiet                          Suppress Gradle output
  -- extra_args...                 Extra args passed to gradle

Examples:
  android.sh build
  android.sh build --config Release
  android.sh build --task bundleRelease
  android.sh deploy
  android.sh deploy path/to/app.apk
  android.sh devices list
  android.sh devices create pixel_api28 --api 28 --device pixel
  android.sh info
  android.sh config show
  android.sh emulator start max
  android.sh emulator stop
  android.sh emulator ready
  android.sh app status
  android.sh app stop
  android.sh run                             # Build, install, launch
  android.sh run max                         # Same, but on 'max' device
  android.sh run path/to/app.apk             # Install provided APK
  android.sh run path/to/app.apk max         # Install APK on 'max' device

Note: Configuration is managed via environment variables in devbox.json.
USAGE
  exit 1
}

# ============================================================================
# Initialize Variables
# ============================================================================

command_name="${1-}"
if [ -z "$command_name" ] || [ "$command_name" = "help" ]; then
  usage
fi
shift || true

# Local variables (derived from user-overridable variables)
config_dir="${ANDROID_CONFIG_DIR:-./devbox.d/android}"
scripts_dir="${ANDROID_SCRIPTS_DIR:-${config_dir%/}/scripts}"

# ============================================================================
# Helper Functions
# ============================================================================

# Ensure lib.sh is loaded for shared utilities
ensure_lib_loaded() {
  if ! command -v android_require_jq >/dev/null 2>&1; then
    if [ -f "${scripts_dir}/lib/lib.sh" ]; then
      . "${scripts_dir}/lib/lib.sh"
    else
      echo "ERROR: lib/lib.sh not found. Cannot continue." >&2
      exit 1
    fi
  fi
}

# Derive suite-namespaced state directory
android_state_dir() {
  _suite="${SUITE_NAME:-default}"
  _runtime_dir="${ANDROID_RUNTIME_DIR:-${ANDROID_USER_HOME:-}}"
  if [ -z "$_runtime_dir" ]; then
    _runtime_dir="${PWD}/.devbox/virtenv"
  fi
  printf '%s/%s' "$_runtime_dir" "$_suite"
}

# ============================================================================
# Command Handlers
# ============================================================================

case "$command_name" in
  # --------------------------------------------------------------------------
  # build - Auto-detect and build Gradle project
  # --------------------------------------------------------------------------
  build)
    ensure_lib_loaded

    build_script="${scripts_dir%/}/domain/build.sh"
    if [ ! -f "$build_script" ]; then
      echo "ERROR: domain/build.sh not found: $build_script" >&2
      exit 1
    fi

    # shellcheck source=/dev/null
    . "$build_script"
    android_build "$@"
    ;;

  # --------------------------------------------------------------------------
  # deploy - Install and launch app on running emulator (no build, no emu start)
  # --------------------------------------------------------------------------
  deploy)
    ensure_lib_loaded

    deploy_script="${scripts_dir%/}/domain/deploy.sh"
    if [ ! -f "$deploy_script" ]; then
      echo "ERROR: domain/deploy.sh not found: $deploy_script" >&2
      exit 1
    fi

    # shellcheck source=/dev/null
    . "$deploy_script"

    apk_arg="${1:-}"
    state_dir="$(android_state_dir)"

    # Read serial from state file (suite-namespaced, then legacy, then env var)
    emulator_serial=""
    if [ -f "$state_dir/emulator-serial.txt" ]; then
      emulator_serial="$(cat "$state_dir/emulator-serial.txt")"
    fi
    if [ -z "$emulator_serial" ]; then
      runtime_dir="${ANDROID_RUNTIME_DIR:-${ANDROID_USER_HOME:-}}"
      if [ -n "$runtime_dir" ] && [ -f "$runtime_dir/emulator-serial.txt" ]; then
        emulator_serial="$(cat "$runtime_dir/emulator-serial.txt")"
      fi
    fi
    if [ -z "$emulator_serial" ]; then
      emulator_serial="${ANDROID_EMULATOR_SERIAL:-emulator-${EMU_PORT:-5554}}"
    fi

    # Resolve APK path
    if [ -n "$apk_arg" ]; then
      apk_path="$apk_arg"
      if [ "${apk_path#/}" = "$apk_path" ]; then
        apk_path="$PWD/$apk_path"
      fi
      if [ ! -f "$apk_path" ]; then
        echo "ERROR: APK not found: $apk_path" >&2
        exit 1
      fi
    else
      project_root="${DEVBOX_PROJECT_ROOT:-${DEVBOX_PROJECT_DIR:-${DEVBOX_WD:-$PWD}}}"
      apk_path="$(android_find_apk "$project_root" || true)"
      if [ -z "$apk_path" ] || [ ! -f "$apk_path" ]; then
        echo "ERROR: No APK found. Build first with 'android.sh build'." >&2
        exit 1
      fi
    fi

    echo "APK: $(basename "$apk_path")"

    # Extract metadata
    apk_metadata="$(android_extract_apk_metadata "$apk_path")"
    package_name="$(printf '%s\n' "$apk_metadata" | sed -n '1p')"
    activity_name="$(printf '%s\n' "$apk_metadata" | sed -n '2p')"

    echo "Package: $package_name"
    echo "Activity: $activity_name"

    # Install and launch
    android_install_apk "$apk_path" "$emulator_serial"
    android_launch_app "$package_name" "$activity_name" "$emulator_serial"

    # Save state
    mkdir -p "$state_dir"
    echo "$package_name" > "$state_dir/app-id.txt"
    echo "$activity_name" > "$state_dir/app-activity.txt"

    echo "Deploy complete"
    ;;

  # --------------------------------------------------------------------------
  # devices - Delegate to devices.sh
  # --------------------------------------------------------------------------
  devices)
    devices_script="${scripts_dir%/}/user/devices.sh"
    if [ ! -x "$devices_script" ]; then
      echo "ERROR: devices.sh not found or not executable: $devices_script" >&2
      exit 1
    fi
    exec "$devices_script" "$@"
    ;;

  # --------------------------------------------------------------------------
  # info - Display SDK information
  # --------------------------------------------------------------------------
  info)
    # Source core.sh to get android_show_summary function
    ensure_lib_loaded

    core_script="${scripts_dir}/platform/core.sh"
    if [ ! -f "$core_script" ]; then
      echo "ERROR: platform/core.sh not found: $core_script" >&2
      exit 1
    fi

    # shellcheck source=/dev/null
    . "$core_script"

    # Call summary function (defined in core.sh)
    if command -v android_show_summary >/dev/null 2>&1; then
      android_show_summary
    else
      echo "ERROR: android_show_summary function not available" >&2
      exit 1
    fi
    ;;

  # --------------------------------------------------------------------------
  # config - Configuration management
  # --------------------------------------------------------------------------
  config)
    subcommand="${1-}"
    shift || true

    # Source config.sh
    config_script="${scripts_dir%/}/user/config.sh"
    if [ ! -f "$config_script" ]; then
      echo "ERROR: user/config.sh not found: $config_script" >&2
      exit 1
    fi

    # shellcheck source=/dev/null
    . "$config_script"

    case "$subcommand" in
      show)
        if command -v android_config_show >/dev/null 2>&1; then
          android_config_show
        else
          echo "ERROR: android_config_show function not available" >&2
          exit 1
        fi
        ;;

      set)
        if command -v android_config_set >/dev/null 2>&1; then
          android_config_set "$@"
        else
          echo "ERROR: android_config_set function not available" >&2
          exit 1
        fi
        ;;

      reset)
        if command -v android_config_reset >/dev/null 2>&1; then
          android_config_reset
        else
          echo "ERROR: android_config_reset function not available" >&2
          exit 1
        fi
        ;;

      *)
        echo "ERROR: Unknown config subcommand: $subcommand" >&2
        echo "Usage: android.sh config <show|set|reset>" >&2
        exit 1
        ;;
    esac
    ;;

  # --------------------------------------------------------------------------
  # emulator - Emulator lifecycle management
  # --------------------------------------------------------------------------
  emulator)
    subcommand="${1-}"
    shift || true

    # Source layer 3 dependencies (emulator needs AVD functions)
    avd_script="${scripts_dir%/}/domain/avd.sh"
    emulator_script="${scripts_dir%/}/domain/emulator.sh"

    if [ ! -f "$avd_script" ]; then
      echo "ERROR: domain/avd.sh not found: $avd_script" >&2
      exit 1
    fi
    if [ ! -f "$emulator_script" ]; then
      echo "ERROR: domain/emulator.sh not found: $emulator_script" >&2
      exit 1
    fi

    # Source avd.sh first (emulator depends on it)
    # shellcheck source=/dev/null
    . "$avd_script"
    # shellcheck source=/dev/null
    . "$emulator_script"

    case "$subcommand" in
      start)
        # Parse flags and device name
        pure_mode=0
        wait_ready=0
        device_name=""

        while [ $# -gt 0 ]; do
          case "$1" in
            --pure)
              pure_mode=1
              shift
              ;;
            --wait-ready)
              wait_ready=1
              shift
              ;;
            *)
              device_name="$1"
              shift
              ;;
          esac
        done

        # Auto-detect pure mode from devbox environment
        if [ "${DEVBOX_PURE_SHELL:-}" = "1" ]; then
          pure_mode=1
        fi

        # Allow overriding pure mode to reuse existing emulator
        # Usage: devbox run --pure -e REUSE_EMU=1 android.sh emulator start
        if [ "${REUSE_EMU:-}" = "1" ]; then
          pure_mode=0
        fi

        # Layer 3 orchestration: setup AVDs first, then start emulator
        if ! command -v android_setup_avds >/dev/null 2>&1; then
          echo "ERROR: android_setup_avds function not available" >&2
          exit 1
        fi
        if ! command -v android_start_emulator >/dev/null 2>&1; then
          echo "ERROR: android_start_emulator function not available" >&2
          exit 1
        fi

        # If --pure mode, set flag for emulator to wipe data
        if [ "$pure_mode" = "1" ]; then
          export ANDROID_EMULATOR_PURE=1
        fi

        # Step 1: Setup AVDs (ensures they exist and match definitions)
        echo "Setting up Android Virtual Devices..."
        android_setup_avds

        # Step 2: Start emulator (uses ANDROID_RESOLVED_AVD from setup)
        android_start_emulator "$device_name"

        # Step 3: Save serial to suite-namespaced state dir
        state_dir="$(android_state_dir)"
        mkdir -p "$state_dir"
        if [ -n "${ANDROID_EMULATOR_SERIAL:-}" ]; then
          echo "$ANDROID_EMULATOR_SERIAL" > "$state_dir/emulator-serial.txt"
        fi

        # Step 4: If --wait-ready, wait for emulator to be ready and exit (detach mode for dev)
        # Otherwise in pure mode, keep running (process-compose manages lifecycle)
        if [ "$wait_ready" = "1" ]; then
          echo "Waiting for emulator to be ready..."
          max_wait=120
          elapsed=0
          while ! android_emulator_ready; do
            sleep 3
            elapsed=$((elapsed + 3))
            if [ $elapsed -ge $max_wait ]; then
              echo "ERROR: Emulator did not become ready within ${max_wait}s" >&2
              exit 1
            fi
          done
          echo "✓ Emulator ready and running in background"
          exit 0
        fi
        ;;

      stop)
        if command -v android_stop_emulator >/dev/null 2>&1; then
          android_stop_emulator
        else
          echo "ERROR: android_stop_emulator function not available" >&2
          exit 1
        fi
        ;;

      ready)
        # Silent readiness probe: exit 0 if booted, 1 if not
        state_dir="$(android_state_dir)"
        serial=""

        if [ -f "$state_dir/emulator-serial.txt" ]; then
          serial="$(cat "$state_dir/emulator-serial.txt")"
        fi

        # Fallback to legacy location
        if [ -z "$serial" ]; then
          runtime_dir="${ANDROID_RUNTIME_DIR:-${ANDROID_USER_HOME:-}}"
          if [ -n "$runtime_dir" ] && [ -f "$runtime_dir/emulator-serial.txt" ]; then
            serial="$(cat "$runtime_dir/emulator-serial.txt")"
          fi
        fi

        if [ -z "$serial" ]; then
          exit 1
        fi

        if adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; then
          exit 0
        fi
        exit 1
        ;;

      reset)
        avd_reset_script="${scripts_dir%/}/domain/avd-reset.sh"
        if [ ! -f "$avd_reset_script" ]; then
          echo "ERROR: domain/avd-reset.sh not found: $avd_reset_script" >&2
          exit 1
        fi
        # shellcheck source=/dev/null
        . "$avd_reset_script"

        if command -v android_stop_emulator >/dev/null 2>&1 && command -v android_reset_avds >/dev/null 2>&1; then
          android_stop_emulator
          android_reset_avds
        else
          echo "ERROR: Required functions not available" >&2
          exit 1
        fi
        ;;

      *)
        echo "ERROR: Unknown emulator subcommand: $subcommand" >&2
        echo "Usage: android.sh emulator <start|stop|ready|reset> [device]" >&2
        exit 1
        ;;
    esac
    ;;

  # --------------------------------------------------------------------------
  # app - App lifecycle management
  # --------------------------------------------------------------------------
  app)
    subcommand="${1-}"
    shift || true

    state_dir="$(android_state_dir)"

    case "$subcommand" in
      status)
        # Check if deployed app is running (exit 0 if running, 1 if not)
        app_id=""
        if [ -f "$state_dir/app-id.txt" ]; then
          app_id="$(cat "$state_dir/app-id.txt")"
        fi
        # Fallback to legacy location
        if [ -z "$app_id" ]; then
          runtime_dir="${ANDROID_RUNTIME_DIR:-${ANDROID_USER_HOME:-}}"
          if [ -n "$runtime_dir" ] && [ -f "$runtime_dir/app-id.txt" ]; then
            app_id="$(cat "$runtime_dir/app-id.txt")"
          fi
        fi
        if [ -z "$app_id" ]; then
          exit 1
        fi

        serial=""
        if [ -f "$state_dir/emulator-serial.txt" ]; then
          serial="$(cat "$state_dir/emulator-serial.txt")"
        fi
        if [ -z "$serial" ]; then
          runtime_dir="${ANDROID_RUNTIME_DIR:-${ANDROID_USER_HOME:-}}"
          if [ -n "$runtime_dir" ] && [ -f "$runtime_dir/emulator-serial.txt" ]; then
            serial="$(cat "$runtime_dir/emulator-serial.txt")"
          fi
        fi
        if [ -z "$serial" ]; then
          serial="emulator-${EMU_PORT:-5554}"
        fi

        if adb -s "$serial" shell pidof "$app_id" >/dev/null 2>&1; then
          exit 0
        fi
        exit 1
        ;;

      stop)
        # Stop the deployed app
        app_id=""
        if [ -f "$state_dir/app-id.txt" ]; then
          app_id="$(cat "$state_dir/app-id.txt")"
        fi
        if [ -z "$app_id" ]; then
          runtime_dir="${ANDROID_RUNTIME_DIR:-${ANDROID_USER_HOME:-}}"
          if [ -n "$runtime_dir" ] && [ -f "$runtime_dir/app-id.txt" ]; then
            app_id="$(cat "$runtime_dir/app-id.txt")"
          fi
        fi

        serial=""
        if [ -f "$state_dir/emulator-serial.txt" ]; then
          serial="$(cat "$state_dir/emulator-serial.txt")"
        fi
        if [ -z "$serial" ]; then
          runtime_dir="${ANDROID_RUNTIME_DIR:-${ANDROID_USER_HOME:-}}"
          if [ -n "$runtime_dir" ] && [ -f "$runtime_dir/emulator-serial.txt" ]; then
            serial="$(cat "$runtime_dir/emulator-serial.txt")"
          fi
        fi
        if [ -z "$serial" ]; then
          serial="emulator-${EMU_PORT:-5554}"
        fi

        if [ -n "$app_id" ]; then
          adb -s "$serial" shell am force-stop "$app_id" 2>/dev/null || true
          echo "App stopped: $app_id"
        else
          echo "No app to stop"
        fi
        ;;

      *)
        echo "ERROR: Unknown app subcommand: $subcommand" >&2
        echo "Usage: android.sh app <status|stop>" >&2
        exit 1
        ;;
    esac
    ;;

  # --------------------------------------------------------------------------
  # run - Build, install, and launch app on emulator
  # Usage: android.sh run [apk_path] [device]
  # --------------------------------------------------------------------------
  run)
    # Parse arguments - first arg could be APK path or device name
    apk_arg=""
    device_name=""

    if [ $# -gt 0 ]; then
      # If first arg looks like a file path (contains / or ends with .apk), treat as APK
      if printf '%s' "$1" | grep -q -e '/' -e '\.apk$'; then
        apk_arg="$1"
        shift
      fi
    fi

    # Remaining arg is device name
    device_name="${1:-}"

    # Source layer 3 dependencies
    avd_script="${scripts_dir%/}/domain/avd.sh"
    emulator_script="${scripts_dir%/}/domain/emulator.sh"
    deploy_script="${scripts_dir%/}/domain/deploy.sh"

    for script in "$avd_script" "$emulator_script" "$deploy_script"; do
      if [ ! -f "$script" ]; then
        echo "ERROR: Required script not found: $script" >&2
        exit 1
      fi
    done

    # Source all layer 3 scripts (order doesn't matter - they're independent)
    # shellcheck source=/dev/null
    . "$avd_script"
    # shellcheck source=/dev/null
    . "$emulator_script"
    # shellcheck source=/dev/null
    . "$deploy_script"

    # Verify functions are available
    for func in android_setup_avds android_start_emulator android_run_app; do
      if ! command -v "$func" >/dev/null 2>&1; then
        echo "ERROR: $func function not available" >&2
        exit 1
      fi
    done

    # Layer 4 orchestration: setup -> start -> run
    echo "Setting up Android Virtual Devices..."
    android_setup_avds

    echo ""
    echo "Starting emulator..."
    android_start_emulator "$device_name"

    echo ""
    # Pass both APK (if provided) and device name to run
    if [ -n "$apk_arg" ]; then
      android_run_app "$apk_arg" "$device_name"
    else
      android_run_app "$device_name"
    fi
    ;;

  # --------------------------------------------------------------------------
  # Unknown command
  # --------------------------------------------------------------------------
  *)
    echo "ERROR: Unknown command: $command_name" >&2
    usage
    ;;
esac
