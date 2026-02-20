#!/usr/bin/env bash
# iOS Plugin - lib.sh Unit Tests

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

IOS_SCRIPTS_DIR="${script_dir}/../../ios/virtenv/scripts"
export IOS_SCRIPTS_DIR

# Source lib.sh (new location in lib/)
. "${IOS_SCRIPTS_DIR}/lib/lib.sh"

echo "========================================"
echo "iOS lib.sh Unit Tests"
echo "========================================"
echo "Testing: ${IOS_SCRIPTS_DIR}/lib/lib.sh"

# ============================================================================
# Tests: Load Guards
# ============================================================================

start_test "Load-once guard"
. "${IOS_SCRIPTS_DIR}/lib/lib.sh"
assert_equal "1" "${IOS_LIB_LOADED}" "Load-once guard should keep IOS_LIB_LOADED=1"

start_test "Execution protection"
assert_failure "sh '${IOS_SCRIPTS_DIR}/lib/lib.sh'" "Should fail when executed directly"

# ============================================================================
# Tests: String Normalization
# ============================================================================

start_test "ios_sanitize_device_name - preserves valid name"
result="$(ios_sanitize_device_name "iPhone 15 Pro" || true)"
assert_equal "iPhone 15 Pro" "$result" "Should preserve valid device name"

start_test "ios_sanitize_device_name - removes invalid chars"
result="$(ios_sanitize_device_name "Test Device!@#" || true)"
assert_equal "Test Device" "$result" "Should remove invalid characters"

# ============================================================================
# Tests: Config Path Resolution (using example project fixtures)
# ============================================================================

example_ios_dir="$REPO_ROOT/examples/ios"

start_test "ios_config_path"
unset IOS_CONFIG_DIR
DEVBOX_PROJECT_ROOT="$example_ios_dir"
export DEVBOX_PROJECT_ROOT
config_path="$(ios_config_path 2>/dev/null || true)"
expected="$example_ios_dir/devbox.d/ios"
assert_equal "$expected" "$config_path" "Should resolve to example ios config dir"

start_test "ios_devices_dir"
unset IOS_DEVICES_DIR
devices_dir="$(ios_devices_dir 2>/dev/null || true)"
expected="$example_ios_dir/devbox.d/ios/devices"
assert_equal "$expected" "$devices_dir" "Should resolve to example ios devices dir"
assert_success "[ -d '$devices_dir' ]" "Devices dir should exist"

# ============================================================================
# Tests: Checksum (using example project fixtures)
# ============================================================================

start_test "ios_compute_devices_checksum - computes checksum"
checksum1="$(ios_compute_devices_checksum "$devices_dir" || true)"
assert_not_empty "$checksum1" "Should compute checksum"
assert_equal "64" "${#checksum1}" "Checksum should be 64 characters"

start_test "ios_compute_devices_checksum - stable checksum"
checksum2="$(ios_compute_devices_checksum "$devices_dir" || true)"
assert_equal "$checksum1" "$checksum2" "Checksum should be stable across calls"

# ============================================================================
# Tests: Requirement Functions
# ============================================================================

start_test "ios_require_jq"
if command -v jq >/dev/null 2>&1; then
  assert_success "ios_require_jq" "Should succeed when jq is available"
else
  echo "  SKIP: jq not available"
fi

start_test "ios_require_tool"
assert_success "ios_require_tool 'sh' 'sh is required'" "Should succeed for sh"
assert_failure "ios_require_tool 'nonexistent_tool_xyz'" "Should fail for missing tool"

# ============================================================================
# Test Summary
# ============================================================================

test_summary "ios-lib"
