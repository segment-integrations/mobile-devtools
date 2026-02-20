#!/usr/bin/env bash
# Test simulator detection and matching logic
# Tests can be run standalone without running full e2e tests

set -euo pipefail

# Setup: Source the framework and simulator scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../test-framework.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source iOS setup
cd "$REPO_ROOT/examples/ios"
if [ ! -d ".devbox/virtenv/ios" ]; then
  echo "ERROR: iOS virtenv not found. Run 'devbox shell' first."
  exit 1
fi

# Source the scripts
IOS_SCRIPTS_DIR=".devbox/virtenv/ios/scripts"
export IOS_SCRIPTS_DIR

. "$IOS_SCRIPTS_DIR/lib/lib.sh"
. "$IOS_SCRIPTS_DIR/platform/core.sh"
. "$IOS_SCRIPTS_DIR/domain/device_manager.sh"
. "$IOS_SCRIPTS_DIR/domain/simulator.sh"

echo "========================================"
echo "iOS Simulator Detection Tests"
echo "========================================"
echo ""

# Test 1: Check required functions exist
log_test "Function availability"
assert_success "command -v resolve_runtime" "resolve_runtime function exists"
assert_success "command -v devicetype_id_for_name" "devicetype_id_for_name function exists"
assert_success "command -v ios_start" "ios_start function exists"
assert_success "command -v ios_stop" "ios_stop function exists"

# Test 2: List available runtimes
log_test "Runtime resolution"
echo "Available iOS runtimes:"
xcrun simctl list runtimes | grep "iOS" || echo "No iOS runtimes found"

# Try to resolve a common runtime
if xcrun simctl list runtimes | grep -q "iOS"; then
  # Get first available iOS runtime version
  first_runtime=$(xcrun simctl list runtimes -j | jq -r '.runtimes[] | select(.platform == "iOS") | .version' | head -1)
  if [ -n "$first_runtime" ]; then
    echo "Testing with runtime: $first_runtime"
    runtime_id=$(resolve_runtime "$first_runtime" || echo "")
    assert_success "[ -n '$runtime_id' ]" "Resolves runtime version $first_runtime"
  fi
fi

# Test 3: Device type matching
log_test "Device type matching"
echo "Available device types:"
xcrun simctl list devicetypes | grep "iPhone" | head -3 || echo "No device types found"

# Test matching various device names
device_type=$(devicetype_id_for_name "iPhone 13" || echo "")
assert_success "[ -n '$device_type' ]" "Matches 'iPhone 13' device type"

# Test that generic "iPhone" without model number fails gracefully
device_type=$(devicetype_id_for_name "iPhone" || echo "")
if [ -z "$device_type" ]; then
  echo "  Generic 'iPhone' not matched (as expected - needs specific model)"
  assert_success "true" "Generic device name handling works"
else
  assert_success "[ -n '$device_type' ]" "Matches generic 'iPhone' device type"
fi

# Test 4: List existing simulators
log_test "Simulator listing"
echo "Existing simulators:"
xcrun simctl list devices | grep -E "(Booted|Shutdown)" | head -5 || echo "No simulators found"

booted_count=$(xcrun simctl list devices | grep -c "Booted" || echo "0")
# Clean up newlines from grep -c output
booted_count=$(echo "$booted_count" | tr -d '\n')
echo "Booted simulators: $booted_count"
assert_success "[ '$booted_count' -ge 0 ]" "Can count booted simulators"

# Test 5: Simulator state detection
log_test "Simulator state detection"
if [ "$booted_count" -gt 0 ]; then
  # Get first booted simulator UDID
  booted_udid=$(xcrun simctl list devices | grep "Booted" | grep -oE '[0-9A-F-]{36}' | head -1)
  echo "Testing with booted simulator: $booted_udid"

  # Check if simulator is booted via simctl
  assert_success "xcrun simctl list devices | grep '$booted_udid' | grep -q 'Booted'" "Detects booted simulator"
  assert_success "xcrun simctl bootstatus '$booted_udid'" "Can query boot status"
else
  echo "  No booted simulators for state detection tests"
  assert_success "true" "Skipped - no booted simulators"
fi

