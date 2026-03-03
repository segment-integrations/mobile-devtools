#!/usr/bin/env bash
# React Native Plugin - Environment Validation Tests
# Tests that both Android and iOS environments are properly configured in --pure mode
# (matches CI execution environment)

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "React Native Environment Validation (--pure)"
echo "========================================"

rn_example="$script_dir/../../../examples/react-native"

# Helper to run commands in pure devbox environment
run_pure() {
  (cd "$rn_example" && devbox run --pure bash -c "$1" 2>/dev/null)
}

# ============================================================================
# Test: setup command
# ============================================================================

start_test "setup command completes in --pure mode"
(cd "$rn_example" && devbox run --pure setup >/dev/null 2>&1)
exit_code=$?
assert_success "[ $exit_code -eq 0 ]" "setup should exit with 0"

# ============================================================================
# Test: Node.js environment
# ============================================================================

start_test "Node.js is available"
assert_success "run_pure 'command -v node'" "node should be available"

start_test "npm is available"
assert_success "run_pure 'command -v npm'" "npm should be available"

start_test "Node.js version is usable"
assert_success "run_pure 'node --version'" "node --version should work"

# ============================================================================
# Test: React Native environment variables
# ============================================================================

start_test "REACT_NATIVE_VIRTENV is set"
assert_success "run_pure 'test -n \"\$REACT_NATIVE_VIRTENV\" && test -d \"\$REACT_NATIVE_VIRTENV\"'" "virtenv should exist"

start_test "metro.sh is in PATH"
assert_success "run_pure 'command -v metro.sh'" "metro.sh should be available"

# ============================================================================
# Test: Android SDK
# ============================================================================

start_test "ANDROID_SDK_ROOT is set"
sdk_root=$(run_pure 'echo $ANDROID_SDK_ROOT')
assert_not_empty "$sdk_root" "ANDROID_SDK_ROOT should be set"

start_test "adb is in PATH"
assert_success "run_pure 'command -v adb'" "adb should be available"

start_test "android.sh is in PATH"
assert_success "run_pure 'command -v android.sh'" "android.sh should be available"

# ============================================================================
# Test: iOS tools (macOS only)
# ============================================================================

if [ "$(uname -s)" = "Darwin" ]; then
  start_test "xcrun is available (macOS)"
  assert_success "run_pure 'command -v xcrun'" "xcrun should be available"

  start_test "simctl works (macOS)"
  assert_success "run_pure 'xcrun simctl list devices'" "simctl should work"

  start_test "ios.sh is in PATH (macOS)"
  assert_success "run_pure 'command -v ios.sh'" "ios.sh should be available"
fi

# ============================================================================
# Test: Skip flags
# ============================================================================

start_test "ANDROID_SKIP_SETUP=1 skips Android"
output=$(cd "$rn_example" && devbox run --pure -e ANDROID_SKIP_SETUP=1 setup 2>&1)
assert_contains "$output" "Skipping Android setup" "should skip Android"

start_test "IOS_SKIP_SETUP=1 skips iOS"
output=$(cd "$rn_example" && devbox run --pure -e IOS_SKIP_SETUP=1 setup 2>&1)
assert_contains "$output" "Skipping iOS setup" "should skip iOS"

start_test "Both platforms can be skipped (web mode)"
output=$(cd "$rn_example" && devbox run --pure -e ANDROID_SKIP_SETUP=1 -e IOS_SKIP_SETUP=1 setup 2>&1)
assert_contains "$output" "No platforms were set up" "should skip both"

# ============================================================================
# Test: Idempotency
# ============================================================================

start_test "setup is idempotent (can run 3 times)"
(cd "$rn_example" && devbox run --pure setup >/dev/null 2>&1 && devbox run --pure setup >/dev/null 2>&1 && devbox run --pure setup >/dev/null 2>&1)
exit_code=$?
assert_success "[ $exit_code -eq 0 ]" "multiple runs should succeed"

# Summary
test_summary
