#!/usr/bin/env bash
# iOS Plugin - POSIX Compatibility Tests
#
# Verifies that init scripts (sourced during devbox shell startup) work
# correctly under dash, which is the default /bin/sh on Linux.
# These scripts use #!/usr/bin/env sh and must avoid bash-isms.

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "iOS POSIX Compatibility Tests"
echo "========================================"

# ============================================================================
# Setup
# ============================================================================

scripts_dir="$script_dir/../../ios/virtenv/scripts"

# Scripts that are sourced (must be POSIX-compatible)
sourced_scripts=(
  "$scripts_dir/lib/lib.sh"
  "$scripts_dir/platform/core.sh"
  "$scripts_dir/platform/device_config.sh"
  "$scripts_dir/init/setup.sh"
)

# ============================================================================
# Tests: ShellCheck POSIX Validation
# ============================================================================

if command -v shellcheck >/dev/null 2>&1; then
  for script in "${sourced_scripts[@]}"; do
    script_name="$(basename "$script")"
    start_test "shellcheck --shell=sh $script_name"
    if [ ! -f "$script" ]; then
      echo "  ✗ FAIL: Script not found: $script"
      test_failed=$((test_failed + 1))
      continue
    fi
    output="$(shellcheck --shell=sh --severity=error "$script" 2>&1 || true)"
    if [ -z "$output" ]; then
      echo "  ✓ PASS: No POSIX errors"
      test_passed=$((test_passed + 1))
    else
      echo "  ✗ FAIL: ShellCheck found POSIX issues"
      echo "$output" | head -20
      test_failed=$((test_failed + 1))
    fi
  done
else
  echo "SKIP: shellcheck not available (install for POSIX validation)"
fi

# ============================================================================
# Tests: Dash Compatibility (if dash is available)
# ============================================================================

if command -v dash >/dev/null 2>&1; then
  start_test "lib.sh sources under dash without error"
  if dash -c ". '$scripts_dir/lib/lib.sh'" >/dev/null 2>&1; then
    echo "  ✓ PASS: lib.sh sources cleanly under dash"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL: lib.sh failed under dash"
    test_failed=$((test_failed + 1))
  fi

  start_test "platform/core.sh sources under dash without error"
  # core.sh sources lib.sh, so set IOS_SCRIPTS_DIR
  if dash -c "IOS_SCRIPTS_DIR='$scripts_dir'; export IOS_SCRIPTS_DIR; . '$scripts_dir/platform/core.sh'" >/dev/null 2>&1; then
    echo "  ✓ PASS: core.sh sources cleanly under dash"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL: core.sh failed under dash"
    test_failed=$((test_failed + 1))
  fi

  start_test "platform/device_config.sh sources under dash without error"
  if dash -c "IOS_SCRIPTS_DIR='$scripts_dir'; export IOS_SCRIPTS_DIR; . '$scripts_dir/platform/device_config.sh'" >/dev/null 2>&1; then
    echo "  ✓ PASS: device_config.sh sources cleanly under dash"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL: device_config.sh failed under dash"
    test_failed=$((test_failed + 1))
  fi
else
  echo "SKIP: dash not available (install for runtime POSIX testing)"
fi

# ============================================================================
# Summary
# ============================================================================

test_summary "ios-posix-compat"
