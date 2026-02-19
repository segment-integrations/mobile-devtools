#!/usr/bin/env bash
# Android Plugin - devices.sh Integration Tests

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "Android devices.sh Integration Tests"
echo "========================================"
echo ""

# Setup test environment
test_root="$(make_temp_dir "android-devices")"
mkdir -p "$test_root/devices"
mkdir -p "$test_root/scripts/lib"
mkdir -p "$test_root/scripts/platform"
mkdir -p "$test_root/scripts/domain"
mkdir -p "$test_root/scripts/user"

# Copy required scripts with new layer structure
cp "$script_dir/../../android/virtenv/scripts/lib/lib.sh" "$test_root/scripts/lib/"
cp "$script_dir/../../android/virtenv/scripts/platform/core.sh" "$test_root/scripts/platform/"
cp "$script_dir/../../android/virtenv/scripts/platform/device_config.sh" "$test_root/scripts/platform/"
cp "$script_dir/../../android/virtenv/scripts/domain/avd.sh" "$test_root/scripts/domain/"
cp "$script_dir/../../android/virtenv/scripts/user/devices.sh" "$test_root/scripts/user/"

# Set environment variables (new config approach)
export ANDROID_CONFIG_DIR="$test_root"
export ANDROID_DEVICES_DIR="$test_root/devices"
export ANDROID_SCRIPTS_DIR="$test_root/scripts"
export ANDROID_DEVICES=""  # Empty = all devices
export ANDROID_DEFAULT_DEVICE=""

devices_script="$test_root/scripts/user/devices.sh"

# Test: Create device
echo "TEST: Create device"
assert_success "$devices_script create test_pixel --api 28 --device pixel --tag google_apis" "Create device"
assert_success "[ -f '$test_root/devices/test_pixel.json' ]" "Device file created"

# Test: List devices
echo ""
echo "TEST: List devices"
assert_success "$devices_script list | grep -q test_pixel" "List shows created device"

# Test: Show device
echo ""
echo "TEST: Show device"
assert_success "$devices_script show test_pixel | grep -q '\"api\": 28'" "Show device contains correct API"

# Test: Update device
echo ""
echo "TEST: Update device"
assert_success "$devices_script update test_pixel --api 34" "Update device API"
assert_success "$devices_script show test_pixel | grep -q '\"api\": 34'" "Device updated correctly"

# Test: Eval (generate lock file) - with specific device selected
echo ""
echo "TEST: Generate lock file with device selection"
export ANDROID_DEVICES="test_pixel"
assert_success "$devices_script eval" "Generate lock file"
assert_success "[ -f '$test_root/devices/devices.lock' ]" "Lock file created"
assert_success "grep -q 'test_pixel' '$test_root/devices/devices.lock'" "Lock file contains device name"
assert_success "grep -q '34' '$test_root/devices/devices.lock'" "Lock file contains API 34"

# Test: Delete device
echo ""
echo "TEST: Delete device"
assert_success "$devices_script delete test_pixel" "Delete device"
assert_success "[ ! -f '$test_root/devices/test_pixel.json' ]" "Device file removed"

# Cleanup
rm -rf "$test_root"

# ============================================================================
# Test Summary
# ============================================================================

test_summary "android-devices"
