#!/usr/bin/env sh
set -eu

usage() {
  cat >&2 <<'USAGE'
Usage: ios.sh <command> [args]

Commands:
  build [flags]              Auto-detect and build Xcode project
  deploy [app_path]          Install and launch app on running simulator
  devices <command> [args]
  simulator start [device] [--pure]
  simulator stop
  simulator ready
  simulator reset
  app status                 Check if deployed app is running
  app stop                   Stop the deployed app
  run [app_path] [device]    Build, start sim, install, and launch
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
  ios.sh deploy
  ios.sh deploy /path/to/MyApp.app
  ios.sh devices list
  ios.sh devices create iphone15 --runtime 17.5
  ios.sh simulator start max
  ios.sh simulator start max --pure
  ios.sh simulator stop
  ios.sh simulator ready
  ios.sh simulator reset
  ios.sh app status
  ios.sh app stop
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

# Derive suite-namespaced state directory
ios_state_dir() {
  _suite="${SUITE_NAME:-default}"
  _runtime_dir="${IOS_RUNTIME_DIR:-}"
  if [ -z "$_runtime_dir" ]; then
    # Fallback for environments where plugin.json hasn't set it
    if [ -n "${DEVBOX_PROJECT_ROOT:-}" ]; then
      _runtime_dir="${DEVBOX_PROJECT_ROOT}/.devbox/virtenv/ios/runtime"
    else
      _runtime_dir="${PWD}/.devbox/virtenv/ios/runtime"
    fi
  fi
  printf '%s/%s' "$_runtime_dir" "$_suite"
}

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
        # Parse arguments for device name and flags
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
              if [ -z "$device_name" ]; then
                device_name="$1"
              fi
              shift
              ;;
          esac
        done

        # Auto-detect pure mode from devbox environment
        if [ "${DEVBOX_PURE_SHELL:-}" = "1" ]; then
          pure_mode=1
        fi

        # Allow overriding pure mode to reuse existing simulator
        # Usage: devbox run --pure -e REUSE_SIM=1 ios.sh simulator start
        if [ "${REUSE_SIM:-}" = "1" ]; then
          pure_mode=0
        fi

        # Prepare state directory
        state_dir="$(ios_state_dir)"
        mkdir -p "$state_dir"

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

          # Create test-specific simulator name (includes suite name for isolation)
          suite_label="${SUITE_NAME:-default}"
          test_sim_name="${device_base} (${runtime_name}) Test-${suite_label}"

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

          # Save state to runtime dir
          echo "$test_udid" > "$state_dir/simulator-udid.txt"
          echo "$test_udid" > "$state_dir/test-simulator-udid.txt"

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

          # Save UDID to state dir
          if [ -n "${IOS_SIM_UDID:-}" ]; then
            echo "$IOS_SIM_UDID" > "$state_dir/simulator-udid.txt"
          fi
        fi

        # If --wait-ready, wait for simulator to be ready and exit (detach mode for dev)
        # Otherwise in pure mode, keep running (process-compose manages lifecycle)
        if [ "$wait_ready" = "1" ]; then
          echo "Waiting for simulator to be ready..."
          max_wait=60
          elapsed=0
          while ! ios_simulator_ready; do
            sleep 2
            elapsed=$((elapsed + 2))
            if [ $elapsed -ge $max_wait ]; then
              echo "ERROR: Simulator did not become ready within ${max_wait}s" >&2
              exit 1
            fi
          done
          echo "✓ Simulator ready and running in background"
          exit 0
        fi
        ;;
      stop)
        state_dir="$(ios_state_dir)"

        # Check for test simulator in state dir
        test_udid=""
        if [ -f "$state_dir/test-simulator-udid.txt" ]; then
          test_udid="$(cat "$state_dir/test-simulator-udid.txt")"
        fi

        if [ -n "$test_udid" ]; then
          echo "Stopping and deleting test simulator..."
          xcrun simctl shutdown "$test_udid" >/dev/null 2>&1 || true
          xcrun simctl delete "$test_udid" >/dev/null 2>&1 || true
          echo "Test simulator deleted: $test_udid"

          # Clean up all state files
          rm -f "$state_dir/simulator-udid.txt"
          rm -f "$state_dir/test-simulator-udid.txt"
          rm -f "$state_dir/bundle-id.txt"
        else
          # Normal mode - just stop the simulator
          ios_stop
          rm -f "$state_dir/simulator-udid.txt" 2>/dev/null || true
        fi
        ;;
      ready)
        # Silent readiness probe: exit 0 if booted, 1 if not
        state_dir="$(ios_state_dir)"
        udid=""

        # Try state file first
        if [ -f "$state_dir/simulator-udid.txt" ]; then
          udid="$(cat "$state_dir/simulator-udid.txt")"
        fi

        # Fallback: find any booted simulator
        if [ -z "$udid" ]; then
          udid="$(xcrun simctl list devices -j | jq -r '.devices[]?[]? | select(.state == "Booted") | .udid' | head -n1 || true)"
        fi

        if [ -z "$udid" ]; then
          exit 1
        fi

        # Check if booted
        sim_state="$(xcrun simctl list devices -j | jq -r --arg udid "$udid" '.devices[]?[]? | select(.udid == $udid) | .state' | head -n1 || true)"
        if [ "$sim_state" = "Booted" ]; then
          exit 0
        fi
        exit 1
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
        echo "  All simulators stopped"
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
        echo "Reset complete!"
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
  deploy)
    # Install and launch app on already-running simulator (no build, no sim start)
    # shellcheck disable=SC1090
    . "${script_dir}/domain/deploy.sh"

    app_arg="${1:-}"

    state_dir="$(ios_state_dir)"

    # Resolve UDID from state file or find booted simulator
    udid=""
    if [ -f "$state_dir/simulator-udid.txt" ]; then
      udid="$(cat "$state_dir/simulator-udid.txt")"
    fi
    if [ -z "$udid" ]; then
      udid="$(xcrun simctl list devices -j | jq -r '.devices[]?[]? | select(.state == "Booted") | .udid' | head -n1 || true)"
    fi
    if [ -z "$udid" ]; then
      echo "ERROR: No booted simulator found. Run 'ios.sh simulator start' first." >&2
      exit 1
    fi

    # Resolve app path
    if [ -n "$app_arg" ]; then
      app_path="$app_arg"
      if [ "${app_path#/}" = "$app_path" ]; then
        app_path="$PWD/$app_path"
      fi
      if [ ! -d "$app_path" ]; then
        echo "ERROR: App bundle not found: $app_path" >&2
        exit 1
      fi
    else
      project_root="$(ios_resolve_project_root)"
      app_path="$(ios_find_app "$project_root" || true)"
      if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
        echo "ERROR: No .app bundle found. Build first with 'ios.sh build'." >&2
        exit 1
      fi
    fi

    echo "App: $(basename "$app_path")"

    # Extract bundle ID
    bundle_id="${IOS_XCODEBUILD_BUNDLE_ID:-}"
    if [ -z "$bundle_id" ]; then
      bundle_id="$(ios_extract_bundle_id "$app_path")"
    fi
    if [ -z "$bundle_id" ]; then
      echo "ERROR: Unable to resolve bundle identifier" >&2
      exit 1
    fi

    # Install and launch
    echo "Installing on simulator: $udid"
    xcrun simctl install "$udid" "$app_path"

    echo "Launching: $bundle_id"
    xcrun simctl launch "$udid" "$bundle_id"

    # Save state
    mkdir -p "$state_dir"
    echo "$bundle_id" > "$state_dir/bundle-id.txt"

    echo "Deploy complete"
    ;;
  app)
    sub="${1-}"
    shift || true

    state_dir="$(ios_state_dir)"

    case "$sub" in
      status)
        # Check if deployed app is running (exit 0 if running, 1 if not)
        bundle_id=""
        if [ -f "$state_dir/bundle-id.txt" ]; then
          bundle_id="$(cat "$state_dir/bundle-id.txt")"
        fi
        if [ -z "$bundle_id" ]; then
          exit 1
        fi

        udid=""
        if [ -f "$state_dir/simulator-udid.txt" ]; then
          udid="$(cat "$state_dir/simulator-udid.txt")"
        fi
        if [ -z "$udid" ]; then
          udid="$(xcrun simctl list devices -j | jq -r '.devices[]?[]? | select(.state == "Booted") | .udid' | head -n1 || true)"
        fi
        if [ -z "$udid" ]; then
          exit 1
        fi

        if xcrun simctl spawn "$udid" launchctl list 2>/dev/null | grep -q "$bundle_id"; then
          exit 0
        fi
        exit 1
        ;;
      stop)
        # Stop the deployed app
        bundle_id=""
        if [ -f "$state_dir/bundle-id.txt" ]; then
          bundle_id="$(cat "$state_dir/bundle-id.txt")"
        fi

        udid=""
        if [ -f "$state_dir/simulator-udid.txt" ]; then
          udid="$(cat "$state_dir/simulator-udid.txt")"
        fi
        if [ -z "$udid" ]; then
          udid="$(xcrun simctl list devices -j | jq -r '.devices[]?[]? | select(.state == "Booted") | .udid' | head -n1 || true)"
        fi

        if [ -n "$udid" ] && [ -n "$bundle_id" ]; then
          xcrun simctl terminate "$udid" "$bundle_id" 2>/dev/null || true
          echo "App stopped: $bundle_id"
        else
          echo "No app to stop"
        fi
        ;;
      *)
        echo "ERROR: Unknown app subcommand: $sub" >&2
        echo "Usage: ios.sh app <status|stop>" >&2
        exit 1
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
    xcodebuild "$@"
    ;;
  *)
    usage
    ;;
esac