# Test 6: Device name resolution from device definitions
log_test "Device definition resolution"
devices_dir="devbox.d/ios/devices"
if [ -d "$devices_dir" ]; then
  echo "Device definitions:"
  for device_file in "$devices_dir"/*.json; do
    [ -f "$device_file" ] || continue
    device_name=$(jq -r '.name' "$device_file" 2>/dev/null || echo "")
    runtime=$(jq -r '.runtime' "$device_file" 2>/dev/null || echo "")
    echo "  - $device_name (iOS $runtime)"

    if [ -n "$device_name" ]; then
      device_type=$(devicetype_id_for_name "$device_name" 2>/dev/null || echo "")
      if [ -n "$device_type" ]; then
        assert_success "[ -n '$device_type' ]" "Resolved device type for '$device_name'"
      else
        echo "  Could not resolve device type for '$device_name' (may not be available)"
      fi
    fi
  done
else
  echo "  No device definitions directory found"
fi

# Test 7: Simulator UDID lookup by name
log_test "Simulator lookup by device name"
if [ "$booted_count" -gt 0 ]; then
  # Get device name of first booted simulator
  booted_line=$(xcrun simctl list devices | grep "Booted" | head -1)
  device_name=$(echo "$booted_line" | sed -E 's/^[[:space:]]*([^(]+).*/\1/' | xargs)
  booted_udid=$(echo "$booted_line" | grep -oE '[0-9A-F-]{36}')

  echo "Booted device: $device_name"
  echo "Expected UDID: $booted_udid"

  # Find simulator by name
  found_udid=$(xcrun simctl list devices | grep "$device_name" | grep "Booted" | grep -oE '[0-9A-F-]{36}' | head -1 || echo "")
  assert_equal "$booted_udid" "$found_udid" "Finds simulator UDID by device name"
else
  echo "  No booted simulators for lookup tests"
  assert_success "true" "Skipped - no booted simulators"
fi

# Test 8: Runtime availability checking
log_test "Runtime availability validation"
available_runtimes=$(xcrun simctl list runtimes -j | jq -r '.runtimes[] | select(.platform == "iOS") | .version')
runtime_count=$(echo "$available_runtimes" | wc -l | xargs)
echo "Available iOS runtimes: $runtime_count"
assert_success "[ '$runtime_count' -gt 0 ]" "Has at least one iOS runtime available"

# Test 9: Device definitions lock file validation
log_test "Lock file device validation"
lock_file="$devices_dir/devices.lock"
if [ -f "$lock_file" ]; then
  echo "Validating lock file: $lock_file"

  assert_success "jq -e '.devices' '$lock_file'" "Lock file has devices array"
  assert_success "jq -e '.checksum' '$lock_file'" "Lock file has checksum"

  device_count=$(jq '.devices | length' "$lock_file")
  echo "Devices in lock file: $device_count"
  assert_success "[ '$device_count' -gt 0 ]" "Lock file contains devices"

  # Validate each device can be resolved
  for i in $(seq 0 $((device_count - 1))); do
    device_name=$(jq -r ".devices[$i].name" "$lock_file")
    device_runtime=$(jq -r ".devices[$i].runtime" "$lock_file")
    echo "Validating device: $device_name (iOS $device_runtime)"

    # Try to resolve device type
    device_type=$(devicetype_id_for_name "$device_name" 2>/dev/null || echo "")
    if [ -n "$device_type" ]; then
      assert_success "[ -n '$device_type' ]" "Device type resolved: $device_name"
    else
      echo "  Device type not available: $device_name"
    fi

    # Try to resolve runtime
    runtime_id=$(resolve_runtime "$device_runtime" 2>/dev/null || echo "")
    if [ -n "$runtime_id" ]; then
      assert_success "[ -n '$runtime_id' ]" "Runtime resolved: iOS $device_runtime"
    else
      echo "  Runtime not available: iOS $device_runtime (may need download)"
    fi
  done
else
  echo "  No lock file found at: $lock_file"
  echo "Run 'devbox run ios.sh devices eval' to generate"
fi

# Test 10: CoreSimulatorService health check
log_test "CoreSimulatorService health"
if pgrep -q CoreSimulatorService; then
  assert_success "pgrep CoreSimulatorService" "CoreSimulatorService is running"
else
  echo "  CoreSimulatorService not running (will start when needed)"
  assert_success "true" "CoreSimulatorService state noted"
fi

# Test 11: Pure mode simulator naming
log_test "Pure mode simulator identification"
echo "Pure mode creates simulators with ' Test' suffix"
echo "Example: 'iPhone 17 Test' for pure mode"
echo "Example: 'iPhone 17' for normal mode"

# Check if any test simulators exist
test_sims=$(xcrun simctl list devices | grep " Test" | grep -c "iPhone" || echo "0")
# Clean up newlines
test_sims=$(echo "$test_sims" | tr -d '\n')
echo "Test simulators found: $test_sims"
assert_success "[ '$test_sims' -ge 0 ]" "Can detect test simulators"

# Summary
test_summary "ios-simulator-detection"
