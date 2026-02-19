#!/usr/bin/env bash
# iOS Plugin - devices.sh Integration Tests

set -euo pipefail

# Setup logging - redirect all output to log file
SCRIPT_DIR_NAME="$(basename "$(dirname "$0")")"
SCRIPT_NAME="$(basename "$0" .sh)"
mkdir -p "${TEST_LOGS_DIR:-reports/logs}"
LOG_FILE="${TEST_LOGS_DIR:-reports/logs}/${SCRIPT_DIR_NAME}-${SCRIPT_NAME}.txt"
exec > >(tee "$LOG_FILE")
exec 2>&1

test_passed=0
test_failed=0

assert_success() {
  if eval "$1" >/dev/null 2>&1; then
    echo "  ✓ PASS: $2"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL: $2"
    test_failed=$((test_failed + 1))
  fi
}

echo "========================================"
echo "iOS devices.sh Integration Tests"
echo "========================================"
echo ""

# Setup test environment
test_root="/tmp/ios-plugin-device-test-$$"
mkdir -p "$test_root/devices"
mkdir -p "$test_root/scripts/lib"
mkdir -p "$test_root/scripts/platform"
mkdir -p "$test_root/scripts/domain"
mkdir -p "$test_root/scripts/user"

# Copy required scripts (layered structure)
script_dir="$(cd "$(dirname "$0")" && pwd)"
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

# Summary
echo ""
echo "========================================"
total=$((test_passed + test_failed))
echo "Total:  $total"
echo "Passed: $test_passed"
echo "Failed: $test_failed"
echo ""

# Write results file for summary aggregation
results_dir="${TEST_RESULTS_DIR:-$(cd "$(dirname "$0")/../../../reports/results" 2>/dev/null && pwd || echo "/tmp")}"
mkdir -p "$results_dir" 2>/dev/null || true
cat > "$results_dir/ios-devices.json" << EOF
{
  "suite": "ios-devices",
  "passed": $test_passed,
  "failed": $test_failed,
  "total": $total
}
EOF

if [ "$test_failed" -gt 0 ]; then
  echo "RESULT: ✗ FAILED"
  exit 1
else
  echo "RESULT: ✓ ALL PASSED"
  exit 0
fi
