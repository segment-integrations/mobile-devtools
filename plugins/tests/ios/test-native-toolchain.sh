#!/usr/bin/env bash
# iOS Plugin - Native Toolchain Isolation Tests
#
# Verifies that ios_setup_native_toolchain() properly strips Nix stdenv
# build environment variables so Xcode/clang uses Apple's native toolchain.
#
# Background: Nix's mkShell sets ~80 build variables (CC, NIX_CFLAGS_COMPILE,
# DEVELOPER_DIR pointing to Nix's apple-sdk, etc.) that break xcodebuild when
# targeting iOS Simulator. The native toolchain function must strip these.

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
. "$script_dir/../test-framework.sh"
setup_logging

echo "========================================"
echo "iOS Native Toolchain Isolation"
echo "========================================"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Skipping (not macOS)"
  exit 0
fi

ios_example="$script_dir/../../../examples/ios"

if [ ! -d "$ios_example" ]; then
  echo "Skipping (examples/ios not found)"
  exit 0
fi

# Use project-local scratch dir for test artifacts
scratch_dir="${REPO_ROOT}/reports/scratch/native-toolchain"
mkdir -p "$scratch_dir"

# ============================================================================
# Setup: Load raw Nix environment (devbox shellenv without init_hooks)
# ============================================================================

# shellenv sets all Nix stdenv variables without running plugin init_hooks,
# giving us the "polluted" state that ios_setup_native_toolchain() must fix.
eval "$(cd "$ios_example" && devbox shellenv 2>/dev/null)"

# ============================================================================
# Phase 1: Verify Nix stdenv pollution is present (before cleanup)
# ============================================================================

start_test "Nix stdenv sets NIX_CFLAGS_COMPILE"
assert_not_empty "${NIX_CFLAGS_COMPILE:-}" "NIX_CFLAGS_COMPILE should be set by Nix stdenv"

start_test "Nix stdenv sets NIX_LDFLAGS"
assert_not_empty "${NIX_LDFLAGS:-}" "NIX_LDFLAGS should be set by Nix stdenv"

start_test "Nix stdenv sets NIX_CC to Nix clang wrapper"
assert_contains "${NIX_CC:-}" "/nix/store/" "NIX_CC should point to Nix store"

start_test "Nix stdenv sets DEVELOPER_DIR to Nix apple-sdk"
assert_contains "${DEVELOPER_DIR:-}" "/nix/store/" "DEVELOPER_DIR should point to Nix SDK"

start_test "Nix clang wrapper is first in PATH"
clang_path="$(command -v clang 2>/dev/null || true)"
assert_contains "${clang_path:-}" "/nix/store/" "clang should resolve to Nix wrapper"

# If iOS Simulator SDK is available, verify Nix clang warns about cross-compilation
SIM_SDK=$(/usr/bin/xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null || true)
if [ -n "$SIM_SDK" ]; then
  test_c="$scratch_dir/test_uint8.c"
  cat > "$test_c" << 'EOF'
#include <stdint.h>
int main(void) { uint8_t x = 42; return (int)x - 42; }
EOF

  start_test "Nix clang wrapper warns about iOS cross-compilation"
  nix_output="$(clang -isysroot "$SIM_SDK" -target arm64-apple-ios17.0-simulator \
    -c "$test_c" -o /dev/null 2>&1 || true)"
  assert_contains "$nix_output" "nix-wrapped compiler" \
    "Nix wrapper should warn about cross-target compilation"
fi

# ============================================================================
# Phase 2: Apply native toolchain cleanup
# ============================================================================

# Reset one-shot guards so we can apply the cleanup in this shell
unset IOS_NATIVE_TOOLCHAIN_APPLIED
unset IOS_CORE_LOADED IOS_CORE_LOADED_PID

export IOS_SCRIPTS_DIR="$ios_example/.devbox/virtenv/ios/scripts"
. "$IOS_SCRIPTS_DIR/lib/lib.sh"
. "$IOS_SCRIPTS_DIR/platform/core.sh"
ios_setup_native_toolchain

# ============================================================================
# Phase 3: Verify Nix stdenv pollution is gone (after cleanup)
# ============================================================================

start_test "NIX_CFLAGS_COMPILE is unset after cleanup"
assert_equal "" "${NIX_CFLAGS_COMPILE:-}" "NIX_CFLAGS_COMPILE should be empty"

start_test "NIX_LDFLAGS is unset after cleanup"
assert_equal "" "${NIX_LDFLAGS:-}" "NIX_LDFLAGS should be empty"

start_test "NIX_CC is unset after cleanup"
assert_equal "" "${NIX_CC:-}" "NIX_CC should be empty"

start_test "NIX_HARDENING_ENABLE is unset after cleanup"
assert_equal "" "${NIX_HARDENING_ENABLE:-}" "NIX_HARDENING_ENABLE should be empty"

