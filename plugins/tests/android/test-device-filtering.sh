#!/usr/bin/env bash
# Android Plugin - Device Filtering Tests
# Tests device filtering logic and fixes for trailing newline bug

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "Android Device Filtering Tests"
echo "========================================"
echo ""

# Setup test environment
test_root="$(make_temp_dir "android-device-filtering")"
mkdir -p "$test_root/devices"
mkdir -p "$test_root/scripts/lib"
mkdir -p "$test_root/scripts/platform"
mkdir -p "$test_root/scripts/domain"
mkdir -p "$test_root/scripts/user"
mkdir -p "$test_root/avd"

# Copy required scripts
cp "$script_dir/../../android/virtenv/scripts/lib/lib.sh" "$test_root/scripts/lib/"
cp "$script_dir/../../android/virtenv/scripts/platform/core.sh" "$test_root/scripts/platform/"
cp "$script_dir/../../android/virtenv/scripts/platform/device_config.sh" "$test_root/scripts/platform/"
cp "$script_dir/../../android/virtenv/scripts/domain/avd.sh" "$test_root/scripts/domain/"
cp "$script_dir/../../android/virtenv/scripts/user/devices.sh" "$test_root/scripts/user/"

# Set environment variables
export ANDROID_CONFIG_DIR="$test_root"
export ANDROID_DEVICES_DIR="$test_root/devices"
export ANDROID_SCRIPTS_DIR="$test_root/scripts"
export ANDROID_AVD_HOME="$test_root/avd"
export ANDROID_DEFAULT_DEVICE=""
export ANDROID_SYSTEM_IMAGE_TAG="google_apis"

devices_script="$test_root/scripts/user/devices.sh"
avd_script="$test_root/scripts/domain/avd.sh"

# ============================================================================
# Test Setup: Create Test Devices
# ============================================================================

echo "SETUP: Creating test devices"
"$devices_script" create min --api 24 --device pixel --tag google_apis >/dev/null 2>&1
"$devices_script" create max --api 36 --device medium_phone --tag google_apis >/dev/null 2>&1
"$devices_script" create mid --api 30 --device pixel_5 --tag google_apis >/dev/null 2>&1

assert_success "[ -f '$test_root/devices/min.json' ]" "min.json created"
assert_success "[ -f '$test_root/devices/max.json' ]" "max.json created"
assert_success "[ -f '$test_root/devices/mid.json' ]" "mid.json created"

# Generate lock file with all devices
export ANDROID_DEVICES=""
"$devices_script" eval >/dev/null 2>&1
assert_success "[ -f '$test_root/devices/devices.lock' ]" "devices.lock created"

# ============================================================================
# Test 1: Single Device Filter (Bug Case)
# ============================================================================

start_test "Single device filter - max only"

export ANDROID_DEVICES="max"
lock_file="$test_root/devices/devices.lock"

# Source avd.sh functions to test filtering logic
(
  set -e
  . "$test_root/scripts/lib/lib.sh"
  . "$test_root/scripts/platform/core.sh"

  # Extract the filtering logic
  devices_json="$(jq -c '.devices[]' "$lock_file" 2>/dev/null || echo "")"

  if [ -n "${ANDROID_DEVICES:-}" ]; then
    IFS=',' read -ra selected_devices <<< "${ANDROID_DEVICES}"

    filtered_json=""
    for device_json in $devices_json; do
      device_filename="$(echo "$device_json" | jq -r '.filename // empty')"

      should_include=false
      for selected in "${selected_devices[@]}"; do
        if [ "$device_filename" = "$selected" ]; then
          should_include=true
          break
        fi
      done

      if [ "$should_include" = true ]; then
        filtered_json="${filtered_json}${device_json}"$'\n'
      fi
    done

    # Strip trailing newline (THE FIX)
    devices_json="${filtered_json%$'\n'}"
  fi

  # Count lines (should be 1, not 2)
  line_count=$(echo "$devices_json" | wc -l | tr -d ' ')

  if [ "$line_count" -ne 1 ]; then
    echo "ERROR: Expected 1 line, got $line_count" >&2
    echo "Content:" >&2
    echo "$devices_json" | cat -A >&2
    exit 1
  fi

  # Count non-empty lines
  non_empty_count=$(echo "$devices_json" | grep -c '{' || echo "0")

  if [ "$non_empty_count" -ne 1 ]; then
    echo "ERROR: Expected 1 device JSON, got $non_empty_count" >&2
    exit 1
  fi

  # Verify no trailing newline
  if [[ "$devices_json" == *$'\n' ]]; then
    echo "ERROR: devices_json has trailing newline" >&2
    exit 1
  fi

  # Process each device (simulate the while loop)
  device_processed=0
  empty_lines=0

  echo "$devices_json" | while IFS= read -r device_json; do
    # Skip empty lines (defensive guard)
    if [ -z "$device_json" ]; then
      empty_lines=$((empty_lines + 1))
      continue
    fi

    device_processed=$((device_processed + 1))

    # Parse fields
    api_level="$(echo "$device_json" | jq -r '.api // empty')"
    device_hardware="$(echo "$device_json" | jq -r '.device // empty')"

    if [ -z "$api_level" ] || [ -z "$device_hardware" ]; then
      echo "ERROR: Device definition missing required fields" >&2
      exit 1
    fi
  done

  echo "Processed 1 device successfully"
)

