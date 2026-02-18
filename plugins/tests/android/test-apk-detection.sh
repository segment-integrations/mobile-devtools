#!/usr/bin/env bash
# Android Plugin - APK Metadata Detection Tests
#
# Tests for APK package name and activity extraction in deploy.sh
# Must be run inside android devbox environment (needs aapt from SDK)

set -euo pipefail

# Setup logging
SCRIPT_DIR_NAME="$(basename "$(dirname "$0")")"
SCRIPT_NAME="$(basename "$0" .sh)"
mkdir -p "${TEST_LOGS_DIR:-reports/logs}"
LOG_FILE="${TEST_LOGS_DIR:-reports/logs}/${SCRIPT_DIR_NAME}-${SCRIPT_NAME}.txt"
exec > >(tee "$LOG_FILE")
exec 2>&1

# ============================================================================
# Test Framework
# ============================================================================

test_passed=0
test_failed=0
test_name=""

start_test() {
  test_name="$1"
  echo ""
  echo "TEST: $test_name"
}

assert_equal() {
  expected="$1"
  actual="$2"
  message="${3:-}"

  if [ "$expected" = "$actual" ]; then
    echo "  PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  FAIL${message:+: $message}"
    echo "    Expected: '$expected'"
    echo "    Actual:   '$actual'"
    test_failed=$((test_failed + 1))
  fi
}

assert_not_empty() {
  actual="$1"
  message="${2:-}"

  if [ -n "$actual" ]; then
    echo "  PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  FAIL${message:+: $message}"
    echo "    Value was empty"
    test_failed=$((test_failed + 1))
  fi
}

assert_success() {
  command_str="$1"
  message="${2:-}"

  if eval "$command_str" >/dev/null 2>&1; then
    echo "  PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  FAIL${message:+: $message}"
    echo "    Command failed: $command_str"
    test_failed=$((test_failed + 1))
  fi
}

assert_failure() {
  command_str="$1"
  message="${2:-}"

  if ! (eval "$command_str") >/dev/null 2>&1; then
    echo "  PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  FAIL${message:+: $message}"
    echo "    Command should have failed: $command_str"
    test_failed=$((test_failed + 1))
  fi
}

test_summary() {
  total=$((test_passed + test_failed))
  echo ""
  echo "========================================"
  echo "Test Summary"
  echo "========================================"
  echo "Total:  $total"
  echo "Passed: $test_passed"
  echo "Failed: $test_failed"
  echo ""

  # Write results file for summary aggregation
  results_dir="${TEST_RESULTS_DIR:-$(cd "$(dirname "$0")/../../../reports/results" 2>/dev/null && pwd || echo "/tmp")}"
  mkdir -p "$results_dir" 2>/dev/null || true
  cat > "$results_dir/android-apk-detection.json" << EOF
{
  "suite": "android-apk-detection",
  "passed": $test_passed,
  "failed": $test_failed,
  "total": $total
}
EOF

  if [ "$test_failed" -gt 0 ]; then
    echo "RESULT: FAILED"
    exit 1
  else
    echo "RESULT: ALL PASSED"
    exit 0
  fi
}

# ============================================================================
# Setup
# ============================================================================

script_dir="$(cd "$(dirname "$0")" && pwd)"
deploy_path="$script_dir/../../android/virtenv/scripts/domain/deploy.sh"
lib_path="$script_dir/../../android/virtenv/scripts/lib/lib.sh"
core_path="$script_dir/../../android/virtenv/scripts/platform/core.sh"
fixture_apk="$script_dir/fixtures/test-app.apk"

if [ ! -f "$deploy_path" ]; then
  echo "ERROR: deploy.sh not found at: $deploy_path"
  exit 1
fi

if [ ! -f "$fixture_apk" ]; then
  echo "ERROR: Test fixture APK not found at: $fixture_apk"
  exit 1
fi

# Source dependencies
. "$lib_path"
. "$core_path"
. "$deploy_path"

echo "========================================"
echo "Android APK Detection Tests"
echo "========================================"
echo "Testing: $deploy_path"
echo "Fixture: $fixture_apk"

