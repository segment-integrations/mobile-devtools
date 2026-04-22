#!/usr/bin/env bash
# React Native Plugin - Doctor Command Tests
# Tests for doctor.sh health check functionality

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "React Native Doctor Command Tests"
echo "========================================"
echo ""

# ============================================================================
# Setup
# ============================================================================

test_root=$(make_temp_dir "rn-doctor-test")
mkdir -p "$test_root/scripts/lib"
mkdir -p "$test_root/scripts/user"

# Copy required scripts
cp "$script_dir/../../react-native/virtenv/scripts/lib/doctor.sh" "$test_root/scripts/lib/"
cp "$script_dir/../../react-native/virtenv/scripts/user/doctor.sh" "$test_root/scripts/user/"

# Set environment variables
export RN_SCRIPTS_DIR="$test_root/scripts"
export ANDROID_SKIP_SETUP=1
export IOS_SKIP_SETUP=1

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
# Test: RN-specific check functions exist
# ============================================================================

echo ""
echo "TEST: RN-specific functions exist"

assert_success "type rn_check_node_version >/dev/null 2>&1" "rn_check_node_version function exists"
assert_success "type rn_check_package_json >/dev/null 2>&1" "rn_check_package_json function exists"
assert_success "type rn_check_node_modules >/dev/null 2>&1" "rn_check_node_modules function exists"
assert_success "type rn_check_metro_port >/dev/null 2>&1" "rn_check_metro_port function exists"

# ============================================================================
# Test: Full doctor script execution
# ============================================================================

echo ""
echo "TEST: Full doctor script execution"

# Doctor should run and produce output (with platforms skipped)
output=$(bash "$test_root/scripts/user/doctor.sh" 2>&1 || true)
assert_success "echo \"\$output\" | grep -q 'React Native Environment Check'" "Doctor produces expected output"

echo ""
echo "========================================"
echo "  ✓ All React Native doctor tests passed"
echo "========================================"
echo ""