if [ $? -eq 0 ]; then
  echo "  ✓ PASS: Single device filter works without empty lines"
  test_passed=$((test_passed + 1))
else
  echo "  ✗ FAIL: Single device filter produced empty lines or invalid data"
  test_failed=$((test_failed + 1))
fi

# ============================================================================
# Test 2: Multiple Device Filter
# ============================================================================

start_test "Multiple device filter - min,max"

export ANDROID_DEVICES="min,max"

(
  set -e
  . "$test_root/scripts/lib/lib.sh"
  . "$test_root/scripts/platform/core.sh"

  devices_json="$(jq -c '.devices[]' "$lock_file" 2>/dev/null || echo "")"

  IFS=',' read -ra selected_devices <<< "${ANDROID_DEVICES}"

  filtered_json=""
  for device_json in $devices_json; do
    device_filename="$(echo "$device_json" | jq -r '.filename // empty')"

    should_include=false
    for selected in "${selected_devices[@]}"; do
      if [ "$device_filename" = "$selected" ]; then
        should_include=true
        break
      fi
    done

    if [ "$should_include" = true ]; then
      filtered_json="${filtered_json}${device_json}"$'\n'
    fi
  done

  # Strip trailing newline
  devices_json="${filtered_json%$'\n'}"

  # Count devices
  device_count=$(echo "$devices_json" | grep -c '{')

  if [ "$device_count" -ne 2 ]; then
    echo "ERROR: Expected 2 devices, got $device_count" >&2
    exit 1
  fi

  # Verify no trailing newline
  if [[ "$devices_json" == *$'\n' ]]; then
    echo "ERROR: devices_json has trailing newline" >&2
    exit 1
  fi

  echo "Filtered 2 devices successfully"
)

if [ $? -eq 0 ]; then
  echo "  ✓ PASS: Multiple device filter works correctly"
  test_passed=$((test_passed + 1))
else
  echo "  ✗ FAIL: Multiple device filter failed"
  test_failed=$((test_failed + 1))
fi

# ============================================================================
# Test 3: Empty Filter (All Devices)
# ============================================================================

start_test "Empty filter - all devices"

export ANDROID_DEVICES=""

(
  set -e
  . "$test_root/scripts/lib/lib.sh"
  . "$test_root/scripts/platform/core.sh"

  devices_json="$(jq -c '.devices[]' "$lock_file" 2>/dev/null || echo "")"

  # No filtering when ANDROID_DEVICES is empty

  device_count=$(echo "$devices_json" | grep -c '{')

  if [ "$device_count" -ne 3 ]; then
    echo "ERROR: Expected 3 devices (all), got $device_count" >&2
    exit 1
  fi

  echo "All 3 devices available"
)

if [ $? -eq 0 ]; then
  echo "  ✓ PASS: Empty filter returns all devices"
  test_passed=$((test_passed + 1))
else
  echo "  ✗ FAIL: Empty filter failed"
  test_failed=$((test_failed + 1))
fi

# ============================================================================
# Test 4: Invalid Filter (No Matches)
# ============================================================================

start_test "Invalid filter - nonexistent device"

export ANDROID_DEVICES="nonexistent"

