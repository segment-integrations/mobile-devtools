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
# E2E Step Tracking
# ============================================================================

# Record a passing E2E step. Call from process-compose YAML processes.
e2e_step_pass() {
  local step_name="$1"
  mkdir -p reports/steps
  echo "pass" > "reports/steps/${step_name}.status"
}

# Record a failing E2E step with an optional reason.
e2e_step_fail() {
  local step_name="$1"
  local reason="${2:-Unknown error}"
  mkdir -p reports/steps
  printf 'fail\n%s\n' "$reason" > "reports/steps/${step_name}.status"
}

# Read all step status files and report results. Replaces assert_file_exists
# for E2E summaries. Returns 0 if all steps passed, 1 otherwise.
e2e_report_steps() {
  local steps_dir="reports/steps"
  local any_failure=0

  if [ ! -d "$steps_dir" ] || [ -z "$(ls "$steps_dir"/*.status 2>/dev/null)" ]; then
    echo "  No step status files found - pipeline may not have started"
    test_failed=$((test_failed + 1))
    return 1
  fi

  for status_file in "$steps_dir"/*.status; do
    local step_name
    step_name="$(basename "$status_file" .status)"
    local status
    status="$(head -1 "$status_file")"
    if [ "$status" = "pass" ]; then
      echo "  ✓ PASS: $step_name"
      test_passed=$((test_passed + 1))
    else
      local reason
      reason="$(tail -n +2 "$status_file")"
      echo "  ✗ FAIL: $step_name"
      [ -n "$reason" ] && echo "    Reason: $reason"
      test_failed=$((test_failed + 1))
      any_failure=1
    fi
  done

  rm -rf "$steps_dir"
  return $any_failure
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

  # Write per-suite results JSON
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
  "total": ${total},
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF

  # Regenerate combined summary from all suite JSONs
  _regenerate_summary "$results_dir"

  if [ "$test_failed" -gt 0 ]; then
    echo "RESULT: ✗ FAILED"
    exit 1
  else
    echo "RESULT: ✓ ALL PASSED"
    exit 0
  fi
}

# Regenerate reports/summary.md from all per-suite JSON files.
# Called automatically by test_summary(); can also be called standalone.
_regenerate_summary() {
  local results_dir="${1:-${TEST_RESULTS_DIR:-$REPO_ROOT/reports/results}}"
  local reports_dir="${REPORTS_DIR:-$REPO_ROOT/reports}"
  local logs_dir="${TEST_LOGS_DIR:-$reports_dir/logs}"

  # Resolve relative paths against REPO_ROOT
  [[ "$results_dir" = /* ]] || results_dir="$REPO_ROOT/$results_dir"
  [[ "$reports_dir" = /* ]] || reports_dir="$REPO_ROOT/$reports_dir"
  [[ "$logs_dir" = /* ]] || logs_dir="$REPO_ROOT/$logs_dir"

  local summary_file="$reports_dir/summary.md"

  # Bail if no result files exist yet
  local json_files
  json_files=$(ls "$results_dir"/*.json 2>/dev/null | sort) || return 0
  [ -n "$json_files" ] || return 0

  # Aggregate
  local _tp=0 _tf=0 _sc=0 _af=0
  local _names=() _passed=() _failed=() _totals=() _times=()

  for rf in $json_files; do
    [ -f "$rf" ] || continue
    local n p f t ts
    n=$(jq -r '.suite // "unknown"' "$rf" 2>/dev/null)
    p=$(jq -r '.passed // 0' "$rf" 2>/dev/null)
    f=$(jq -r '.failed // 0' "$rf" 2>/dev/null)
    t=$(jq -r '.total // 0' "$rf" 2>/dev/null)
    ts=$(jq -r '.timestamp // ""' "$rf" 2>/dev/null)

    _names+=("$n"); _passed+=("$p"); _failed+=("$f"); _totals+=("$t"); _times+=("$ts")
    _tp=$((_tp + p)); _tf=$((_tf + f)); _sc=$((_sc + 1))
    [ "$f" -gt 0 ] && _af=1
  done

  local _gt=$((_tp + _tf))

  mkdir -p "$reports_dir" 2>/dev/null || true
  {
    echo "# Test Suite Summary"
    echo ""
    echo "**Updated:** $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    if [ "$_af" -gt 0 ]; then
      echo "> **SOME TESTS FAILED**"
    else
      echo "> **ALL ${_sc} SUITES PASSED** (${_gt} tests)"
    fi
    echo ""

    echo "| Suite | Passed | Failed | Total | Result | Ran At |"
    echo "|-------|-------:|-------:|------:|--------|--------|"

    for i in $(seq 0 $((_sc - 1))); do
      local badge="PASS"
      [ "${_failed[$i]}" -gt 0 ] && badge="FAIL"
      echo "| ${_names[$i]} | ${_passed[$i]} | ${_failed[$i]} | ${_totals[$i]} | ${badge} | ${_times[$i]} |"
    done

    local total_badge="PASS"
    [ "$_af" -gt 0 ] && total_badge="FAIL"
    echo "| **TOTAL** | **${_tp}** | **${_tf}** | **${_gt}** | **${total_badge}** | |"
    echo ""

    # Log files
    if ls "$logs_dir"/*.txt >/dev/null 2>&1; then
      echo "## Log Files"
      echo ""
      for log in "$logs_dir"/*.txt; do
        echo "- \`$log\`"
      done
      echo ""
    fi

    echo "---"
    echo ""
    echo "_Run \`devbox run test:fast\` to regenerate this summary_"
  } > "$summary_file"
}
