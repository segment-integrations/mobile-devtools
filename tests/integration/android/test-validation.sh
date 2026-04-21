#!/usr/bin/env bash
set -euo pipefail

# Setup logging - redirect all output to log file
SCRIPT_DIR_NAME="$(basename "$(dirname "$0")")"
SCRIPT_NAME="$(basename "$0" .sh)"
mkdir -p "${TEST_LOGS_DIR:-reports/logs}"
LOG_FILE="${TEST_LOGS_DIR:-reports/logs}/${SCRIPT_DIR_NAME}-${SCRIPT_NAME}.txt"
exec > >(tee "$LOG_FILE")
exec 2>&1

echo "Android Validation Integration Tests"
echo "====================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/../../.."

# Source test framework
. "$REPO_ROOT/plugins/tests/test-framework.sh"

# Setup test environment
TEST_ROOT="$(make_temp_dir "android-validation")"
mkdir -p "$TEST_ROOT/devbox.d/android/devices"
mkdir -p "$TEST_ROOT/devbox.d/android/scripts"

# Copy device fixtures from example project
cp "$REPO_ROOT/examples/android/devbox.d/android/devices/"*.json "$TEST_ROOT/devbox.d/android/devices/"

# Copy plugin scripts
cp -r "$REPO_ROOT/plugins/android/virtenv/scripts/"* "$TEST_ROOT/devbox.d/android/scripts/"
find "$TEST_ROOT/devbox.d/android/scripts" -name "*.sh" -type f -exec chmod +x {} +

# Set environment for tests
export ANDROID_CONFIG_DIR="$TEST_ROOT/devbox.d/android"
export ANDROID_DEVICES_DIR="$TEST_ROOT/devbox.d/android/devices"
export ANDROID_SCRIPTS_DIR="$TEST_ROOT/devbox.d/android/scripts"
export ANDROID_DEVICES=""
export ANDROID_SDK_ROOT="/tmp/fake-sdk"
export ANDROID_DEFAULT_DEVICE="medium_phone_api36"

cd "$TEST_ROOT"

# Test 1: Lock file generation
echo "Test: Lock file generation..."
if sh "$ANDROID_SCRIPTS_DIR/user/devices.sh" eval >/dev/null 2>&1; then
  if [ -f "$ANDROID_DEVICES_DIR/devices.lock" ]; then
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
if [ -f "$ANDROID_DEVICES_DIR/devices.lock" ]; then
  if [ -s "$ANDROID_DEVICES_DIR/devices.lock" ]; then
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

# Test 3: Lock file has checksum
echo "Test: Lock file checksum..."
if [ -f "$ANDROID_DEVICES_DIR/devices.lock" ]; then
  if jq -e '.checksum' "$ANDROID_DEVICES_DIR/devices.lock" >/dev/null 2>&1; then
    checksum=$(jq -r '.checksum' "$ANDROID_DEVICES_DIR/devices.lock")
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

# Test 4: Device list shows fixtures
echo "Test: Device list validation..."
device_list=$(sh "$ANDROID_SCRIPTS_DIR/user/devices.sh" list 2>/dev/null || echo "")
if echo "$device_list" | grep -q "pixel_api24"; then
  test_passed=$((test_passed + 1))
  echo "✓ Device list shows test devices"
else
  test_failed=$((test_failed + 1))
  echo "✗ Device list doesn't show expected devices"
fi

# Cleanup
cd /
rm -rf "$TEST_ROOT"

test_summary "android-integration-validation"
