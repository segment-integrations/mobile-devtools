#!/usr/bin/env bash
# Android Plugin - lib.sh Unit Tests
#
# Tests for core utility functions in lib.sh

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

# ============================================================================
# Setup
# ============================================================================

lib_path="$script_dir/../../android/virtenv/scripts/lib/lib.sh"

if [ ! -f "$lib_path" ]; then
  echo "ERROR: lib.sh not found at: $lib_path"
  exit 1
fi

# Source lib.sh
# shellcheck source=../../android/virtenv/scripts/lib/lib.sh
. "$lib_path"

echo "========================================"
echo "Android lib.sh Unit Tests"
echo "========================================"
echo "Testing: $lib_path"

# ============================================================================
# Tests: String Normalization
# ============================================================================

start_test "android_normalize_name - lowercase conversion"
result="$(android_normalize_name "Pixel")"
assert_equal "pixel" "$result" "Should convert to lowercase"

start_test "android_normalize_name - removes special chars"
result="$(android_normalize_name "Pixel-8_Pro")"
assert_equal "pixel8pro" "$result" "Should remove dashes and underscores"

start_test "android_normalize_name - removes spaces"
result="$(android_normalize_name "Nexus 5X")"
assert_equal "nexus5x" "$result" "Should remove spaces"

start_test "android_sanitize_avd_name - preserves allowed chars"
result="$(android_sanitize_avd_name "Pixel_8-Pro.v2")"
assert_equal "Pixel_8-Pro.v2" "$result" "Should preserve ._- characters"

start_test "android_sanitize_avd_name - converts spaces"
result="$(android_sanitize_avd_name "Pixel 8 Pro")"
assert_equal "Pixel_8_Pro" "$result" "Should convert spaces to underscores"

start_test "android_sanitize_avd_name - removes invalid chars"
result="$(android_sanitize_avd_name "Pixel@#8!")"
assert_equal "Pixel8" "$result" "Should remove @#! characters"

start_test "android_sanitize_avd_name - fails on empty input"
assert_failure "android_sanitize_avd_name ''" "Should fail on empty string"

# ============================================================================
# Tests: Checksum Functions
# ============================================================================

# Read-only checksum tests use example project fixtures
example_devices="$(fixture_android_devices_dir)"

start_test "android_compute_devices_checksum - generates checksum"
result="$(android_compute_devices_checksum "$example_devices")"
assert_success "[ -n '$result' ]" "Should return non-empty checksum"

start_test "android_compute_devices_checksum - stable checksum"
checksum1="$(android_compute_devices_checksum "$example_devices")"
checksum2="$(android_compute_devices_checksum "$example_devices")"
assert_equal "$checksum1" "$checksum2" "Should return same checksum for same files"

# Write test needs a temp dir
start_test "android_compute_devices_checksum - different content = different checksum"
test_dir="$(make_temp_dir "android-checksum")"
echo '{"name":"test1","api":28}' > "$test_dir/test1.json"
checksum_before="$(android_compute_devices_checksum "$test_dir")"
echo '{"name":"test2","api":36}' > "$test_dir/test2.json"
checksum_after="$(android_compute_devices_checksum "$test_dir")"
assert_success "[ '$checksum_before' != '$checksum_after' ]" "Should change when files change"
rm -rf "$test_dir"

start_test "android_compute_devices_checksum - fails on non-existent dir"
assert_failure "android_compute_devices_checksum '/nonexistent/path'" "Should fail on missing directory"

# ============================================================================
# Tests: Path Resolution
# ============================================================================

# Use example android project for path resolution
example_android_dir="$REPO_ROOT/examples/android"

# Save original and set test root
SAVED_PROJECT_ROOT="${DEVBOX_PROJECT_ROOT:-}"
unset ANDROID_CONFIG_DIR
export DEVBOX_PROJECT_ROOT="$example_android_dir"

start_test "android_resolve_project_path - finds existing file"
result="$(android_resolve_project_path "devices" 2>/dev/null || true)"
if [ -n "$result" ] && [ -d "$result" ]; then
  assert_success "true" "Should resolve to existing directory"
else
  assert_failure "false" "Should have found devices directory"
fi

start_test "android_resolve_project_path - finds directory"
result="$(android_resolve_project_path "devices" 2>/dev/null || true)"
expected="${example_android_dir}/devbox.d/android/devices"
assert_equal "$expected" "$result" "Should resolve devices directory"

start_test "android_resolve_project_path - fails on missing path"
assert_failure "android_resolve_project_path 'nonexistent.json'" "Should fail when path doesn't exist"

start_test "android_resolve_config_dir - finds config directory"
result="$(android_resolve_config_dir 2>/dev/null || true)"
expected="${example_android_dir}/devbox.d/android"
assert_equal "$expected" "$result" "Should find android config directory"

# Restore
if [ -n "$SAVED_PROJECT_ROOT" ]; then
  export DEVBOX_PROJECT_ROOT="$SAVED_PROJECT_ROOT"
else
  unset DEVBOX_PROJECT_ROOT
fi

# ============================================================================
# Tests: Requirement Functions
# ============================================================================

start_test "android_require_jq - succeeds when jq available"
assert_success "android_require_jq" "Should succeed if jq is installed"

start_test "android_require_tool - succeeds for existing tool"
assert_success "android_require_tool 'sh'" "Should succeed for sh"

start_test "android_require_tool - fails for missing tool"
assert_failure "android_require_tool 'nonexistent_tool_xyz'" "Should fail for missing tool"

# Create test directory for dir_contains test
test_sdk="$(make_temp_dir "android-sdk")"
mkdir -p "$test_sdk/platform-tools"

start_test "android_require_dir_contains - succeeds when path exists"
assert_success "android_require_dir_contains '$test_sdk' 'platform-tools'" "Should succeed when subpath exists"

start_test "android_require_dir_contains - fails when path missing"
assert_failure "android_require_dir_contains '$test_sdk' 'nonexistent'" "Should fail when subpath missing"

# Cleanup
rm -rf "$test_sdk"

# ============================================================================
# Test Summary
# ============================================================================

test_summary "android-lib"
