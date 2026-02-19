#!/usr/bin/env bash
# iOS Plugin - App Bundle Auto-Detection Resolution Tests
#
# Tests for the ios_find_app() precedence chain in deploy.sh.
# These tests use temporary directories with fixture .app bundles.
# Does NOT require Xcode (xcodebuild tests are skipped).

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

# ============================================================================
# Setup
# ============================================================================

deploy_path="$script_dir/../../ios/virtenv/scripts/domain/deploy.sh"
lib_path="$script_dir/../../ios/virtenv/scripts/lib/lib.sh"
core_path="$script_dir/../../ios/virtenv/scripts/platform/core.sh"

if [ ! -f "$deploy_path" ]; then
  echo "ERROR: deploy.sh not found at: $deploy_path"
  exit 1
fi

# Source dependencies (deploy.sh must be sourced)
IOS_SCRIPTS_DIR="$script_dir/../../ios/virtenv/scripts"
export IOS_SCRIPTS_DIR
. "$deploy_path"

# Create temp project structures
TMPDIR_BASE="$(make_temp_dir "ios-app-resolution")"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# Helper to create a fake .app bundle with Info.plist
create_fake_app() {
  app_dir="$1"
  bundle_id="${2:-com.test.app}"
  mkdir -p "$app_dir"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $bundle_id" "$app_dir/Info.plist" 2>/dev/null || true
}

echo "========================================"
echo "iOS App Resolution Tests"
echo "========================================"
echo "Testing: $deploy_path"

# ============================================================================
# Tests: ios_find_app with IOS_APP_ARTIFACT env var (precedence 1)
# ============================================================================

start_test "ios_find_app - resolves via IOS_APP_ARTIFACT env var"
test_root="$TMPDIR_BASE/test1"
mkdir -p "$test_root/DerivedData/Build/Products/Debug-iphonesimulator"
create_fake_app "$test_root/DerivedData/Build/Products/Debug-iphonesimulator/MyApp.app"
IOS_APP_ARTIFACT="DerivedData/Build/Products/Debug-iphonesimulator/MyApp.app" \
  result=$(ios_find_app "$test_root" 2>/dev/null)
assert_equal "$test_root/DerivedData/Build/Products/Debug-iphonesimulator/MyApp.app" "$result" \
  "Should find app via IOS_APP_ARTIFACT relative path"

start_test "ios_find_app - resolves via IOS_APP_ARTIFACT glob"
test_root="$TMPDIR_BASE/test1b"
mkdir -p "$test_root/DerivedData/Build/Products/Debug-iphonesimulator"
create_fake_app "$test_root/DerivedData/Build/Products/Debug-iphonesimulator/MyApp.app"
IOS_APP_ARTIFACT="DerivedData/Build/Products/Debug-iphonesimulator/*.app" \
  result=$(ios_find_app "$test_root" 2>/dev/null)
assert_equal "$test_root/DerivedData/Build/Products/Debug-iphonesimulator/MyApp.app" "$result" \
  "Should find app via IOS_APP_ARTIFACT glob pattern"

start_test "ios_find_app - IOS_APP_ARTIFACT takes priority over recursive search"
test_root="$TMPDIR_BASE/test1c"
mkdir -p "$test_root/specific" "$test_root/other"
create_fake_app "$test_root/specific/Target.app" "com.test.target"
create_fake_app "$test_root/other/Decoy.app" "com.test.decoy"
IOS_APP_ARTIFACT="specific/Target.app" \
  result=$(ios_find_app "$test_root" 2>/dev/null)
assert_equal "$test_root/specific/Target.app" "$result" \
  "IOS_APP_ARTIFACT should take priority"

# ============================================================================
# Tests: ios_find_app with recursive search (precedence 3 - skipping xcodebuild)
# ============================================================================

start_test "ios_find_app - finds .app via recursive search"
test_root="$TMPDIR_BASE/test3"
mkdir -p "$test_root/Build/Products/Debug-iphonesimulator"
create_fake_app "$test_root/Build/Products/Debug-iphonesimulator/MyApp.app"
IOS_APP_ARTIFACT="" \
  result=$(ios_find_app "$test_root" 2>/dev/null)
assert_equal "$test_root/Build/Products/Debug-iphonesimulator/MyApp.app" "$result" \
  "Should find .app via recursive search"

start_test "ios_find_app - excludes Pods directory"
test_root="$TMPDIR_BASE/test3b"
mkdir -p "$test_root/Pods/SomePod" "$test_root/build"
create_fake_app "$test_root/Pods/SomePod/SomePod.app"
create_fake_app "$test_root/build/Real.app" "com.test.real"
IOS_APP_ARTIFACT="" \
  result=$(ios_find_app "$test_root" 2>/dev/null)
assert_equal "$test_root/build/Real.app" "$result" \
  "Should skip Pods directory"

start_test "ios_find_app - excludes .build directory"
test_root="$TMPDIR_BASE/test3c"
mkdir -p "$test_root/.build/artifacts" "$test_root/output"
create_fake_app "$test_root/.build/artifacts/Cached.app"
create_fake_app "$test_root/output/Real.app" "com.test.real"
IOS_APP_ARTIFACT="" \
  result=$(ios_find_app "$test_root" 2>/dev/null)
