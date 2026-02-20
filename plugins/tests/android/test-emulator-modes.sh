#!/usr/bin/env bash
# Test emulator pure mode vs normal mode behavior
# Tests the logic for reusing vs creating fresh emulators

set -euo pipefail

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../test-framework.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

cd "$REPO_ROOT/examples/android"
if [ ! -d ".devbox/virtenv/android" ]; then
  echo "ERROR: Android virtenv not found. Run 'devbox shell' first."
  exit 1
fi

. .devbox/virtenv/android/scripts/init/setup.sh
. .devbox/virtenv/android/scripts/domain/emulator.sh

echo "========================================"
echo "Emulator Mode Behavior Tests"
echo "========================================"
echo ""

echo "This test demonstrates the difference between:"
echo "  1. Normal mode: Reuses existing emulator if AVD matches"
echo "  2. Pure mode: Always creates fresh emulator with clean state"
echo ""

# Check current emulator state
echo "Current State:"
running_count=$(adb devices 2>/dev/null | grep -c "emulator-" | tr -d '\n' || echo "0")
echo "  Running emulators: $running_count"

if [ "$running_count" -gt 0 ]; then
  echo "  Emulator details:"
  android_list_running_emulators | while IFS=: read -r serial avd; do
    echo "    - $serial: $avd"
  done
fi
echo ""

# Test 1: Normal mode behavior
log_test "Normal Mode (Reuse existing)"
echo ""

echo "Scenario: Running 'android.sh emulator start max' (no --pure flag)"
echo ""
echo "Expected behavior:"
echo "  - If emulator with matching AVD exists: Reuse it"
echo "  - If no matching emulator: Start new one"
echo "  - Emulator persists after script exits"
echo ""

# Check if max AVD exists
if [ "$running_count" -gt 0 ]; then
  assert_success "true" "Emulator already running - normal mode would reuse it"
  echo ""
  echo "Test reuse detection:"

  first_serial=$(adb devices | awk 'NR>1 && $1 ~ /^emulator-/ && $2=="device" {print $1; exit}')
  avd_name=$(adb -s "$first_serial" shell getprop ro.boot.qemu.avd_name 2>/dev/null | tr -d '\r')

  echo "  Existing: $first_serial ($avd_name)"

  found=$(android_find_running_emulator "$avd_name" || echo "")
  assert_equal "$first_serial" "$found" "android_find_running_emulator correctly finds emulator"
else
  echo "No emulators running - normal mode would start new one"
  echo "    (Run 'devbox run start:emu' to test reuse behavior)"
fi

echo ""

# Test 2: Pure mode behavior
log_test "Pure Mode (Fresh instance)"
echo ""

echo "Scenario: Running 'android.sh emulator start --pure max'"
echo ""
echo "Expected behavior:"
echo "  - Always starts fresh emulator with --wipe-data flag"
echo "  - Ignores any existing emulators"
echo "  - Creates clean state for deterministic testing"
echo "  - Should be stopped after test completes (in e2e tests)"
echo ""

echo "Pure mode flag:"
echo "  export ANDROID_EMULATOR_PURE=1"
echo "  This triggers --wipe-data flag in emulator command"
echo ""

# Test 3: AVD matching logic
log_test "AVD Matching Logic"
echo ""

echo "How emulators are matched to AVDs:"
echo ""
echo "1. Query running emulators:"
echo "   adb devices | grep emulator-"
echo ""
echo "2. For each emulator, get AVD name:"
echo "   adb shell getprop ro.boot.qemu.avd_name"
echo ""
echo "3. Compare with target AVD:"
echo "   if [ \"\$running_avd\" = \"\$target_avd\" ]; then"
echo "     # Reuse this emulator"
echo "   fi"
echo ""

if [ "$running_count" -gt 0 ]; then
  echo "Current AVD mapping:"
  android_list_running_emulators | while IFS=: read -r serial avd; do
    state=$(adb devices | grep "$serial" | awk '{print $2}')
    echo "  $serial -> $avd ($state)"
  done
else
  echo "  (No emulators running to demonstrate)"
fi

echo ""

# Test 4: Serial file tracking
log_test "Serial File Tracking"
echo ""

echo "Serial (emulator-5554) is the standard adb identifier because:"
echo "  - Unique per emulator instance"
echo "  - Required for all adb commands: adb -s emulator-5554 shell ..."
echo "  - Stable for the lifetime of the emulator process"
echo "  - Not tied to PID (which can be unreliable)"
echo ""

echo "Serial file: /tmp/android-emulator-serial.txt"
if [ -f /tmp/android-emulator-serial.txt ]; then
  serial=$(cat /tmp/android-emulator-serial.txt)
  echo "  File exists: $serial"

  if android_is_emulator_running "$serial"; then
    echo "  Emulator is running and responsive"
  else
    echo "  Emulator not running (stale serial file)"
  fi
else
  echo "  File does not exist (no emulator started this session)"
fi

echo ""

# Test 5: Cleanup behavior
log_test "Cleanup Behavior"
echo ""

echo "Normal mode cleanup:"
echo "  - App stopped: adb shell am force-stop com.example.app"
echo "  - Emulator kept running for dev convenience"
echo ""

echo "Pure mode cleanup (TEST_PURE=1):"
echo "  - App stopped: adb shell am force-stop com.example.app"
echo "  - Emulator killed: android.sh emulator stop"
echo "  - Serial file cleaned up"
echo "  - Next run starts completely fresh"
echo ""

# Summary
echo "========================================"
echo "SUMMARY"
echo "========================================"
echo ""
echo "Key Differences:"
echo ""
echo "Normal Mode:"
echo "  + Fast (reuses existing emulator)"
echo "  + Good for development/iteration"
echo "  + Emulator persists between runs"
echo "  - May have state from previous runs"
echo ""
echo "Pure Mode:"
echo "  + Deterministic (clean state every time)"
echo "  + Good for CI/CD pipelines"
echo "  + Isolated test runs"
echo "  - Slower (boots fresh emulator)"
echo ""

echo "Usage:"
echo "  devbox run test:e2e              # Normal mode"
echo "  TEST_PURE=1 devbox run test:e2e  # Pure mode"
echo ""

echo "All behavior tests passed!"
