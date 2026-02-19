#!/usr/bin/env bash
# Shared test framework for plugin unit and integration tests
#
# Source this file from any test script:
#   script_dir="$(cd "$(dirname "$0")" && pwd)"
#   . "$script_dir/../test-framework.sh"
#   setup_logging
#
#   # ... tests ...
#
#   test_summary "suite-name"

set -euo pipefail

# ============================================================================
# Auto-detection
# ============================================================================

FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$FRAMEWORK_DIR/../.." && pwd)}"
export REPO_ROOT

# ============================================================================
# Counters
# ============================================================================

test_passed=0
test_failed=0

# ============================================================================
# Logging Setup
# ============================================================================

# Redirects stdout/stderr to both terminal and a log file under reports/logs/.
# Call this near the top of your test script, after sourcing the framework.
setup_logging() {
  local script_dir_name script_name
  script_dir_name="$(basename "$(dirname "$0")")"
  script_name="$(basename "$0" .sh)"
  mkdir -p "${TEST_LOGS_DIR:-reports/logs}"
  LOG_FILE="${TEST_LOGS_DIR:-reports/logs}/${script_dir_name}-${script_name}.txt"
  exec > >(tee "$LOG_FILE")
  exec 2>&1
}

# ============================================================================
# Test Section Headers
# ============================================================================

start_test() {
  echo ""
  echo "TEST: $1"
}

log_test() {
  echo ""
  echo "========================================"
  echo "TEST: $1"
  echo "========================================"
}

# ============================================================================
# Assertions
# ============================================================================

assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="${3:-}"

  if [ "$expected" = "$actual" ]; then
    echo "  ✓ PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL${message:+: $message}"
    echo "    Expected: '$expected'"
    echo "    Actual:   '$actual'"
    test_failed=$((test_failed + 1))
  fi
}

assert_success() {
  local command_str="$1"
  local message="${2:-}"

  if eval "$command_str" >/dev/null 2>&1; then
    echo "  ✓ PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL${message:+: $message}"
    echo "    Command failed: $command_str"
    test_failed=$((test_failed + 1))
  fi
}

assert_failure() {
  local command_str="$1"
  local message="${2:-}"

  # Run in subshell to prevent exit from killing test script
  if ! (eval "$command_str") >/dev/null 2>&1; then
    echo "  ✓ PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL${message:+: $message}"
    echo "    Command should have failed: $command_str"
    test_failed=$((test_failed + 1))
  fi
}

assert_not_empty() {
  local actual="$1"
  local message="${2:-}"

  if [ -n "$actual" ]; then
    echo "  ✓ PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL${message:+: $message}"
    echo "    Value was empty"
    test_failed=$((test_failed + 1))
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-}"

  if echo "$haystack" | grep -q "$needle"; then
    echo "  ✓ PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL${message:+: $message}"
    echo "    '$haystack' does not contain '$needle'"
    test_failed=$((test_failed + 1))
  fi
}

assert_output() {
  local cmd="$1"
  local expected="$2"
  local description="$3"

  local output
  output=$(eval "$cmd" 2>&1 || true)

  if echo "$output" | grep -q "$expected"; then
    echo "  ✓ PASS${description:+: $description}"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL${description:+: $description}"
    echo "    Expected to contain: $expected"
    echo "    Got: $output"
    test_failed=$((test_failed + 1))
  fi
}

assert_file_exists() {
  local file="$1"
  local message="${2:-File exists: $file}"

  if [ -f "$file" ]; then
    test_passed=$((test_passed + 1))
    echo "  ✓ PASS: ${message}"
  else
    test_failed=$((test_failed + 1))
    echo "  ✗ FAIL: ${message}"
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local message="${3:-File contains pattern: $pattern}"

  if [ -f "$file" ] && grep -q "$pattern" "$file"; then
    test_passed=$((test_passed + 1))
    echo "  ✓ PASS: ${message}"
  else
    test_failed=$((test_failed + 1))
    echo "  ✗ FAIL: ${message}"
  fi
}

assert_command_success() {
  local message="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    test_passed=$((test_passed + 1))
    echo "  ✓ PASS: ${message}"
  else
    test_failed=$((test_failed + 1))
    echo "  ✗ FAIL: ${message}"
    echo "    Command failed: $*"
  fi
}

# ============================================================================
# Fixture Helpers
# ============================================================================

fixture_android_devices_dir() {
  printf '%s\n' "$REPO_ROOT/examples/android/devbox.d/android/devices"
}

fixture_ios_devices_dir() {
  printf '%s\n' "$REPO_ROOT/examples/ios/devbox.d/ios/devices"
}

# Creates a project-local temp directory under reports/tmp/.
# Returns the path. Caller is responsible for cleanup.
make_temp_dir() {
  local label="${1:-test}"
  local temp_dir="$REPO_ROOT/reports/tmp/${label}-$$"
  mkdir -p "$temp_dir"
  printf '%s\n' "$temp_dir"
}

# ============================================================================
# Test Summary
# ============================================================================

test_summary() {
  local suite_name="${1:-unknown}"
  local total=$((test_passed + test_failed))

  echo ""
  echo "========================================"
  echo "Test Summary"
  echo "========================================"
  echo "Total:  $total"
  echo "Passed: $test_passed"
  echo "Failed: $test_failed"
  echo ""

  # Write results file for summary aggregation
  local results_dir="${TEST_RESULTS_DIR:-$REPO_ROOT/reports/results}"
  if [[ ! "$results_dir" = /* ]]; then
    results_dir="$REPO_ROOT/$results_dir"
  fi

  mkdir -p "$results_dir" 2>/dev/null || true
  cat > "$results_dir/${suite_name}.json" << EOF
{
  "suite": "${suite_name}",
  "passed": ${test_passed},
  "failed": ${test_failed},
  "total": ${total}
}
EOF

  if [ "$test_failed" -gt 0 ]; then
    echo "RESULT: ✗ FAILED"
    exit 1
  else
    echo "RESULT: ✓ ALL PASSED"
    exit 0
  fi
}
