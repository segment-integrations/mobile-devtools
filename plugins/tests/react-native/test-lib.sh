#!/usr/bin/env bash
# React Native Plugin - lib.sh Unit Tests
#
# Tests for Metro port management functions in lib.sh

set -euo pipefail

# Setup logging - redirect all output to log file
SCRIPT_DIR_NAME="$(basename "$(dirname "$0")")"
SCRIPT_NAME="$(basename "$0" .sh)"
mkdir -p "${TEST_LOGS_DIR:-reports/logs}"
LOG_FILE="${TEST_LOGS_DIR:-reports/logs}/${SCRIPT_DIR_NAME}-${SCRIPT_NAME}.txt"
exec > >(tee "$LOG_FILE")
exec 2>&1

# ============================================================================
# Test Framework
# ============================================================================

test_passed=0
test_failed=0
test_name=""

start_test() {
  test_name="$1"
  echo ""
  echo "TEST: $test_name"
}

assert_equal() {
  expected="$1"
  actual="$2"
  message="${3:-}"

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
  command_str="$1"
  message="${2:-}"

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
  command_str="$1"
  message="${2:-}"

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

assert_contains() {
  haystack="$1"
  needle="$2"
  message="${3:-}"

  if echo "$haystack" | grep -q "$needle"; then
    echo "  ✓ PASS${message:+: $message}"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL${message:+: $message}"
    echo "    String '$haystack' does not contain '$needle'"
    test_failed=$((test_failed + 1))
  fi
}

test_summary() {
  total=$((test_passed + test_failed))
  echo ""
  echo "========================================"
  echo "Test Summary"
  echo "========================================"
  echo "Total:  $total"
  echo "Passed: $test_passed"
  echo "Failed: $test_failed"
  echo ""

  # Write results file for summary aggregation
  results_dir="${TEST_RESULTS_DIR:-$(cd "$(dirname "$0")/../../../reports/results" 2>/dev/null && pwd || echo "/tmp")}"
  mkdir -p "$results_dir" 2>/dev/null || true
  cat > "$results_dir/react-native-lib.json" << EOF
{
  "suite": "react-native-lib",
  "passed": $test_passed,
  "failed": $test_failed,
  "total": $total
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

# ============================================================================
# Setup
# ============================================================================

script_dir="$(cd "$(dirname "$0")" && pwd)"
lib_path="$script_dir/../../react-native/virtenv/scripts/lib/lib.sh"

if [ ! -f "$lib_path" ]; then
  echo "ERROR: lib.sh not found at: $lib_path"
  exit 1
fi

# Create temporary test environment
test_virtenv="/tmp/rn-plugin-test-$$"
mkdir -p "$test_virtenv/metro"
export REACT_NATIVE_VIRTENV="$test_virtenv"

# Source lib.sh
# shellcheck source=../../react-native/virtenv/scripts/lib/lib.sh
. "$lib_path"

echo "========================================"
echo "React Native lib.sh Unit Tests"
echo "========================================"
echo "Testing: $lib_path"
echo "Test Virtenv: $test_virtenv"

# Prepare results directory
results_base="${TEST_RESULTS_DIR:-$(cd "$script_dir/../../.." 2>/dev/null && pwd)/reports/results}"
mkdir -p "$results_base"

# ============================================================================
# Tests: Port Allocation
# ============================================================================

start_test "rn_find_available_port - finds port in range"
port=$(rn_find_available_port 8091 8199)
assert_success "[ -n '$port' ]" "Should return non-empty port"
assert_success "[ '$port' -ge 8091 ]" "Port should be >= 8091"
assert_success "[ '$port' -le 8199 ]" "Port should be <= 8199"

start_test "rn_allocate_metro_port - allocates port"
port=$(rn_allocate_metro_port "test1")
assert_success "[ -n '$port' ]" "Should return non-empty port"
# Port file uses run-id in name: port-{suite}-{run_id}.txt
assert_success "ls '$test_virtenv/metro/port-test1-'*.txt >/dev/null 2>&1" "Should create port file with run-id"

start_test "rn_allocate_metro_port - creates suite-specific port file"
port1=$(rn_allocate_metro_port "android")
port2=$(rn_allocate_metro_port "ios")
assert_success "ls '$test_virtenv/metro/port-android-'*.txt >/dev/null 2>&1" "Should create android port file"
assert_success "ls '$test_virtenv/metro/port-ios-'*.txt >/dev/null 2>&1" "Should create ios port file"

start_test "rn_allocate_metro_port - reuses allocated port"
port1=$(rn_allocate_metro_port "test2")
port2=$(rn_allocate_metro_port "test2")
assert_equal "$port1" "$port2" "Should return same port when called twice"

start_test "rn_get_metro_port - retrieves allocated port"
allocated_port=$(rn_allocate_metro_port "test3")
retrieved_port=$(rn_get_metro_port "test3")
assert_equal "$allocated_port" "$retrieved_port" "Should retrieve same port that was allocated"

start_test "rn_get_metro_port - allocates if not exists"
port=$(rn_get_metro_port "test4")
assert_success "[ -n '$port' ]" "Should allocate new port if none exists"
assert_success "ls '$test_virtenv/metro/port-test4-'*.txt >/dev/null 2>&1" "Should create port file"

# ============================================================================
# Tests: Metro Environment Files
# ============================================================================

start_test "rn_save_metro_env - creates environment file"
env_file=$(rn_save_metro_env "test5" "8095")
assert_success "[ -f '$env_file' ]" "Should create environment file"
# Env file uses run-id: env-{suite}-{run_id}.sh, with symlink at env-{suite}.sh
assert_success "[ -L '$test_virtenv/metro/env-test5.sh' ]" "Should create symlink at simple name"

start_test "rn_save_metro_env - sets correct variables"
env_file_test6=$(rn_save_metro_env "test6" "8096")
env_content=$(cat "$env_file_test6")
assert_contains "$env_content" "RCT_METRO_PORT=\"8096\"" "Should set RCT_METRO_PORT"
assert_contains "$env_content" "METRO_PORT=\"8096\"" "Should set METRO_PORT"
assert_contains "$env_content" "REACT_NATIVE_PACKAGER_HOSTNAME=\"localhost\"" "Should set hostname"

start_test "rn_save_metro_env - file is executable"
env_file_test7=$(rn_save_metro_env "test7" "8097")
assert_success "[ -x '$env_file_test7' ]" "Environment file should be executable"

start_test "rn_export_metro_env - exports variables"
test_port="8098"
rn_save_metro_env "test8" "$test_port" >/dev/null
# Create port file to match
echo "$test_port" > "$test_virtenv/metro/port-test8.txt"
unset RCT_METRO_PORT METRO_PORT REACT_NATIVE_PACKAGER_HOSTNAME
rn_export_metro_env "test8"
assert_equal "$test_port" "$METRO_PORT" "Should export METRO_PORT"
assert_equal "$test_port" "$RCT_METRO_PORT" "Should export RCT_METRO_PORT"
assert_equal "localhost" "$REACT_NATIVE_PACKAGER_HOSTNAME" "Should export hostname"

# ============================================================================
# Tests: Metro Cleanup
# ============================================================================

start_test "rn_clean_metro - removes port file"
rn_allocate_metro_port "test9" >/dev/null
rn_clean_metro "test9"
assert_success "! ls '$test_virtenv/metro/port-test9-'*.txt >/dev/null 2>&1" "Should remove port file"

start_test "rn_clean_metro - removes env file"
rn_save_metro_env "test10" "8099" >/dev/null
rn_clean_metro "test10"
assert_success "[ ! -L '$test_virtenv/metro/env-test10.sh' ]" "Should remove env symlink"

start_test "rn_clean_metro - handles missing files gracefully"
assert_success "rn_clean_metro 'nonexistent'" "Should not fail on nonexistent suite"

# ============================================================================
# Tests: PID Tracking
# ============================================================================

start_test "rn_track_metro_pid - creates pid file"
rn_track_metro_pid "test11" "12345"
assert_success "ls '$test_virtenv/metro/pid-test11-'*.txt >/dev/null 2>&1" "Should create pid file with run-id"

start_test "rn_track_metro_pid - stores correct pid"
rn_track_metro_pid "test12" "67890"
pid_file_test12=$(ls "$test_virtenv/metro/pid-test12-"*.txt 2>/dev/null | head -1)
stored_pid=$(cat "$pid_file_test12")
assert_equal "67890" "$stored_pid" "Should store correct PID"

start_test "rn_get_metro_pid - retrieves stored pid"
rn_track_metro_pid "test13" "11111"
retrieved_pid=$(rn_get_metro_pid "test13")
assert_equal "11111" "$retrieved_pid" "Should retrieve correct PID"

start_test "rn_get_metro_pid - fails when no pid tracked"
assert_failure "rn_get_metro_pid 'nonexistent'" "Should fail when PID not tracked"

start_test "rn_stop_metro - handles nonexistent pid gracefully"
assert_success "rn_stop_metro 'nonexistent'" "Should not fail when no PID tracked"

# ============================================================================
# Tests: Suite Isolation
# ============================================================================

start_test "Suite isolation - separate port files per suite"
rn_allocate_metro_port "android" >/dev/null
rn_allocate_metro_port "ios" >/dev/null
rn_allocate_metro_port "all" >/dev/null
assert_success "ls '$test_virtenv/metro/port-android-'*.txt >/dev/null 2>&1" "Android port file should exist"
assert_success "ls '$test_virtenv/metro/port-ios-'*.txt >/dev/null 2>&1" "iOS port file should exist"
assert_success "ls '$test_virtenv/metro/port-all-'*.txt >/dev/null 2>&1" "All port file should exist"

start_test "Suite isolation - separate env files per suite"
rn_save_metro_env "android" "8100" >/dev/null
rn_save_metro_env "ios" "8101" >/dev/null
rn_save_metro_env "all" "8102" >/dev/null
assert_success "[ -f '$test_virtenv/metro/env-android.sh' ]" "Android env file should exist"
assert_success "[ -f '$test_virtenv/metro/env-ios.sh' ]" "iOS env file should exist"
assert_success "[ -f '$test_virtenv/metro/env-all.sh' ]" "All env file should exist"

start_test "Suite isolation - env files contain correct ports"
android_env_port=$(grep "^export METRO_PORT=" "$test_virtenv/metro/env-android.sh" | cut -d'"' -f2)
ios_env_port=$(grep "^export METRO_PORT=" "$test_virtenv/metro/env-ios.sh" | cut -d'"' -f2)
all_env_port=$(grep "^export METRO_PORT=" "$test_virtenv/metro/env-all.sh" | cut -d'"' -f2)
assert_equal "8100" "$android_env_port" "Android env file should have port 8100"
assert_equal "8101" "$ios_env_port" "iOS env file should have port 8101"
assert_equal "8102" "$all_env_port" "All env file should have port 8102"

start_test "Suite isolation - clean one suite doesn't affect others"
rn_clean_metro "android"
assert_success "! ls '$test_virtenv/metro/port-android-'*.txt >/dev/null 2>&1" "Android port file should be removed"
assert_success "[ ! -L '$test_virtenv/metro/env-android.sh' ]" "Android env symlink should be removed"
assert_success "ls '$test_virtenv/metro/port-ios-'*.txt >/dev/null 2>&1" "iOS port file should still exist"
assert_success "[ -L '$test_virtenv/metro/env-ios.sh' ]" "iOS env symlink should still exist"

# ============================================================================
# Cleanup and Summary
# ============================================================================

# Cleanup test environment
rm -rf "$test_virtenv"

test_summary
