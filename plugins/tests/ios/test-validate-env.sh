#!/usr/bin/env bash
# iOS Plugin - Environment Validation Tests
# Tests that the iOS environment is properly configured in --pure mode
# (matches CI execution environment)

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "iOS Environment Validation (--pure)"
echo "========================================"

# Only run on macOS
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Skipping iOS validation tests (not macOS)"
  exit 0
fi

ios_example="$script_dir/../../../examples/ios"

# Helper to run commands in pure devbox environment
run_pure() {
  (cd "$ios_example" && devbox run --pure bash -c "$1" 2>/dev/null)
}

# ============================================================================
# Test: setup command
# ============================================================================

start_test "setup command completes in --pure mode"
(cd "$ios_example" && devbox run --pure setup >/dev/null 2>&1)
exit_code=$?
assert_success "[ $exit_code -eq 0 ]" "setup should exit with 0"

# ============================================================================
# Test: Xcode tools
# ============================================================================

start_test "xcrun is available"
assert_success "run_pure 'command -v xcrun'" "xcrun should be available"

start_test "xcodebuild is available"
assert_success "run_pure 'command -v xcodebuild'" "xcodebuild should be available"

start_test "xcrun can show SDK path"
assert_success "run_pure 'xcrun --show-sdk-path'" "SDK path should be available"

start_test "simctl list devices works"
assert_success "run_pure 'xcrun simctl list devices'" "simctl should work"

start_test "swift compiler is available"
assert_success "run_pure 'command -v swift'" "swift should be available"

# ============================================================================
# Test: iOS environment variables
# ============================================================================

start_test "IOS_SCRIPTS_DIR is set"
assert_success "run_pure 'test -n \"\$IOS_SCRIPTS_DIR\" && test -d \"\$IOS_SCRIPTS_DIR\"'" "scripts dir should exist"

start_test "IOS_DEVICES_DIR is set"
assert_success "run_pure 'test -n \"\$IOS_DEVICES_DIR\" && test -d \"\$IOS_DEVICES_DIR\"'" "devices dir should exist"

start_test "device definitions exist"
assert_success "run_pure 'ls \"\$IOS_DEVICES_DIR\"/*.json >/dev/null 2>&1'" "should have device JSON files"

start_test "ios.sh is in PATH"
assert_success "run_pure 'command -v ios.sh'" "ios.sh should be available"

# ============================================================================
# Test: Skip flag
# ============================================================================

start_test "setup respects IOS_SKIP_SETUP=1"
output=$(cd "$ios_example" && devbox run --pure -e IOS_SKIP_SETUP=1 setup 2>&1)
assert_success "echo '$output' | grep -q 'Skipping iOS setup'" "should skip when flag is set"

# ============================================================================
# Test: Idempotency
# ============================================================================

start_test "setup is idempotent (can run 3 times)"
(cd "$ios_example" && devbox run --pure setup >/dev/null 2>&1 && devbox run --pure setup >/dev/null 2>&1 && devbox run --pure setup >/dev/null 2>&1)
exit_code=$?
assert_success "[ $exit_code -eq 0 ]" "multiple runs should succeed"

# Summary
test_summary
