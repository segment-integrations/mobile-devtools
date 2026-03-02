#!/usr/bin/env bash
# Android Plugin - Environment Validation Tests
# Tests that setup command properly configures the Android environment

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "Android Environment Validation"
echo "========================================"

# ============================================================================
# Test: setup command
# ============================================================================

start_test "setup command completes without errors"
(cd "$script_dir/../../../examples/android" && devbox run setup >/dev/null 2>&1)
exit_code=$?
assert_success "[ $exit_code -eq 0 ]" "setup should exit with 0"

# ============================================================================
# Test: Environment variables
# ============================================================================

start_test "ANDROID_SDK_ROOT is set after setup"
sdk_root=$(cd "$script_dir/../../../examples/android" && devbox run bash -c 'echo $ANDROID_SDK_ROOT' 2>/dev/null)
assert_success "[ -n '$sdk_root' ]" "ANDROID_SDK_ROOT should be set"

start_test "ANDROID_SDK_ROOT directory exists"
assert_success "cd '$script_dir/../../../examples/android' && devbox run bash -c 'test -d \"\$ANDROID_SDK_ROOT\"' 2>/dev/null" "directory should exist"

# ============================================================================
# Test: Tools in PATH
# ============================================================================

start_test "adb is in PATH"
assert_success "cd '$script_dir/../../../examples/android' && devbox run bash -c 'command -v adb' >/dev/null 2>&1" "adb should be available"

start_test "emulator is in PATH"
assert_success "cd '$script_dir/../../../examples/android' && devbox run bash -c 'command -v emulator' >/dev/null 2>&1" "emulator should be available"

start_test "avdmanager is in PATH"
assert_success "cd '$script_dir/../../../examples/android' && devbox run bash -c 'command -v avdmanager' >/dev/null 2>&1" "avdmanager should be available"

# ============================================================================
# Test: Skip flag
# ============================================================================

start_test "setup respects ANDROID_SKIP_SETUP=1"
output=$(cd "$script_dir/../../../examples/android" && devbox run -e ANDROID_SKIP_SETUP=1 setup 2>&1)
assert_success "echo '$output' | grep -q 'Skipping Android setup'" "should skip when flag is set"

# ============================================================================
# Test: Idempotency
# ============================================================================

start_test "setup is idempotent (can run 3 times)"
(cd "$script_dir/../../../examples/android" && devbox run setup >/dev/null 2>&1 && devbox run setup >/dev/null 2>&1 && devbox run setup >/dev/null 2>&1)
exit_code=$?
assert_success "[ $exit_code -eq 0 ]" "multiple runs should succeed"

# Summary
test_summary
