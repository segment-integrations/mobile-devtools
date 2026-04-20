#!/usr/bin/env sh
# Android Plugin - Emulator Lifecycle Management
# See SCRIPTS.md for detailed documentation

set -e

if ! (return 0 2>/dev/null); then
  echo "ERROR: emulator.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${ANDROID_EMULATOR_LOADED:-}" = "1" ] && [ "${ANDROID_EMULATOR_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_EMULATOR_LOADED=1
ANDROID_EMULATOR_LOADED_PID="$$"

# Source dependencies (Layer 1 & 2 only)
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ]; then
  . "${ANDROID_SCRIPTS_DIR}/lib/lib.sh"
  . "${ANDROID_SCRIPTS_DIR}/platform/core.sh"
  . "${ANDROID_SCRIPTS_DIR}/platform/device_config.sh"
fi

# NOTE: This script should NOT call android_setup_avds directly.
# Layer 4 (android.sh) is responsible for calling android_setup_avds BEFORE calling android_start_emulator.
# Layer 3 scripts must be independent of each other.

# Find a running emulator by AVD name
# Returns the serial (emulator-5554) if found, empty otherwise
# Serial is the standard adb identifier for emulators and is the best way
# to reference them in subsequent adb commands
android_find_running_emulator() {
  avd_name="$1"

  if ! command -v adb >/dev/null 2>&1; then
    return 1
  fi

  # First, ensure adb server is started and device list is fresh
  adb start-server >/dev/null 2>&1 || true

  # Check all running emulator serials (only those marked as 'device', not 'offline')
  for emulator_serial in $(adb devices | awk 'NR>1 && $1 ~ /^emulator-/ && $2=="device" {print $1}'); do
    # Query the AVD name from the emulator
    running_avd_name="$(adb -s "$emulator_serial" shell getprop ro.boot.qemu.avd_name 2>/dev/null | tr -d "\r")"

    if [ -n "$running_avd_name" ] && [ "$running_avd_name" = "$avd_name" ]; then
      # Double-check the emulator is responsive
      if adb -s "$emulator_serial" shell echo "ping" >/dev/null 2>&1; then
        printf '%s\n' "$emulator_serial"
        return 0
      fi
    fi
  done

  return 1
}

# List all running emulators with their AVD names
# Output format: serial:avd_name (e.g., emulator-5554:pixel_api30)
android_list_running_emulators() {
  if ! command -v adb >/dev/null 2>&1; then
    return 0
  fi

  adb start-server >/dev/null 2>&1 || true

  for emulator_serial in $(adb devices | awk 'NR>1 && $1 ~ /^emulator-/ && $2=="device" {print $1}'); do
    running_avd_name="$(adb -s "$emulator_serial" shell getprop ro.boot.qemu.avd_name 2>/dev/null | tr -d "\r")"
    if [ -n "$running_avd_name" ]; then
      printf '%s:%s\n' "$emulator_serial" "$running_avd_name"
    fi
  done
}

# Check if an emulator serial is running and responsive
android_is_emulator_running() {
  emulator_serial="$1"

  if ! command -v adb >/dev/null 2>&1; then
    return 1
  fi

  # Check if listed in adb devices
  if ! adb devices | awk 'NR>1 && $1 ~ /^emulator-/ && $2=="device" {print $1}' | grep -q "^${emulator_serial}$"; then
    return 1
  fi

  # Verify it's responsive
  if ! adb -s "$emulator_serial" shell echo "ping" >/dev/null 2>&1; then
    return 1
  fi

  return 0
}

# Find an available emulator port (even numbers: 5554, 5556, 5558, ...)
android_find_available_port() {
  starting_port="${1:-5554}"
  candidate_port="$starting_port"

  if ! command -v adb >/dev/null 2>&1; then
    printf '%s\n' "$candidate_port"
    return 0
  fi

  # Keep incrementing by 2 until we find an unused port
  while adb devices | awk 'NR>1 && $1=="emulator-'"$candidate_port"'"' | grep -q .; do
    candidate_port=$((candidate_port + 2))
  done

  printf '%s\n' "$candidate_port"
}

# Get the tracking file path for this project's emulators
# Stores in project-local virtenv directory for isolation between projects
android_get_emulator_tracking_file() {
  # Use ANDROID_USER_HOME (project-local virtenv) for tracking file
  tracking_dir="${ANDROID_USER_HOME:-${ANDROID_AVD_HOME:-$HOME/.android}}"
  printf '%s/emulators-started.txt\n' "$tracking_dir"
}

# Track an emulator serial as started by this project
android_track_emulator() {
  emulator_serial="$1"
  tracking_file="$(android_get_emulator_tracking_file)"
  # Add serial if not already tracked
  if [ ! -f "$tracking_file" ] || ! grep -qxF "$emulator_serial" "$tracking_file" 2>/dev/null; then
    echo "$emulator_serial" >> "$tracking_file"
  fi
}

