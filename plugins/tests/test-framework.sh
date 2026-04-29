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

# Record the start time of an E2E step. Call at the beginning of a step.
e2e_step_start() {
  local step_name="$1"
  local steps_dir="${E2E_STEPS_DIR:-${REPO_ROOT:-.}/reports/steps}"
  mkdir -p "$steps_dir"
  date +%s > "$steps_dir/${step_name}.start"
}

# Record the end time of an E2E step. Call at the end of a step.
# Calculates duration from start time if available.
e2e_step_end() {
  local step_name="$1"
  local status="${2:-pass}"
  local reason="${3:-}"

  local steps_dir="${E2E_STEPS_DIR:-${REPO_ROOT:-.}/reports/steps}"
  mkdir -p "$steps_dir"
  local end_time
  end_time=$(date +%s)

  # Calculate duration if start time exists
  local duration=""
  if [ -f "$steps_dir/${step_name}.start" ]; then
    local start_time
    start_time=$(cat "$steps_dir/${step_name}.start")
    local elapsed=$((end_time - start_time))
    duration="${elapsed}s"
  fi

  # Write status file with duration
  if [ "$status" = "pass" ]; then
    if [ -n "$duration" ]; then
      printf 'pass\n%s\n' "$duration" > "$steps_dir/${step_name}.status"
    else
      echo "pass" > "$steps_dir/${step_name}.status"
    fi
  else
    if [ -n "$duration" ]; then
      printf 'fail\n%s\n%s\n' "$reason" "$duration" > "$steps_dir/${step_name}.status"
    else
      printf 'fail\n%s\n' "$reason" > "$steps_dir/${step_name}.status"
    fi
  fi
}


# Read all step status files and report results. Replaces assert_file_exists
# for E2E summaries. Returns 0 if all steps passed, 1 otherwise.
#
# Usage:
#   e2e_report_steps                           # Check existing status files only
#   e2e_report_steps step1 step2 step3         # Also verify these steps ran
#
# When expected steps are provided, any missing status files are reported as
# failures with "Step never executed". This catches false successes where
# processes are skipped due to broken dependency chains.
e2e_report_steps() {
  local steps_dir="reports/steps"
  local any_failure=0
  local expected_steps=("$@")
  local found_steps=()

  if [ ! -d "$steps_dir" ] || [ -z "$(ls "$steps_dir"/*.status 2>/dev/null)" ]; then
    echo "  No step status files found - pipeline may not have started"
    test_failed=$((test_failed + 1))
    # Still check expected steps below (they'll all be missing)
    if [ ${#expected_steps[@]} -eq 0 ]; then
      return 1
    fi
    any_failure=1
  else
    for status_file in "$steps_dir"/*.status; do
      local step_name
      step_name="$(basename "$status_file" .status)"
      found_steps+=("$step_name")
      local status
      status="$(head -1 "$status_file")"

      # Parse file content: line 1 = status, line 2+ = reason/duration
      local file_content
      file_content="$(tail -n +2 "$status_file")"

      if [ "$status" = "pass" ]; then
        # For pass: line 2 is duration (if present)
        local duration="$file_content"
        if [ -n "$duration" ]; then
          echo "  ✓ PASS: $step_name ($duration)"
        else
          echo "  ✓ PASS: $step_name"
        fi
        test_passed=$((test_passed + 1))
      else
        # For fail: line 2 is reason, line 3 is duration (if present)
        local reason duration
        reason="$(echo "$file_content" | head -1)"
        duration="$(echo "$file_content" | tail -1)"

        # If reason and duration are the same, there's no duration
        if [ "$reason" = "$duration" ]; then
          duration=""
        fi

        if [ -n "$duration" ]; then
          echo "  ✗ FAIL: $step_name ($duration)"
        else
          echo "  ✗ FAIL: $step_name"
        fi
        [ -n "$reason" ] && echo "    Reason: $reason"
        test_failed=$((test_failed + 1))
        any_failure=1
      fi
    done
  fi

  # Check for expected steps that never ran (no status file written)
  if [ ${#expected_steps[@]} -gt 0 ]; then
    for expected in "${expected_steps[@]}"; do
      local was_found=0
      for found in "${found_steps[@]+"${found_steps[@]}"}"; do
        if [ "$found" = "$expected" ]; then
          was_found=1
          break
        fi
      done
      if [ "$was_found" -eq 0 ]; then
        echo "  ✗ FAIL: $expected"
        echo "    Reason: Step never executed (process may have been skipped)"
        test_failed=$((test_failed + 1))
        any_failure=1
      fi
    done
  fi

  # List available diagnostic logs when there are failures
  if [ "$any_failure" -eq 1 ]; then
    local logs_dir="reports/logs"
    local has_logs=0
    for logfile in "$logs_dir"/*.log "$logs_dir"/*.txt; do
      [ -f "$logfile" ] || continue
      local size
      size=$(wc -c < "$logfile" | tr -d ' ')
      if [ "$size" -gt 0 ]; then
        if [ "$has_logs" -eq 0 ]; then
          echo ""
          echo "  Diagnostic logs:"
          has_logs=1
        fi
        echo "    $logfile (${size} bytes)"
      fi
    done
  fi

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