start_test "NIX_APPLE_SDK_VERSION is unset after cleanup"
assert_equal "" "${NIX_APPLE_SDK_VERSION:-}" "NIX_APPLE_SDK_VERSION should be empty"

start_test "SDKROOT is unset after cleanup"
assert_equal "" "${SDKROOT:-}" "SDKROOT should be empty (let Xcode resolve)"

start_test "MACOSX_DEPLOYMENT_TARGET is unset after cleanup"
assert_equal "" "${MACOSX_DEPLOYMENT_TARGET:-}" "MACOSX_DEPLOYMENT_TARGET should be empty"

start_test "CC points to /usr/bin/clang"
assert_equal "/usr/bin/clang" "${CC:-}" "CC should be system clang"

start_test "CXX points to /usr/bin/clang++"
assert_equal "/usr/bin/clang++" "${CXX:-}" "CXX should be system clang++"

start_test "DEVELOPER_DIR does not point to Nix store"
if echo "${DEVELOPER_DIR:-unset}" | grep -q "/nix/store/"; then
  echo "  ✗ FAIL: DEVELOPER_DIR still points to Nix: ${DEVELOPER_DIR}"
  test_failed=$((test_failed + 1))
else
  echo "  ✓ PASS: DEVELOPER_DIR=${DEVELOPER_DIR:-unset}"
  test_passed=$((test_passed + 1))
fi

start_test "clang resolves to /usr/bin/clang (not Nix wrapper)"
clang_after="$(command -v clang 2>/dev/null || true)"
assert_equal "/usr/bin/clang" "$clang_after" "clang should be system binary"

start_test "No Nix clang-wrapper paths in PATH"
if echo "$PATH" | tr ':' '\n' | grep -q "clang-wrapper"; then
  echo "  ✗ FAIL: PATH still contains clang-wrapper"
  echo "    $(echo "$PATH" | tr ':' '\n' | grep "clang-wrapper")"
  test_failed=$((test_failed + 1))
else
  echo "  ✓ PASS: No clang-wrapper in PATH"
  test_passed=$((test_passed + 1))
fi

start_test "No Nix cctools paths in PATH"
if echo "$PATH" | tr ':' '\n' | grep -q "cctools"; then
  echo "  ✗ FAIL: PATH still contains cctools"
  test_failed=$((test_failed + 1))
else
  echo "  ✓ PASS: No cctools in PATH"
  test_passed=$((test_passed + 1))
fi

start_test "No Nix xcbuild paths in PATH"
if echo "$PATH" | tr ':' '\n' | grep -q "xcbuild"; then
  echo "  ✗ FAIL: PATH still contains xcbuild"
  test_failed=$((test_failed + 1))
else
  echo "  ✓ PASS: No xcbuild in PATH"
  test_passed=$((test_passed + 1))
fi

start_test "Build tool vars unset (AR, AS, LD, NM)"
all_unset=true
for var in AR AS LD NM OBJCOPY OBJDUMP RANLIB SIZE STRINGS STRIP; do
  val="$(eval "printf '%s' \"\${$var:-}\"")"
  if [ -n "$val" ]; then
    echo "  ✗ $var still set: $val"
    all_unset=false
  fi
done
if $all_unset; then
  echo "  ✓ PASS: All build tool vars unset"
  test_passed=$((test_passed + 1))
else
  echo "  ✗ FAIL: Some build tool vars still set"
  test_failed=$((test_failed + 1))
fi

# If iOS Simulator SDK is available, verify clean compilation
if [ -n "$SIM_SDK" ] && [ -f "$scratch_dir/test_uint8.c" ]; then
  start_test "iOS Simulator compilation succeeds after cleanup"
  compile_out="$(clang -isysroot "$SIM_SDK" -target arm64-apple-ios17.0-simulator \
    -c "$scratch_dir/test_uint8.c" -o "$scratch_dir/test_uint8.o" 2>&1)"
  compile_exit=$?
  if [ $compile_exit -eq 0 ]; then
    echo "  ✓ PASS: Compilation succeeded (exit 0)"
    test_passed=$((test_passed + 1))
  else
    echo "  ✗ FAIL: Compilation failed (exit $compile_exit)"
    echo "    $compile_out"
    test_failed=$((test_failed + 1))
  fi

  start_test "No Nix wrapper warnings in compilation output"
  if echo "$compile_out" | grep -q "nix-wrapped"; then
    echo "  ✗ FAIL: Nix wrapper warning still present"
    echo "    $compile_out"
    test_failed=$((test_failed + 1))
  else
    echo "  ✓ PASS: No Nix wrapper warnings"
    test_passed=$((test_passed + 1))
  fi
fi

# Cleanup scratch
rm -rf "$scratch_dir"

# Summary
test_summary