# Check if an emulator serial is tracked by this project
android_is_tracked_emulator() {
  emulator_serial="$1"
  tracking_file="$(android_get_emulator_tracking_file)"
  [ -f "$tracking_file" ] && grep -qxF "$emulator_serial" "$tracking_file" 2>/dev/null
}

# Clean up offline emulator entries in adb (only for tracked emulators)
# Only kills emulators started by this project that are in "offline" state
android_cleanup_offline_emulators() {
  if ! command -v adb >/dev/null 2>&1; then
    return 0
  fi

  tracking_file="$(android_get_emulator_tracking_file)"
  if [ ! -f "$tracking_file" ]; then
    # No emulators tracked by this project
    return 0
  fi

  # Only kill emulators that are tracked by this project AND are offline
  adb devices | awk 'NR>1 && $2=="offline" {print $1}' | while read -r offline_serial; do
    if android_is_tracked_emulator "$offline_serial"; then
      echo "Cleaning up offline emulator: $offline_serial (tracked by this project)" >&2
      adb -s "$offline_serial" emu kill >/dev/null 2>&1 || true
      # Remove from tracking file
      sed -i.bak "/^${offline_serial}\$/d" "$tracking_file" 2>/dev/null || true
    fi
  done
}

# Start an Android emulator
android_start_emulator() {
  device_name="${1:-}"

  # Set device selection if provided
  if [ -n "$device_name" ]; then
    ANDROID_DEVICE_NAME="$device_name"
    export ANDROID_DEVICE_NAME
  fi

  # Configuration
  headless_mode="${EMU_HEADLESS:-}"
  preferred_port="${EMU_PORT:-5554}"
  avd_to_start=""

  # ---- Resolve AVD Name ----
  # NOTE: android_setup_avds() must be called by the caller (layer 4) BEFORE calling this function
  # It sets ANDROID_RESOLVED_AVD which we use here

  # Priority order: user-specified AVD > resolved AVD from setup > error
  if [ -n "${AVD_NAME:-}" ]; then
    avd_to_start="$AVD_NAME"
  elif [ -n "${ANDROID_RESOLVED_AVD:-}" ]; then
    avd_to_start="$ANDROID_RESOLVED_AVD"
  fi

  if [ -z "$avd_to_start" ]; then
    echo "ERROR: No AVD resolved" >&2
    echo "       Ensure android_setup_avds() was called first, or set AVD_NAME explicitly" >&2
    exit 1
  fi

  echo ""
  echo "Target AVD: $avd_to_start"

  # ---- Check if Already Running ----

  # In pure mode, always start a fresh instance
  pure_mode="${ANDROID_EMULATOR_PURE:-0}"
  if [ "$pure_mode" != "1" ]; then
    # Clean up offline emulators (skip if ANDROID_SKIP_CLEANUP=1 for multi-emulator scenarios)
    skip_cleanup="${ANDROID_SKIP_CLEANUP:-0}"
    if [ "$skip_cleanup" != "1" ]; then
      android_cleanup_offline_emulators
    fi

    existing_serial="$(android_find_running_emulator "$avd_to_start" 2>/dev/null || true)"
    if [ -n "$existing_serial" ]; then
      ANDROID_EMULATOR_SERIAL="$existing_serial"
      export ANDROID_EMULATOR_SERIAL

      # Extract port from serial (emulator-5554 -> 5554)
      EMU_PORT="${existing_serial#emulator-}"
      export EMU_PORT

      echo "Android emulator already running: ${existing_serial} (${avd_to_start})"
      return 0
    fi
  else
    echo "Pure mode: Starting fresh emulator with clean state..."
  fi

  # ---- Find Available Port ----

  available_port="$(android_find_available_port "$preferred_port")"
  emulator_serial="emulator-${available_port}"

  ANDROID_EMULATOR_SERIAL="$emulator_serial"
  EMU_PORT="$available_port"
  export ANDROID_EMULATOR_SERIAL EMU_PORT

  # Persist serial so readiness probes can find it (survives foreground blocking)
  _emu_runtime_dir="${ANDROID_RUNTIME_DIR:-${ANDROID_USER_HOME:-}}"
  if [ -n "$_emu_runtime_dir" ]; then
    mkdir -p "$_emu_runtime_dir"
    echo "$emulator_serial" > "$_emu_runtime_dir/emulator-serial.txt"
    # Also write to suite-namespaced path if SUITE_NAME is set
    if [ -n "${SUITE_NAME:-}" ]; then
      mkdir -p "$_emu_runtime_dir/$SUITE_NAME"
      echo "$emulator_serial" > "$_emu_runtime_dir/$SUITE_NAME/emulator-serial.txt"
    fi
  fi

  # ---- Start Emulator ----

  echo ""
  echo "Starting Android emulator:"
  echo "  AVD: $avd_to_start"
  echo "  Port: $available_port"
  echo "  Serial: $emulator_serial"
  echo "  Headless: ${headless_mode:-no}"

  # Build emulator command
  emulator_flags="-port $available_port"
  emulator_flags="$emulator_flags -gpu swiftshader_indirect"
  emulator_flags="$emulator_flags -noaudio"
  emulator_flags="$emulator_flags -no-boot-anim"
  emulator_flags="$emulator_flags -camera-back none"
  emulator_flags="$emulator_flags -accel on"

  # Pure mode: wipe data for clean state
  # Also disable snapshots in pure mode to avoid conflicts with -wipe-data
  if [ "$pure_mode" = "1" ]; then
    emulator_flags="$emulator_flags -wipe-data"
    emulator_flags="$emulator_flags -no-snapshot-save"
    emulator_flags="$emulator_flags -no-snapshot-load"
  fi

  # Snapshot configuration - default to enabled for fast boots (5-10s vs 2-5min)
  # Set ANDROID_DISABLE_SNAPSHOTS=1 to force cold boots (needed for writable-system)
  disable_snapshots="${ANDROID_DISABLE_SNAPSHOTS:-0}"
  if [ "$disable_snapshots" = "1" ]; then
    emulator_flags="$emulator_flags -writable-system"
    emulator_flags="$emulator_flags -no-snapshot-save"
    emulator_flags="$emulator_flags -no-snapshot-load"
  fi

  if [ -n "$headless_mode" ]; then
    emulator_flags="$emulator_flags -no-window"
  fi

  # Start emulator in background, fully detached from parent shell/session
  # Using setsid creates a new session, preventing termination signals from parent
  # Log output to project-local reports directory
  if [ -n "${TEST_LOGS_DIR:-}" ]; then
    mkdir -p "${TEST_LOGS_DIR}"
    emulator_log="${TEST_LOGS_DIR}/emulator-${avd_to_start}.log"
  elif [ -n "${REPORTS_DIR:-}" ]; then
    mkdir -p "${REPORTS_DIR}/logs"
    emulator_log="${REPORTS_DIR}/logs/emulator-${avd_to_start}.log"
  else
    # Fallback to project-local reports directory
    mkdir -p "reports/logs"
    emulator_log="reports/logs/emulator-${avd_to_start}.log"
  fi

  # Check if we should run in foreground (for process-compose monitoring)
  if [ "${ANDROID_EMULATOR_FOREGROUND:-0}" = "1" ]; then
    # Run emulator in foreground - process-compose will monitor it
    # No need to wait for boot - readiness probe handles that
    echo "  Running in foreground mode (monitored by process-compose)"
    echo "  Log: $emulator_log"
    echo "  Flags: $emulator_flags"
    echo ""
    echo "Running command: emulator -avd $avd_to_start $emulator_flags"
    echo ""

    # Track this emulator as started by this project
    android_track_emulator "$emulator_serial"

    # Run emulator in foreground - this blocks until emulator exits
    # Don't use exec - just run it normally so the script doesn't get replaced
    # In foreground mode for process-compose, don't redirect output - let process-compose handle logging
    # shellcheck disable=SC2086
    emulator -avd "$avd_to_start" $emulator_flags
    emulator_exit=$?

    echo "Emulator exited with code: $emulator_exit"

    # Clean up tracking when emulator exits
    tracking_file="$(android_get_emulator_tracking_file)"
    sed -i.bak "/^${emulator_serial}\$/d" "$tracking_file" 2>/dev/null || true

    return $emulator_exit
  fi

  # Background mode: detach emulator from parent shell/session
  # Use setsid to create a new session and fully detach the emulator
  # shellcheck disable=SC2086
  if command -v setsid >/dev/null 2>&1; then
    setsid emulator -avd "$avd_to_start" $emulator_flags >"$emulator_log" 2>&1 &
  else
    # Fallback to nohup if setsid not available
    nohup emulator -avd "$avd_to_start" $emulator_flags >"$emulator_log" 2>&1 &
  fi
  emulator_pid="$!"
  echo "  Log: $emulator_log"

  EMULATOR_PID="$emulator_pid"
  export EMULATOR_PID

  echo "  PID: $emulator_pid"

  # ---- Wait for Device ----

  echo ""
  echo "Waiting for emulator to be ready..."

  if ! command -v adb >/dev/null 2>&1; then
    echo "WARNING: adb not found, cannot verify emulator status" >&2
    return 0
  fi

  # Wait for device with timeout
  device_wait_seconds=0
  device_max_wait=180  # 3 minutes
  echo "Waiting for device to appear (max ${device_max_wait}s)..."
  while ! adb -s "$emulator_serial" get-state >/dev/null 2>&1; do
    if [ "$device_wait_seconds" -ge "$device_max_wait" ]; then
      echo "ERROR: Device $emulator_serial did not appear after ${device_max_wait}s" >&2
      return 1
    fi
    sleep 2
    device_wait_seconds=$((device_wait_seconds + 2))
  done
  echo "Device $emulator_serial detected"

  # ---- Wait for Boot Completion ----

  echo "Waiting for boot to complete..."

  boot_completed=""
  max_wait_seconds=300  # 5 minutes
  elapsed_seconds=0

  until [ "$boot_completed" = "1" ]; do
    boot_completed=$(adb -s "$emulator_serial" shell getprop sys.boot_completed 2>/dev/null | tr -d "\r")

    if [ "$elapsed_seconds" -ge "$max_wait_seconds" ]; then
      echo "WARNING: Boot timeout after ${max_wait_seconds}s, continuing anyway" >&2
      break
    fi

    sleep 5
    elapsed_seconds=$((elapsed_seconds + 5))
  done

  # ---- Optimize for Testing ----

  echo "Disabling animations for faster testing..."

  adb -s "$emulator_serial" shell settings put global window_animation_scale 0 2>/dev/null || true
  adb -s "$emulator_serial" shell settings put global transition_animation_scale 0 2>/dev/null || true
  adb -s "$emulator_serial" shell settings put global animator_duration_scale 0 2>/dev/null || true

  echo ""
  echo "✓ Emulator ready: $emulator_serial"

  # Write serial to runtime directory for scripts to read
  runtime_dir="${ANDROID_RUNTIME_DIR:-${ANDROID_USER_HOME:-}}"
  if [ -n "$runtime_dir" ]; then
    mkdir -p "$runtime_dir"
    echo "$emulator_serial" > "$runtime_dir/emulator-serial.txt"
  fi

  # Track this emulator as started by this project
  android_track_emulator "$emulator_serial"
}

