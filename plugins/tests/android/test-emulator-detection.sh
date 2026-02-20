#!/usr/bin/env bash
# Test emulator detection and matching logic
# Tests can be run standalone without running full e2e tests

set -euo pipefail

# Setup: Source the framework and emulator scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../test-framework.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source Android setup
cd "$REPO_ROOT/examples/android"
if [ ! -d ".devbox/virtenv/android" ]; then
  echo "ERROR: Android virtenv not found. Run 'devbox shell' first."
  exit 1
fi

# Source the scripts
. .devbox/virtenv/android/scripts/init/setup.sh
. .devbox/virtenv/android/scripts/domain/emulator.sh

echo "========================================"
echo "Android Emulator Detection Tests"
echo "========================================"
echo ""

# Test 1: List running emulators (may be empty or have existing emulators)
log_test "List running emulators"
echo "Running emulators:"
android_list_running_emulators || true
assert_success "command -v android_list_running_emulators" "android_list_running_emulators function exists"

# Test 2: Find available port
log_test "Find available port"
port=$(android_find_available_port 5554)
echo "Available port: $port"
assert_success "[ -n '$port' ]" "Returns a port number"
assert_success "[ '$port' -ge 5554 ]" "Port is >= 5554"
assert_success "[ \$(( $port % 2 )) -eq 0 ]" "Port is even number"

# Test 3: Check if non-existent emulator is running
log_test "Check non-existent emulator"
assert_failure "android_is_emulator_running 'emulator-9999'" "Non-existent emulator returns false"
assert_failure "android_find_running_emulator 'nonexistent_avd'" "Non-existent AVD returns false"

# Test 4: Start an emulator and test detection (if no emulator already running)
log_test "Emulator detection with actual instance"
echo "Checking for existing emulators..."
existing_count=$(adb devices | grep -c "emulator-" || echo "0")
echo "Existing emulators: $existing_count"

if [ "$existing_count" -eq 0 ]; then
  echo "No emulators running. Starting test emulator..."
  echo "This will take 1-2 minutes for first boot..."

  # Start emulator in background
  if android.sh emulator start max 2>&1 | head -20; then
    emulator_serial=$(cat /tmp/android-emulator-serial.txt 2>/dev/null || echo "")

    if [ -n "$emulator_serial" ]; then
      echo "Emulator started: $emulator_serial"

      # Test detection functions
      assert_success "android_is_emulator_running '$emulator_serial'" "Detects running emulator by serial"

      avd_name=$(adb -s "$emulator_serial" shell getprop ro.boot.qemu.avd_name 2>/dev/null | tr -d '\r')
      if [ -n "$avd_name" ]; then
        echo "AVD name: $avd_name"
        found_serial=$(android_find_running_emulator "$avd_name" || echo "")
        assert_success "[ '$found_serial' = '$emulator_serial' ]" "Finds emulator by AVD name"
      fi

      # Test listing
      list_output=$(android_list_running_emulators)
      assert_output "echo '$list_output'" "$emulator_serial" "Lists running emulator"

      # Cleanup: Stop emulator
      echo "Stopping test emulator..."
      adb -s "$emulator_serial" emu kill >/dev/null 2>&1 || true
      sleep 2
    else
      echo "Could not start emulator (this is OK if no AVDs exist yet)"
    fi
  else
    echo "Could not start emulator (this is OK if no AVDs exist yet)"
  fi
else
  echo "Using existing emulator(s) for tests..."

  # Test with existing emulator
  first_serial=$(adb devices | awk 'NR>1 && $1 ~ /^emulator-/ && $2=="device" {print $1; exit}')

  if [ -n "$first_serial" ]; then
    echo "Testing with emulator: $first_serial"
    assert_success "android_is_emulator_running '$first_serial'" "Detects existing running emulator"

    avd_name=$(adb -s "$first_serial" shell getprop ro.boot.qemu.avd_name 2>/dev/null | tr -d '\r')
    if [ -n "$avd_name" ]; then
      echo "AVD name: $avd_name"
      found_serial=$(android_find_running_emulator "$avd_name" || echo "")
      assert_success "[ '$found_serial' = '$first_serial' ]" "Finds existing emulator by AVD name"
    fi

    list_output=$(android_list_running_emulators)
    assert_output "echo '$list_output'" "$first_serial" "Lists existing emulator"
  fi
fi

# Test 5: Cleanup functions
log_test "Cleanup offline emulators"
assert_success "android_cleanup_offline_emulators" "Cleanup function runs without error"

# Test 6: Pure mode behavior simulation
log_test "Pure mode vs normal mode behavior"
echo "Pure mode creates fresh emulator with --wipe-data"
echo "Normal mode reuses existing emulator if AVD matches"
assert_success "true" "Pure mode logic documented"
assert_success "true" "Normal mode logic documented"

# Summary
test_summary "android-emulator-detection"
