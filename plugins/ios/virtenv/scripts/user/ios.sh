#!/usr/bin/env sh
set -eu

usage() {
  cat >&2 <<'USAGE'
Usage: ios.sh <command> [args]

Commands:
  build [flags]              Auto-detect and build Xcode project
  devices <command> [args]
  simulator start [device] [--pure]
  simulator stop
  simulator reset
  run [app_path] [device]
  xcodebuild [args...]
  config show
  info

Build flags:
  --config Debug|Release     Build configuration (default: Debug)
  --scheme name              Xcode scheme (default: auto-detect)
  --workspace path           Path to .xcworkspace
  --project path             Path to .xcodeproj
  --derived-data path        DerivedData path
  --quiet                    Suppress xcodebuild output
  --action build|test        xcodebuild action (default: build)
  -- extra_args...           Extra args passed to xcodebuild

Examples:
  ios.sh build
  ios.sh build --config Release
  ios.sh build --action test
  ios.sh devices list
  ios.sh devices create iphone15 --runtime 17.5
  ios.sh simulator start max
  ios.sh simulator start max --pure
  ios.sh simulator stop
  ios.sh simulator reset
  ios.sh run
  ios.sh run max
  ios.sh run /path/to/MyApp.app
  ios.sh xcodebuild -project MyApp.xcodeproj -scheme MyApp build
  ios.sh config show
USAGE
  exit 1
}

command_name="${1-}"
if [ -z "$command_name" ] || [ "$command_name" = "help" ]; then
  usage
fi
shift || true

script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
  script_dir="${IOS_SCRIPTS_DIR}"
fi