assert_equal "$test_root/output/Real.app" "$result" \
  "Should skip .build directory"

start_test "ios_find_app - excludes SourcePackages directory"
test_root="$TMPDIR_BASE/test3d"
mkdir -p "$test_root/SourcePackages/checkouts" "$test_root/build"
create_fake_app "$test_root/SourcePackages/checkouts/Dep.app"
create_fake_app "$test_root/build/Real.app" "com.test.real"
IOS_APP_ARTIFACT="" \
  result=$(ios_find_app "$test_root" 2>/dev/null)
assert_equal "$test_root/build/Real.app" "$result" \
  "Should skip SourcePackages"

start_test "ios_find_app - excludes node_modules directory"
test_root="$TMPDIR_BASE/test3e"
mkdir -p "$test_root/node_modules/some-pkg" "$test_root/build"
create_fake_app "$test_root/node_modules/some-pkg/Cached.app"
create_fake_app "$test_root/build/Real.app" "com.test.real"
IOS_APP_ARTIFACT="" \
  result=$(ios_find_app "$test_root" 2>/dev/null)
assert_equal "$test_root/build/Real.app" "$result" \
  "Should skip node_modules"

start_test "ios_find_app - excludes .devbox directory"
test_root="$TMPDIR_BASE/test3f"
mkdir -p "$test_root/.devbox/virtenv" "$test_root/build"
create_fake_app "$test_root/.devbox/virtenv/Cached.app"
create_fake_app "$test_root/build/Real.app" "com.test.real"
IOS_APP_ARTIFACT="" \
  result=$(ios_find_app "$test_root" 2>/dev/null)
assert_equal "$test_root/build/Real.app" "$result" \
  "Should skip .devbox"

start_test "ios_find_app - excludes DerivedData/ModuleCache directory"
test_root="$TMPDIR_BASE/test3g"
mkdir -p "$test_root/DerivedData/ModuleCache" "$test_root/DerivedData/Build/Products"
create_fake_app "$test_root/DerivedData/ModuleCache/Module.app"
create_fake_app "$test_root/DerivedData/Build/Products/Real.app" "com.test.real"
IOS_APP_ARTIFACT="" \
  result=$(ios_find_app "$test_root" 2>/dev/null)
assert_equal "$test_root/DerivedData/Build/Products/Real.app" "$result" \
  "Should skip DerivedData/ModuleCache"

# ============================================================================
# Tests: ios_find_app fails with clear error (precedence 5)
# ============================================================================

start_test "ios_find_app - fails when no .app found"
test_root="$TMPDIR_BASE/test5"
mkdir -p "$test_root"
IOS_APP_ARTIFACT="" \
  assert_failure "ios_find_app '$test_root'" "Should fail when no .app exists"

start_test "ios_find_app - error message includes guidance"
test_root="$TMPDIR_BASE/test5b"
mkdir -p "$test_root"
IOS_APP_ARTIFACT="" \
  error_output=$(ios_find_app "$test_root" 2>&1 || true)
assert_contains "$error_output" "No .app bundle found" "Error should mention no .app found"
assert_contains "$error_output" "IOS_APP_ARTIFACT" "Error should mention env var"

# ============================================================================
# Tests: ios_extract_bundle_id
# ============================================================================

start_test "ios_extract_bundle_id - extracts from Info.plist"
test_root="$TMPDIR_BASE/test_bundle"
create_fake_app "$test_root/MyApp.app" "com.example.myapp"
result=$(ios_extract_bundle_id "$test_root/MyApp.app" 2>/dev/null)
assert_equal "com.example.myapp" "$result" "Should extract correct bundle ID"

start_test "ios_extract_bundle_id - fails on missing Info.plist"
test_root="$TMPDIR_BASE/test_bundle_missing"
mkdir -p "$test_root/NoInfo.app"
assert_failure "ios_extract_bundle_id '$test_root/NoInfo.app'" "Should fail without Info.plist"

# ============================================================================
# Tests: ios_resolve_app_glob
# ============================================================================

start_test "ios_resolve_app_glob - finds app by exact path"
test_root="$TMPDIR_BASE/test_glob1"
create_fake_app "$test_root/build/MyApp.app"
result=$(ios_resolve_app_glob "$test_root" "build/MyApp.app")
assert_equal "$test_root/build/MyApp.app" "$result" "Should find app by exact path"

start_test "ios_resolve_app_glob - finds app by glob"
test_root="$TMPDIR_BASE/test_glob2"
create_fake_app "$test_root/build/MyApp.app"
result=$(ios_resolve_app_glob "$test_root" "build/*.app")
assert_equal "$test_root/build/MyApp.app" "$result" "Should find app by glob"

start_test "ios_resolve_app_glob - fails on no match"
test_root="$TMPDIR_BASE/test_glob3"
mkdir -p "$test_root"
assert_failure "ios_resolve_app_glob '$test_root' 'nonexistent/*.app'" "Should fail when no app matches"

# ============================================================================
# Summary
# ============================================================================

test_summary "ios-app-resolution"