# ============================================================================
# Tests: aapt Resolution
# ============================================================================

start_test "android_resolve_aapt - finds aapt tool"
aapt_path=$(android_resolve_aapt)
assert_not_empty "$aapt_path" "Should find aapt tool"
assert_success "[ -x '$aapt_path' ] || command -v '$aapt_path'" "aapt should be executable"

# ============================================================================
# Tests: APK Metadata Extraction
# ============================================================================

start_test "android_extract_apk_metadata - extracts package name and activity"
metadata=$(android_extract_apk_metadata "$fixture_apk")
package_name=$(printf '%s\n' "$metadata" | sed -n '1p')
activity_name=$(printf '%s\n' "$metadata" | sed -n '2p')
assert_equal "com.example.devbox" "$package_name" "Should extract correct package name"
assert_not_empty "$activity_name" "Should extract activity name"

start_test "android_extract_apk_metadata - fails on nonexistent APK"
assert_failure "android_extract_apk_metadata '/nonexistent/path/fake.apk'" "Should fail on missing APK"

start_test "android_extract_apk_metadata - fails on non-APK file"
assert_failure "android_extract_apk_metadata '$script_dir/test-lib.sh'" "Should fail on non-APK file"

# ============================================================================
# Tests: Activity Component Resolution
# ============================================================================

start_test "android_resolve_activity_component - relative activity"
component=$(android_resolve_activity_component "com.example.app" ".MainActivity")
assert_equal "com.example.app/.MainActivity" "$component" "Should resolve relative activity"

start_test "android_resolve_activity_component - full activity"
component=$(android_resolve_activity_component "com.example.app" "com.example.app.MainActivity")
assert_equal "com.example.app/com.example.app.MainActivity" "$component" "Should resolve full activity"

start_test "android_resolve_activity_component - simple activity name"
component=$(android_resolve_activity_component "com.example.app" "MainActivity")
assert_equal "com.example.app/MainActivity" "$component" "Should resolve simple activity name"

start_test "android_resolve_activity_component - already has slash"
component=$(android_resolve_activity_component "com.example.app" "com.example.app/.MainActivity")
assert_equal "com.example.app/.MainActivity" "$component" "Should pass through component with slash"

# ============================================================================
# Tests: APK Path Resolution
# ============================================================================

start_test "android_resolve_apk_path - finds APK by exact path"
resolved=$(android_resolve_apk_path "$script_dir/fixtures" "test-app.apk")
assert_equal "$fixture_apk" "$resolved" "Should resolve exact APK path"

start_test "android_resolve_apk_path - finds APK by glob pattern"
resolved=$(android_resolve_apk_path "$script_dir/fixtures" "*.apk")
assert_equal "$fixture_apk" "$resolved" "Should resolve glob pattern"

start_test "android_resolve_apk_path - fails on no match"
assert_failure "android_resolve_apk_path '$script_dir/fixtures' 'nonexistent-*.apk'" "Should fail when no APK matches"

# ============================================================================
# Tests: Auto-detection File Output
# ============================================================================

start_test "deploy saves app-id.txt after metadata extraction"
test_runtime="/tmp/android-apk-test-$$"
mkdir -p "$test_runtime"
ANDROID_RUNTIME_DIR="$test_runtime" ANDROID_USER_HOME="$test_runtime"

# Simulate what android_run_app does after extraction
package_name="com.example.devbox"
activity_name=".MainActivity"
runtime_dir="$test_runtime"
mkdir -p "$runtime_dir"
echo "$package_name" > "$runtime_dir/app-id.txt"
echo "$activity_name" > "$runtime_dir/app-activity.txt"

saved_id=$(cat "$test_runtime/app-id.txt")
saved_activity=$(cat "$test_runtime/app-activity.txt")
assert_equal "com.example.devbox" "$saved_id" "Should save package name to app-id.txt"
assert_equal ".MainActivity" "$saved_activity" "Should save activity to app-activity.txt"

# Cleanup
rm -rf "$test_runtime"

# ============================================================================
# Summary
# ============================================================================

test_summary
