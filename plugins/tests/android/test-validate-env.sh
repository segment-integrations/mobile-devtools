#!/usr/bin/env bash
# Android Plugin - Environment Validation Tests
# Tests that the Android environment is properly configured in --pure mode
# (matches CI execution environment)

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "Android Environment Validation (--pure)"
echo "========================================"

android_example="$script_dir/../../../examples/android"

# Helper to run commands in pure devbox environment
run_pure() {
  (cd "$android_example" && devbox run --pure bash -c "$1" 2>/dev/null)
}

# ============================================================================
# Test: setup command
# ============================================================================

start_test "setup command completes in --pure mode"
(cd "$android_example" && devbox run --pure setup >/dev/null 2>&1)
exit_code=$?
assert_success "[ $exit_code -eq 0 ]" "setup should exit with 0"

# ============================================================================
# Test: SDK environment variables
# ============================================================================

start_test "ANDROID_SDK_ROOT is set"
sdk_root=$(run_pure 'echo $ANDROID_SDK_ROOT')
assert_success "[ -n '$sdk_root' ]" "ANDROID_SDK_ROOT should be set"

start_test "ANDROID_SDK_ROOT directory exists"
assert_success "run_pure 'test -d \"\$ANDROID_SDK_ROOT\"'" "directory should exist"

start_test "ANDROID_HOME matches ANDROID_SDK_ROOT"
home=$(run_pure 'echo $ANDROID_HOME')
assert_success "[ '$home' = '$sdk_root' ]" "ANDROID_HOME should match ANDROID_SDK_ROOT"

start_test "ANDROID_AVD_HOME is set and writable"
assert_success "run_pure 'test -n \"\$ANDROID_AVD_HOME\" && test -w \"\$ANDROID_AVD_HOME\"'" "AVD home should be writable"

# ============================================================================
# Test: Tools in PATH
# ============================================================================

start_test "adb is in PATH"
assert_success "run_pure 'command -v adb'" "adb should be available"

start_test "emulator is in PATH"
assert_success "run_pure 'command -v emulator'" "emulator should be available"

start_test "avdmanager is in PATH"
assert_success "run_pure 'command -v avdmanager'" "avdmanager should be available"

start_test "android.sh is in PATH"
assert_success "run_pure 'command -v android.sh'" "android.sh should be available"

start_test "gradle is in PATH"
assert_success "run_pure 'command -v gradle'" "gradle should be available"

# ============================================================================
# Test: SDK directories
# ============================================================================

start_test "platform-tools directory exists"
assert_success "run_pure 'test -d \"\$ANDROID_SDK_ROOT/platform-tools\"'" "platform-tools should exist"

start_test "emulator directory exists"
assert_success "run_pure 'test -d \"\$ANDROID_SDK_ROOT/emulator\"'" "emulator directory should exist"

start_test "build-tools directory exists"
assert_success "run_pure 'test -d \"\$ANDROID_SDK_ROOT/build-tools\"'" "build-tools should exist"

# ============================================================================
# Test: Device configuration
# ============================================================================

start_test "ANDROID_DEVICES_DIR is set"
assert_success "run_pure 'test -n \"\$ANDROID_DEVICES_DIR\" && test -d \"\$ANDROID_DEVICES_DIR\"'" "devices dir should exist"

start_test "device definitions exist"
assert_success "run_pure 'ls \"\$ANDROID_DEVICES_DIR\"/*.json >/dev/null 2>&1'" "should have device JSON files"

# ============================================================================
# Test: Skip flag
# ============================================================================

start_test "setup respects ANDROID_SKIP_SETUP=1"
output=$(cd "$android_example" && devbox run --pure -e ANDROID_SKIP_SETUP=1 setup 2>&1)
assert_success "echo '$output' | grep -q 'Skipping Android setup'" "should skip when flag is set"

# ============================================================================
# Test: Idempotency
# ============================================================================

start_test "setup is idempotent (can run 3 times)"
(cd "$android_example" && devbox run --pure setup >/dev/null 2>&1 && devbox run --pure setup >/dev/null 2>&1 && devbox run --pure setup >/dev/null 2>&1)
exit_code=$?
assert_success "[ $exit_code -eq 0 ]" "multiple runs should succeed"

# Summary
test_summary
