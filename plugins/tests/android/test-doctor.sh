#!/usr/bin/env bash
# Android Plugin - Doctor Command Tests
# Tests for doctor.sh health check functionality

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "Android Doctor Command Tests"
echo "========================================"
echo ""

# ============================================================================
# Setup
# ============================================================================

test_root=$(make_temp_dir "android-doctor-test")
mkdir -p "$test_root/scripts/lib"
mkdir -p "$test_root/scripts/user"
mkdir -p "$test_root/devices"

# Copy required scripts
cp "$script_dir/../../android/virtenv/scripts/lib/doctor.sh" "$test_root/scripts/lib/"
cp "$script_dir/../../android/virtenv/scripts/lib/lib.sh" "$test_root/scripts/lib/"
cp "$script_dir/../../android/virtenv/scripts/user/doctor.sh" "$test_root/scripts/user/"

# Set environment variables
export ANDROID_CONFIG_DIR="$test_root"
export ANDROID_DEVICES_DIR="$test_root/devices"
export ANDROID_SCRIPTS_DIR="$test_root/scripts"
export ANDROID_SDK_ROOT="$test_root/fake-sdk"
export ANDROID_HOME="$test_root/fake-sdk"
export ANDROID_AVD_HOME="$test_root/avd"

# Create fake SDK directory
mkdir -p "$ANDROID_SDK_ROOT"

# ============================================================================
# Test: Doctor script exists and is executable
# ============================================================================

echo "TEST: Doctor script exists"
assert_success "[ -f '$test_root/scripts/user/doctor.sh' ]" "Doctor script exists"
assert_success "[ -x '$test_root/scripts/user/doctor.sh' ]" "Doctor script is executable"

# ============================================================================
# Test: Doctor library can be sourced
# ============================================================================

echo ""
echo "TEST: Doctor library can be sourced"
assert_success ". '$test_root/scripts/lib/doctor.sh'" "Doctor library sources successfully"

# ============================================================================
# Test: Doctor init function works
# ============================================================================

echo ""
echo "TEST: Doctor init function"
assert_success "doctor_init" "doctor_init runs without error"
assert_success "[ \"\$DOCTOR_CHECKS_PASSED\" -eq 0 ]" "Counters initialized to zero"

# ============================================================================
# Test: Doctor check functions work
# ============================================================================

echo ""
echo "TEST: Doctor check functions"

doctor_init
doctor_check_pass "Test check"
assert_success "[ \"\$DOCTOR_CHECKS_PASSED\" -eq 1 ]" "Pass counter increments"

doctor_check_warn "Test warning" "Test message"
assert_success "[ \"\$DOCTOR_CHECKS_WARNED\" -eq 1 ]" "Warn counter increments"

doctor_check_error "Test error" "Test message"
assert_success "[ \"\$DOCTOR_CHECKS_ERRORED\" -eq 1 ]" "Error counter increments"

# ============================================================================
# Test: Exit code calculation
# ============================================================================

echo ""
echo "TEST: Exit code calculation"

doctor_init
doctor_check_pass "Test"
exit_code=$(doctor_get_exit_code)
assert_success "[ \"$exit_code\" -eq 0 ]" "Exit code 0 for all passed"

doctor_init
doctor_check_warn "Test" "msg"
exit_code=$(doctor_get_exit_code)
assert_success "[ \"$exit_code\" -eq 1 ]" "Exit code 1 for warnings"

doctor_init
doctor_check_error "Test" "msg"
exit_code=$(doctor_get_exit_code)
assert_success "[ \"$exit_code\" -eq 2 ]" "Exit code 2 for errors"

# ============================================================================
# Test: Full doctor script execution
# ============================================================================

echo ""
echo "TEST: Full doctor script execution"

# Doctor should run and produce output
output=$(bash "$test_root/scripts/user/doctor.sh" 2>&1 || true)
assert_success "echo \"\$output\" | grep -q 'Android Environment Check'" "Doctor produces expected output"

echo ""
echo "========================================"
echo "  ✓ All Android doctor tests passed"
echo "========================================"
echo ""