# Run emulator as a service (blocks until stopped)
android_run_emulator_service() {
  device_name="${1:-}"

  # Start the emulator
  android_start_emulator "$device_name"

  # Setup signal handler to stop emulator on interrupt
  trap 'android_stop_emulator; exit 0' INT TERM

  echo ""
  echo "Emulator running in service mode"
  echo "Press Ctrl+C to stop"
  echo ""

  # Keep running while emulator process is alive
  if [ -n "${EMULATOR_PID:-}" ]; then
    while kill -0 "$EMULATOR_PID" 2>/dev/null; do
      sleep 5
    done
    echo "Emulator process ended"
  else
    # If we don't have PID, just sleep forever
    while true; do
      sleep 5
    done
  fi
}

# Stop all running Android emulators started by this project
# Only stops emulators tracked in this project's tracking file
android_stop_emulator() {
  echo "Stopping Android emulators..."

  # Clean up offline entries first
  android_cleanup_offline_emulators

  tracking_file="$(android_get_emulator_tracking_file)"

  if [ ! -f "$tracking_file" ]; then
    echo "No emulators tracked by this project"
    return 0
  fi

  if ! command -v adb >/dev/null 2>&1; then
    echo "WARNING: adb not found, cannot stop emulators gracefully" >&2
    return 1
  fi

  # Get list of tracked emulators that are still running
  stopped_any=0
  while read -r tracked_serial; do
    # Check if this emulator is still running
    if adb devices | awk 'NR>1 {print $1}' | grep -qxF "$tracked_serial"; then
      echo "Stopping emulator: $tracked_serial"
      adb -s "$tracked_serial" emu kill >/dev/null 2>&1 || true
      stopped_any=1
    fi
  done < "$tracking_file"

  # Clear the tracking file
  > "$tracking_file"

  if [ "$stopped_any" -eq 0 ]; then
    echo "No running emulators found"
  else
    echo "✓ Emulators stopped"
  fi
}

# Check if the emulator is ready (boot completed)
# Returns 0 if emulator is booted, 1 otherwise
# Used by android.sh emulator start --wait-ready
android_emulator_ready() {
  # Resolve serial from state directory (suite-namespaced)
  _suite="${SUITE_NAME:-default}"
  _runtime_dir="${ANDROID_RUNTIME_DIR:-${ANDROID_USER_HOME:-}}"
  if [ -z "$_runtime_dir" ]; then
    _runtime_dir="${PWD}/.devbox/virtenv"
  fi
  _state_dir="$_runtime_dir/$_suite"

  _serial=""
  if [ -f "$_state_dir/emulator-serial.txt" ]; then
    _serial="$(cat "$_state_dir/emulator-serial.txt")"
  fi

  if [ -z "$_serial" ]; then
    return 1
  fi

  if adb -s "$_serial" shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; then
    return 0
  fi
  return 1
}
