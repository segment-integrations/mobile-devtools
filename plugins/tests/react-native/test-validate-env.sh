#!/usr/bin/env bash
# React Native Plugin - Environment Validation Tests
# Tests that setup command properly configures both Android and iOS environments

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "React Native Environment Validation"
echo "========================================"

# ============================================================================
# Test: setup command
# ============================================================================

start_test "setup command completes without errors"
(cd "$script_dir/../../../examples/react-native" && devbox run setup >/dev/null 2>&1)
exit_code=$?
assert_success "[ $exit_code -eq 0 ]" "setup should exit with 0"

# ============================================================================
# Test: Node.js environment
# ============================================================================

start_test "Node.js is available"
assert_success "cd '$script_dir/../../../examples/react-native' && devbox run bash -c 'command -v node' >/dev/null 2>&1" "node should be available"

start_test "npm is available"
assert_success "cd '$script_dir/../../../examples/react-native' && devbox run bash -c 'command -v npm' >/dev/null 2>&1" "npm should be available"

# ============================================================================
# Test: Android SDK
# ============================================================================

start_test "Android SDK is available"
sdk_root=$(cd "$script_dir/../../../examples/react-native" && devbox run bash -c 'echo $ANDROID_SDK_ROOT' 2>/dev/null)
assert_success "[ -n '$sdk_root' ]" "ANDROID_SDK_ROOT should be set"

# ============================================================================
# Test: iOS tools (macOS only)
# ============================================================================

if [ "$(uname -s)" = "Darwin" ]; then
  start_test "iOS simctl works (macOS)"
  assert_success "cd '$script_dir/../../../examples/react-native' && devbox run bash -c 'xcrun simctl list devices' >/dev/null 2>&1" "simctl should work"
fi

# ============================================================================
# Test: Skip flags
# ============================================================================

start_test "ANDROID_SKIP_SETUP=1 skips Android"
output=$(cd "$script_dir/../../../examples/react-native" && devbox run -e ANDROID_SKIP_SETUP=1 setup 2>&1)
assert_success "echo '$output' | grep -q 'Skipping Android setup'" "should skip Android"

start_test "IOS_SKIP_SETUP=1 skips iOS"
output=$(cd "$script_dir/../../../examples/react-native" && devbox run -e IOS_SKIP_SETUP=1 setup 2>&1)
assert_success "echo '$output' | grep -q 'Skipping iOS setup'" "should skip iOS"

start_test "Both platforms can be skipped (web mode)"
output=$(cd "$script_dir/../../../examples/react-native" && devbox run -e ANDROID_SKIP_SETUP=1 -e IOS_SKIP_SETUP=1 setup 2>&1)
assert_success "echo '$output' | grep -q 'No platforms were set up'" "should skip both"

# ============================================================================
# Test: Idempotency
# ============================================================================

start_test "setup is idempotent (can run 3 times)"
(cd "$script_dir/../../../examples/react-native" && devbox run setup >/dev/null 2>&1 && devbox run setup >/dev/null 2>&1 && devbox run setup >/dev/null 2>&1)
exit_code=$?
assert_success "[ $exit_code -eq 0 ]" "multiple runs should succeed"

# Summary
test_summary
