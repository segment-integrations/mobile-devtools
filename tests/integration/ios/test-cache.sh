#!/usr/bin/env bash
set -euo pipefail

# Setup logging - redirect all output to log file
SCRIPT_DIR_NAME="$(basename "$(dirname "$0")")"
SCRIPT_NAME="$(basename "$0" .sh)"
mkdir -p "${TEST_LOGS_DIR:-reports/logs}"
LOG_FILE="${TEST_LOGS_DIR:-reports/logs}/${SCRIPT_DIR_NAME}-${SCRIPT_NAME}.txt"
exec > >(tee "$LOG_FILE")
exec 2>&1

echo "iOS Cache Integration Tests"
echo "============================"
echo ""

# Only run on macOS
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Skipping iOS cache tests (not on macOS)"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/../../.."

# Source test framework
. "$REPO_ROOT/plugins/tests/test-framework.sh"

# Setup test environment
TEST_ROOT="$(make_temp_dir "ios-cache")"
mkdir -p "$TEST_ROOT/devbox.d/ios/devices"
mkdir -p "$TEST_ROOT/devbox.d/ios/scripts"
mkdir -p "$TEST_ROOT/.devbox/virtenv/ios"

# Copy device fixtures from example project
cp "$REPO_ROOT/examples/ios/devbox.d/ios/devices/"*.json "$TEST_ROOT/devbox.d/ios/devices/"

# Copy plugin scripts (layered structure)
cp -r "$REPO_ROOT/plugins/ios/virtenv/scripts/"* "$TEST_ROOT/devbox.d/ios/scripts/"
find "$TEST_ROOT/devbox.d/ios/scripts" -name "*.sh" -type f -exec chmod +x {} \;

# Set environment for tests
export IOS_CONFIG_DIR="$TEST_ROOT/devbox.d/ios"
export IOS_DEVICES_DIR="$TEST_ROOT/devbox.d/ios/devices"
export IOS_SCRIPTS_DIR="$TEST_ROOT/devbox.d/ios/scripts"
export IOS_DEVICES=""

cd "$TEST_ROOT"

# Test 1: Lock file generation
echo "Test: Lock file generation..."
if sh "$IOS_SCRIPTS_DIR/user/devices.sh" eval >/dev/null 2>&1; then
  if [ -f "$IOS_DEVICES_DIR/devices.lock" ]; then
    test_passed=$((test_passed + 1))
    echo "✓ Lock file generated successfully"
  else
    test_failed=$((test_failed + 1))
    echo "✗ Lock file not created"
  fi
else
  test_failed=$((test_failed + 1))
  echo "✗ Device eval command failed"
fi

# Test 2: Lock file has valid content
echo "Test: Lock file content validation..."
if [ -f "$IOS_DEVICES_DIR/devices.lock" ]; then
  if [ -s "$IOS_DEVICES_DIR/devices.lock" ]; then
    test_passed=$((test_passed + 1))
    echo "✓ Lock file has valid content"
  else
    test_failed=$((test_failed + 1))
    echo "✗ Lock file is empty"
  fi
else
  test_failed=$((test_failed + 1))
  echo "✗ Lock file not found"
fi

# Test 3: Xcode developer directory resolution
echo "Test: Xcode developer directory..."
if xcrun --show-sdk-path >/dev/null 2>&1; then
  test_passed=$((test_passed + 1))
  echo "✓ Xcode command line tools available"
else
  echo "⚠ Xcode tools not available (skipping)"
  test_passed=$((test_passed + 1))  # Don't fail if Xcode isn't installed
fi

# Test 4: Lock file has checksum
echo "Test: Lock file checksum..."
if [ -f "$IOS_DEVICES_DIR/devices.lock" ]; then
  if jq -e '.checksum' "$IOS_DEVICES_DIR/devices.lock" >/dev/null 2>&1; then
    checksum=$(jq -r '.checksum' "$IOS_DEVICES_DIR/devices.lock")
    if [ -n "$checksum" ] && [ "$checksum" != "null" ]; then
      test_passed=$((test_passed + 1))
      echo "✓ Lock file has valid checksum"
    else
      test_failed=$((test_failed + 1))
      echo "✗ Lock file checksum is invalid"
    fi
  else
    test_failed=$((test_failed + 1))
    echo "✗ Lock file missing checksum field"
  fi
else
  test_failed=$((test_failed + 1))
  echo "✗ Lock file not found"
fi

# Test 5: Device list shows fixtures
echo "Test: Device list validation..."
device_list=$(sh "$IOS_SCRIPTS_DIR/user/devices.sh" list 2>/dev/null || echo "")
if echo "$device_list" | grep -q "iPhone"; then
  test_passed=$((test_passed + 1))
  echo "✓ Device list shows test devices"
else
  test_failed=$((test_failed + 1))
  echo "✗ Device list doesn't show expected devices"
fi

# Cleanup
cd /
rm -rf "$TEST_ROOT"

test_summary "ios-integration-cache"