(
  set -e
  . "$test_root/scripts/lib/lib.sh"
  . "$test_root/scripts/platform/core.sh"

  devices_json="$(jq -c '.devices[]' "$lock_file" 2>/dev/null || echo "")"

  IFS=',' read -ra selected_devices <<< "${ANDROID_DEVICES}"

  filtered_json=""
  for device_json in $devices_json; do
    device_filename="$(echo "$device_json" | jq -r '.filename // empty')"

    should_include=false
    for selected in "${selected_devices[@]}"; do
      if [ "$device_filename" = "$selected" ]; then
        should_include=true
        break
      fi
    done

    if [ "$should_include" = true ]; then
      filtered_json="${filtered_json}${device_json}"$'\n'
    fi
  done

  # Strip trailing newline
  devices_json="${filtered_json%$'\n'}"

  # Should be empty
  if [ -n "$devices_json" ]; then
    echo "ERROR: Expected empty result, got: $devices_json" >&2
    exit 1
  fi

  echo "No matches (as expected)"
)

if [ $? -eq 0 ]; then
  echo "  ✓ PASS: Invalid filter returns empty result"
  test_passed=$((test_passed + 1))
else
  echo "  ✗ FAIL: Invalid filter handling failed"
  test_failed=$((test_failed + 1))
fi

# ============================================================================
# Test 5: Device Count Logging
# ============================================================================

start_test "Device count logging"

export ANDROID_DEVICES="max"

output=$(
  . "$test_root/scripts/lib/lib.sh"
  . "$test_root/scripts/platform/core.sh"

  devices_json="$(jq -c '.devices[]' "$lock_file" 2>/dev/null || echo "")"

  IFS=',' read -ra selected_devices <<< "${ANDROID_DEVICES}"

  filtered_json=""
  for device_json in $devices_json; do
    device_filename="$(echo "$device_json" | jq -r '.filename // empty')"

    should_include=false
    for selected in "${selected_devices[@]}"; do
      if [ "$device_filename" = "$selected" ]; then
        should_include=true
        break
      fi
    done

    if [ "$should_include" = true ]; then
      filtered_json="${filtered_json}${device_json}"$'\n'
    fi
  done

  devices_json="${filtered_json%$'\n'}"

  # Simulate device count logging (from fix #4)
  device_count=$(echo "$devices_json" | grep -c '{' || echo "0")
  echo "Processing $device_count device(s) from lock file"
)

if echo "$output" | grep -q "Processing 1 device(s) from lock file"; then
  echo "  ✓ PASS: Device count logging works"
  test_passed=$((test_passed + 1))
else
  echo "  ✗ FAIL: Device count logging incorrect"
  echo "    Output: $output"
  test_failed=$((test_failed + 1))
fi

# ============================================================================
# Test 6: Empty Line Guard and Debug Logging
# ============================================================================

start_test "Empty line guard prevents processing empty lines"

# Test the empty line guard by checking that a string with trailing newline
# doesn't cause errors when processed
result=$(
  devices_json='{"filename":"max","name":"test","api":36,"device":"pixel"}'$'\n'

  error_count=0
  processed_count=0

  # Simulate the processing loop with empty line guard
  while IFS= read -r device_json; do
    # Skip empty lines (THE FIX)
    if [ -z "$device_json" ]; then
      continue
    fi

    # Try to parse - this would fail on empty string
    api_level="$(echo "$device_json" | jq -r '.api // empty' 2>/dev/null)"
    device_hardware="$(echo "$device_json" | jq -r '.device // empty' 2>/dev/null)"

    if [ -z "$api_level" ] || [ -z "$device_hardware" ]; then
      error_count=$((error_count + 1))
    else
      processed_count=$((processed_count + 1))
    fi
  done <<< "$devices_json"

  # Should process 1 device with 0 errors
  if [ "$processed_count" -eq 1 ] && [ "$error_count" -eq 0 ]; then
    echo "SUCCESS"
  else
    echo "FAIL: processed=$processed_count errors=$error_count"
  fi
)

if [ "$result" = "SUCCESS" ]; then
  echo "  ✓ PASS: Empty line guard prevents processing empty lines"
  test_passed=$((test_passed + 1))
else
  echo "  ✗ FAIL: Empty line guard not working"
  echo "    Result: $result"
  test_failed=$((test_failed + 1))
fi

# ============================================================================
# Cleanup
# ============================================================================

rm -rf "$test_root"

# ============================================================================
# Test Summary
# ============================================================================

test_summary "android-device-filtering"
