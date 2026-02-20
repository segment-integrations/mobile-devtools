#!/usr/bin/env bash
# iOS Plugin - devices.sh Integration Tests

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "iOS devices.sh Integration Tests"
echo "========================================"
echo ""

# Setup test environment
test_root="$(make_temp_dir "ios-devices")"
mkdir -p "$test_root/devices"
mkdir -p "$test_root/scripts/lib"
mkdir -p "$test_root/scripts/platform"
mkdir -p "$test_root/scripts/domain"
mkdir -p "$test_root/scripts/user"

# Copy required scripts (layered structure)
cp "$script_dir/../../ios/virtenv/scripts/lib/lib.sh" "$test_root/scripts/lib/"
cp "$script_dir/../../ios/virtenv/scripts/platform/core.sh" "$test_root/scripts/platform/"
cp "$script_dir/../../ios/virtenv/scripts/platform/device_config.sh" "$test_root/scripts/platform/"
cp "$script_dir/../../ios/virtenv/scripts/domain/device_manager.sh" "$test_root/scripts/domain/"
cp "$script_dir/../../ios/virtenv/scripts/user/devices.sh" "$test_root/scripts/user/"
chmod +x "$test_root/scripts/user/devices.sh"

# Set environment variables
export IOS_CONFIG_DIR="$test_root"
export IOS_DEVICES_DIR="$test_root/devices"
export IOS_SCRIPTS_DIR="$test_root/scripts"
export IOS_DEVICES=""  # Empty = all devices
export IOS_DEFAULT_DEVICE=""
export DEVBOX_PROJECT_ROOT="$test_root"

devices_script="$test_root/scripts/user/devices.sh"

# Test: Create device
echo "TEST: Create device"
assert_success "$devices_script create test_iphone --runtime 17.5" "Create device"
assert_success "[ -f '$test_root/devices/test_iphone.json' ]" "Device file created"

# Test: List devices
echo ""
echo "TEST: List devices"
assert_success "$devices_script list | grep -q test_iphone" "List shows created device"

# Test: Show device
echo ""
echo "TEST: Show device"
assert_success "$devices_script show test_iphone | grep -q '\"runtime\": \"17.5\"'" "Show device contains correct runtime"

# Test: Update device
echo ""
echo "TEST: Update device"
assert_success "$devices_script update test_iphone --runtime 18.0" "Update device runtime"
assert_success "$devices_script show test_iphone | grep -q '\"runtime\": \"18.0\"'" "Device updated correctly"

# Test: Eval (generate lock file)
echo ""
echo "TEST: Generate lock file"
assert_success "$devices_script eval" "Generate lock file"
assert_success "[ -f '$test_root/devices/devices.lock' ]" "Lock file created"

# Verify lock file contains device
echo ""
echo "TEST: Lock file contents"
if [ -f "$test_root/devices/devices.lock" ]; then
  if jq -e '.devices[] | select(.name == "test_iphone")' "$test_root/devices/devices.lock" >/dev/null 2>&1; then
    echo "  ✓ PASS: Lock file contains device"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL: Lock file missing device"
    test_failed=$((test_failed + 1))
  fi
else
  echo "  ✗ FAIL: Lock file not found"
  test_failed=$((test_failed + 1))
fi

# Test: Device filtering with IOS_DEVICES
echo ""
echo "TEST: Device filtering (create multiple devices)"
assert_success "$devices_script create test_min --runtime 15.4" "Create min device"
assert_success "$devices_script create test_max --runtime 18.0" "Create max device"

# Generate lock file with all devices
assert_success "$devices_script eval" "Generate lock with all devices"

# Count devices in lock file
if [ -f "$test_root/devices/devices.lock" ]; then
  device_count=$(jq '.devices | length' "$test_root/devices/devices.lock")
  if [ "$device_count" -eq 3 ]; then
    echo "  ✓ PASS: Lock file contains all 3 devices"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL: Expected 3 devices, got $device_count"
    test_failed=$((test_failed + 1))
  fi
fi

# Test: Delete device
echo ""
echo "TEST: Delete device"
assert_success "$devices_script delete test_iphone" "Delete device"
assert_success "[ ! -f '$test_root/devices/test_iphone.json' ]" "Device file removed"

# Cleanup
rm -rf "$test_root"

# ============================================================================
# Test Summary
# ============================================================================

test_summary "ios-devices"
