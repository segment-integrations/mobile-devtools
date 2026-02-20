#!/usr/bin/env bash
# Android Plugin - APK Auto-Detection Resolution Tests
#
# Tests for the android_find_apk() precedence chain in deploy.sh.
# These tests use temporary directories with fixture APKs.

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

# ============================================================================
# Setup
# ============================================================================

deploy_path="$script_dir/../../android/virtenv/scripts/domain/deploy.sh"
lib_path="$script_dir/../../android/virtenv/scripts/lib/lib.sh"
core_path="$script_dir/../../android/virtenv/scripts/platform/core.sh"

if [ ! -f "$deploy_path" ]; then
  echo "ERROR: deploy.sh not found at: $deploy_path"
  exit 1
fi

# Source dependencies
. "$lib_path"
. "$core_path"
. "$deploy_path"

# Create temp project structures
TMPDIR_BASE="$(make_temp_dir "android-apk-resolution")"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo "========================================"
echo "Android APK Resolution Tests"
echo "========================================"
echo "Testing: $deploy_path"

# ============================================================================
# Tests: android_find_apk with ANDROID_APP_APK env var (precedence 1)
# ============================================================================

start_test "android_find_apk - resolves via ANDROID_APP_APK env var"
test_root="$TMPDIR_BASE/test1"
mkdir -p "$test_root/app/build/outputs/apk/debug"
touch "$test_root/app/build/outputs/apk/debug/app-debug.apk"
ANDROID_APP_APK="app/build/outputs/apk/debug/app-debug.apk" \
  result=$(android_find_apk "$test_root" 2>/dev/null)
assert_equal "$test_root/app/build/outputs/apk/debug/app-debug.apk" "$result" \
  "Should find APK via ANDROID_APP_APK relative path"

start_test "android_find_apk - resolves via ANDROID_APP_APK glob"
test_root="$TMPDIR_BASE/test1b"
mkdir -p "$test_root/app/build/outputs/apk/debug"
touch "$test_root/app/build/outputs/apk/debug/app-debug.apk"
ANDROID_APP_APK="app/build/outputs/apk/debug/*.apk" \
  result=$(android_find_apk "$test_root" 2>/dev/null)
assert_equal "$test_root/app/build/outputs/apk/debug/app-debug.apk" "$result" \
  "Should find APK via ANDROID_APP_APK glob pattern"

start_test "android_find_apk - ANDROID_APP_APK takes priority over recursive search"
test_root="$TMPDIR_BASE/test1c"
mkdir -p "$test_root/specific" "$test_root/other"
touch "$test_root/specific/target.apk"
touch "$test_root/other/decoy.apk"
ANDROID_APP_APK="specific/target.apk" \
  result=$(android_find_apk "$test_root" 2>/dev/null)
assert_equal "$test_root/specific/target.apk" "$result" \
  "ANDROID_APP_APK should take priority"

# ============================================================================
# Tests: android_find_apk with recursive search (precedence 2)
# ============================================================================

start_test "android_find_apk - finds APK via recursive search"
test_root="$TMPDIR_BASE/test2"
mkdir -p "$test_root/app/build/outputs/apk/debug"
touch "$test_root/app/build/outputs/apk/debug/app-debug.apk"
ANDROID_APP_APK="" \
  result=$(android_find_apk "$test_root" 2>/dev/null)
assert_equal "$test_root/app/build/outputs/apk/debug/app-debug.apk" "$result" \
  "Should find APK via recursive search"

start_test "android_find_apk - excludes .gradle directory"
test_root="$TMPDIR_BASE/test2b"
mkdir -p "$test_root/.gradle/caches" "$test_root/app/build/outputs"
touch "$test_root/.gradle/caches/cached.apk"
touch "$test_root/app/build/outputs/real.apk"
ANDROID_APP_APK="" \
  result=$(android_find_apk "$test_root" 2>/dev/null)
assert_equal "$test_root/app/build/outputs/real.apk" "$result" \
  "Should skip .gradle directory"

start_test "android_find_apk - excludes build/intermediates directory"
test_root="$TMPDIR_BASE/test2c"
mkdir -p "$test_root/build/intermediates/apk" "$test_root/build/outputs"
touch "$test_root/build/intermediates/apk/intermediate.apk"
touch "$test_root/build/outputs/final.apk"
ANDROID_APP_APK="" \
  result=$(android_find_apk "$test_root" 2>/dev/null)
assert_equal "$test_root/build/outputs/final.apk" "$result" \
  "Should skip build/intermediates"

start_test "android_find_apk - excludes node_modules directory"
test_root="$TMPDIR_BASE/test2d"
mkdir -p "$test_root/node_modules/some-pkg" "$test_root/android/app"
touch "$test_root/node_modules/some-pkg/bundled.apk"
touch "$test_root/android/app/app.apk"
ANDROID_APP_APK="" \
  result=$(android_find_apk "$test_root" 2>/dev/null)
assert_equal "$test_root/android/app/app.apk" "$result" \
  "Should skip node_modules"

start_test "android_find_apk - excludes .devbox directory"
test_root="$TMPDIR_BASE/test2e"
mkdir -p "$test_root/.devbox/virtenv" "$test_root/app"
touch "$test_root/.devbox/virtenv/cached.apk"
touch "$test_root/app/real.apk"
ANDROID_APP_APK="" \
  result=$(android_find_apk "$test_root" 2>/dev/null)
assert_equal "$test_root/app/real.apk" "$result" \
  "Should skip .devbox"

# ============================================================================
# Tests: android_find_apk fails with clear error (precedence 4)
# ============================================================================

start_test "android_find_apk - fails when no APK found"
test_root="$TMPDIR_BASE/test4"
mkdir -p "$test_root"
# Run from a clean dir so $PWD fallback search doesn't find fixture APKs
(cd "$test_root" && ANDROID_APP_APK="" \
  assert_failure "android_find_apk '$test_root'" "Should fail when no APK exists")

start_test "android_find_apk - error message includes guidance"
test_root="$TMPDIR_BASE/test4b"
mkdir -p "$test_root"
# Run from a clean dir so $PWD fallback search doesn't find fixture APKs
error_output=$(cd "$test_root" && ANDROID_APP_APK="" android_find_apk "$test_root" 2>&1 || true)
assert_contains "$error_output" "No APK found" "Error should mention no APK found"
assert_contains "$error_output" "ANDROID_APP_APK" "Error should mention env var"

# ============================================================================
# Summary
# ============================================================================

test_summary "android-apk-resolution"