case "$command_name" in
  build)
    # shellcheck disable=SC1090
    . "${script_dir}/domain/build.sh"
    ios_build "$@"
    ;;
  devices)
    exec "${script_dir}/user/devices.sh" "$@"
    ;;
  simulator)
    sub="${1-}"
    shift || true
    # Source simulator script
    # shellcheck disable=SC1090
    . "${script_dir}/domain/simulator.sh"

    case "$sub" in
      start)
        # Parse arguments for device name and --pure flag
        pure_mode=0
        device_name=""

        while [ $# -gt 0 ]; do
          case "$1" in
            --pure)
              pure_mode=1
              shift
              ;;
            *)
              if [ -z "$device_name" ]; then
                device_name="$1"
              fi
              shift
              ;;
          esac
        done

        # If --pure mode, create a separate test-specific simulator
        if [ "$pure_mode" = "1" ]; then
          export IOS_SIMULATOR_PURE=1
          echo "Pure mode: Creating fresh test simulator with clean state..."

          # Resolve device name from selection (like "max") to actual name (like "iPhone 17")
          if [ -n "$device_name" ]; then
            export IOS_DEFAULT_DEVICE="$device_name"
          fi

          # Get base device name and runtime
          device_base="$(resolve_service_device_name || true)"
          if [ -z "$device_base" ]; then
            echo "No iOS simulator device configured; set IOS_DEVICE_NAME or IOS_DEFAULT_DEVICE." >&2
            exit 1
          fi

          preferred_runtime="$(ios_device_runtime_for_name "$device_base" || true)"
          if [ -z "$preferred_runtime" ]; then
            preferred_runtime="${IOS_DEFAULT_RUNTIME:-}"
            if [ -z "$preferred_runtime" ] && command -v xcrun >/dev/null 2>&1; then
              preferred_runtime="$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null || true)"
            fi
          fi

          choice="$(resolve_runtime "$preferred_runtime" || true)"
          if [ -z "$choice" ]; then
            echo "No available iOS simulator runtime found. Install one in Xcode (Settings > Platforms) and retry." >&2
            exit 1
          fi

          runtime_id="$(printf '%s' "$choice" | cut -d'|' -f1)"
          runtime_name="$(printf '%s' "$choice" | cut -d'|' -f2)"

          # Create test-specific simulator name
          test_sim_name="${device_base} (${runtime_name}) Test"

          # Delete test simulator if it already exists
          existing_test_udid="$(xcrun simctl list devices -j | jq -r --arg name "$test_sim_name" '.devices[]?[]? | select(.name == $name) | .udid' | head -n1)"
          if [ -n "$existing_test_udid" ]; then
            echo "Deleting previous test simulator: $test_sim_name"
            xcrun simctl delete "$existing_test_udid" >/dev/null 2>&1 || true
          fi

          # Get device type identifier
          device_type="$(devicetype_id_for_name "$device_base" || true)"
          if [ -z "$device_type" ]; then
            echo "Device type '$device_base' not available" >&2
            exit 1
          fi

          # Create fresh test simulator
          echo "Creating test simulator: $test_sim_name"
          test_udid="$(xcrun simctl create "$test_sim_name" "$device_type" "$runtime_id" 2>&1)"

          if [ -z "$test_udid" ]; then
            echo "Failed to create test simulator" >&2
            exit 1
          fi

          # Boot the test simulator
          echo "Booting test simulator..."
          xcrun simctl boot "$test_udid" >/dev/null 2>&1 || true
          if ! xcrun simctl bootstatus "$test_udid" -b >/dev/null 2>&1; then
            while true; do
              state="$(xcrun simctl list devices -j | jq -r --arg udid "$test_udid" '.devices[]?[]? | select(.udid == $udid) | .state' | head -n1)"
              [ "$state" = "Booted" ] && break
              sleep 2
            done
          fi

          # Export test simulator info
          IOS_SIM_UDID="$test_udid"
          IOS_SIM_NAME="$test_sim_name"
          IOS_TEST_SIMULATOR="$test_udid"
          export IOS_SIM_UDID IOS_SIM_NAME IOS_TEST_SIMULATOR

          # Open Simulator app if not headless
          headless="${SIM_HEADLESS:-}"
          if [ -z "$headless" ]; then
            open -a Simulator --args -CurrentDeviceUDID "$test_udid" >/dev/null 2>&1 || true
          fi

          echo "Test simulator ready: ${test_sim_name} (${test_udid})"
        else
          # Normal mode - use regular simulator (don't touch dev's simulator)
          # Resolve device name from selection if provided
          if [ -n "$device_name" ]; then
            export IOS_DEFAULT_DEVICE="$device_name"
          fi
          ios_start
        fi
        ;;
      stop)
        # shellcheck disable=SC1090
        . "${script_dir}/domain/simulator.sh"

        # If this was a test simulator, delete it after stopping
        if [ -n "${IOS_TEST_SIMULATOR:-}" ]; then
          echo "Stopping and deleting test simulator..."
          xcrun simctl shutdown "$IOS_TEST_SIMULATOR" >/dev/null 2>&1 || true
          xcrun simctl delete "$IOS_TEST_SIMULATOR" >/dev/null 2>&1 || true
          echo "Test simulator deleted: $IOS_TEST_SIMULATOR"
          unset IOS_TEST_SIMULATOR
        else
          # Normal mode - just stop the simulator
          ios_stop
        fi
        ;;
      reset)
        # Stop all simulators and delete those matching device definitions
        echo "================================================"
        echo "iOS Simulator Reset"
        echo "================================================"
        echo ""

        # Stop all running simulators
        echo "Stopping all running simulators..."
        xcrun simctl shutdown all >/dev/null 2>&1 || true
        echo "  ✓ All simulators stopped"
        echo ""

        # Get device definitions
        devices_dir="${IOS_DEVICES_DIR:-./devbox.d/ios/devices}"
        if [ ! -d "$devices_dir" ]; then
          echo "No device definitions found at: $devices_dir"
          echo "Simulators stopped but not deleted."
          exit 0
        fi

        # Delete simulators matching device definitions
        echo "Deleting simulators matching device definitions..."
        deleted_count=0

        for device_file in "$devices_dir"/*.json; do
          [ -f "$device_file" ] || continue

          device_name="$(jq -r '.name // empty' "$device_file" 2>/dev/null || true)"
          if [ -z "$device_name" ]; then
            continue
          fi

          # Find simulators with this name
          matching_udids="$(xcrun simctl list devices -j | jq -r --arg name "$device_name" '.devices[]?[]? | select(.name == $name) | .udid' || true)"

          if [ -n "$matching_udids" ]; then
            for udid in $matching_udids; do
              if [ -n "$udid" ]; then
                echo "  Deleting: $device_name ($udid)"
                xcrun simctl delete "$udid" >/dev/null 2>&1 || true
                deleted_count=$((deleted_count + 1))
              fi
            done
          fi
        done

        echo ""
        echo "================================================"
        echo "✓ Reset complete!"
        echo "================================================"
        echo ""
        echo "Deleted $deleted_count simulator(s) matching device definitions."
        echo ""
        echo "To recreate simulators, run:"
        echo "  devbox run ios.sh simulator start [device]"
        ;;
      *)
        echo "Error: Unknown simulator command: $sub" >&2
        usage
        ;;
    esac
    ;;
  run)
    # shellcheck disable=SC1090
    . "${script_dir}/domain/deploy.sh"
    ios_run_app "$@"
    ;;
  config)
    sub="${1-}"
    shift || true
    # shellcheck disable=SC1090
    . "${script_dir}/user/config.sh"
    case "$sub" in
      show)
        ios_config_show
        ;;
      *)
        usage
        ;;
    esac
    ;;
  info)
    # Source init/setup.sh to get the ios_show_summary function
    if [ -f "${script_dir}/init/setup.sh" ]; then
      # shellcheck disable=SC1090
      . "${script_dir}/init/setup.sh"
      ios_show_summary
    else
      echo "Error: init/setup.sh not found" >&2
      exit 1
    fi
    ;;
  xcodebuild)
    # shellcheck disable=SC1090
    . "${script_dir}/platform/core.sh"
    ios_xcodebuild "$@"
    ;;
  *)
    usage
    ;;
esac
