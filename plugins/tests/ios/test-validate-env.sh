#!/usr/bin/env bash
# iOS Plugin - Environment Validation Tests
# Tests that setup command properly configures the iOS environment

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "iOS Environment Validation"
echo "========================================"

# Only run on macOS
if [ "$(uname -s)" != "Darwin" ]; then
  echo "⏭️  Skipping iOS validation tests (not macOS)"
  exit 0
fi

# ============================================================================
# Test: setup command
# ============================================================================

start_test "setup command completes without errors"
(cd "$script_dir/../../../examples/ios" && devbox run setup >/dev/null 2>&1)
exit_code=$?
assert_success "[ $exit_code -eq 0 ]" "setup should exit with 0"

# ============================================================================
# Test: Xcode tools
# ============================================================================

start_test "xcrun is available"
assert_success "cd '$script_dir/../../../examples/ios' && devbox run bash -c 'command -v xcrun' >/dev/null 2>&1" "xcrun should be available"

start_test "xcrun can show SDK path"
assert_success "cd '$script_dir/../../../examples/ios' && devbox run bash -c 'xcrun --show-sdk-path' >/dev/null 2>&1" "SDK path should be available"

start_test "simctl list devices works"
assert_success "cd '$script_dir/../../../examples/ios' && devbox run bash -c 'xcrun simctl list devices' >/dev/null 2>&1" "simctl should work"

# ============================================================================
# Test: Skip flag
# ============================================================================

start_test "setup respects IOS_SKIP_SETUP=1"
output=$(cd "$script_dir/../../../examples/ios" && devbox run -e IOS_SKIP_SETUP=1 setup 2>&1)
assert_success "echo '$output' | grep -q 'Skipping iOS setup'" "should skip when flag is set"

# ============================================================================
# Test: Idempotency
# ============================================================================

start_test "setup is idempotent (can run 3 times)"
(cd "$script_dir/../../../examples/ios" && devbox run setup >/dev/null 2>&1 && devbox run setup >/dev/null 2>&1 && devbox run setup >/dev/null 2>&1)
exit_code=$?
assert_success "[ $exit_code -eq 0 ]" "multiple runs should succeed"

# Summary
test_summary
