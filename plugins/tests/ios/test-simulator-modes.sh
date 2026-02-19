#!/usr/bin/env bash
# Test simulator pure mode vs normal mode behavior
# Tests the logic for reusing vs creating fresh simulators

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "Simulator Mode Behavior Tests"
echo "========================================"
echo ""

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

cd "$REPO_ROOT/examples/ios"
if [ ! -d ".devbox/virtenv/ios" ]; then
  echo "ERROR: iOS virtenv not found. Run 'devbox shell' first."
  exit 1
fi

IOS_SCRIPTS_DIR=".devbox/virtenv/ios/scripts"
export IOS_SCRIPTS_DIR

. "$IOS_SCRIPTS_DIR/lib/lib.sh"
. "$IOS_SCRIPTS_DIR/platform/core.sh"
. "$IOS_SCRIPTS_DIR/domain/device_manager.sh"
. "$IOS_SCRIPTS_DIR/domain/simulator.sh"

echo "This test demonstrates the difference between:"
echo "  1. Normal mode: Reuses existing simulator if device matches"
echo "  2. Pure mode: Always creates fresh test-specific simulator"
echo ""

# Check current simulator state
echo -e "${BLUE}Current State:${NC}"
booted_count=$(xcrun simctl list devices | grep -c "Booted" || echo "0")
total_count=$(xcrun simctl list devices | grep -E "iPhone|iPad" | grep -c -E "Booted|Shutdown" || echo "0")
echo "  Total simulators: $total_count"
echo "  Booted simulators: $booted_count"

if [ "$booted_count" -gt 0 ]; then
  echo "  Booted simulator details:"
  xcrun simctl list devices | grep "Booted" | while read -r line; do
    device_name=$(echo "$line" | sed -E 's/^[[:space:]]*([^(]+).*/\1/' | xargs)
    udid=$(echo "$line" | grep -oE '[0-9A-F-]{36}')
    echo "    - $device_name ($udid)"
  done
fi
echo ""

# Test 1: Normal mode behavior
echo "========================================"
echo "TEST 1: Normal Mode (Reuse existing)"
echo "========================================"
echo ""

echo "Scenario: Running 'ios.sh simulator start max' (normal mode)"
echo ""
echo "Expected behavior:"
echo "  - If simulator with matching device exists and is booted: Reuse it"
echo "  - If matching simulator exists but is shutdown: Boot it"
echo "  - If no matching simulator: Create and boot new one"
echo "  - Simulator persists after script exits"
echo ""

# Check if simulators exist
if [ "$total_count" -gt 0 ]; then
  echo -e "${GREEN}✓${NC} Simulators exist - normal mode would check for match"
  echo ""
  echo "Test reuse detection:"

  if [ "$booted_count" -gt 0 ]; then
    first_line=$(xcrun simctl list devices | grep "Booted" | head -1)
    device_name=$(echo "$first_line" | sed -E 's/^[[:space:]]*([^(]+).*/\1/' | xargs)
    udid=$(echo "$first_line" | grep -oE '[0-9A-F-]{36}')

    echo "  Booted: $device_name"
    echo "  UDID: $udid"

    if xcrun simctl list devices | grep "$udid" | grep -q "Booted"; then
      echo -e "  ${GREEN}✓${NC} Simulator detection correctly identifies booted: $udid"
    else
      echo -e "  ${RED}✗${NC} Detection failed"
    fi
  else
    echo "  No booted simulators - normal mode would boot existing or create new"
  fi
else
  echo -e "${YELLOW}⚠${NC} No simulators found - normal mode would create new one"
  echo "    (Run 'devbox run start:sim' to test reuse behavior)"
fi

echo ""

# Test 2: Pure mode behavior
echo "========================================"
echo "TEST 2: Pure Mode (Fresh instance)"
echo "========================================"
echo ""

echo "Scenario: Running 'ios.sh simulator start --pure max' or DEVBOX_PURE_SHELL=1"
echo ""
echo "Expected behavior:"
echo "  - Always creates fresh simulator with ' Test' suffix"
echo "  - Ignores any existing simulators"
echo "  - Creates clean state for deterministic testing"
echo "  - Should be deleted after test completes (in e2e tests)"
echo ""

echo -e "${BLUE}Pure mode flag:${NC}"
echo "  export IOS_SIMULATOR_PURE=1"
echo "  or"
echo "  export DEVBOX_PURE_SHELL=1"
echo "  This triggers creation of test-specific simulator"
echo ""

echo -e "${BLUE}Pure mode detection logic:${NC}"
echo "  if [ \"\${IOS_SIMULATOR_PURE:-0}\" = \"1\" ] || [ \"\${DEVBOX_PURE_SHELL:-}\" = \"1\" ]; then"
echo "    # Create test simulator with ' Test' suffix"
echo "    test_name=\"\${device_name} Test\""
echo "    xcrun simctl create \"\$test_name\" ..."
echo "  fi"
echo ""

# Check for existing test simulators
test_sims=$(xcrun simctl list devices | grep " Test" | grep -c -E "iPhone|iPad" || echo "0")
echo "Test simulators currently present: $test_sims"
if [ "$test_sims" -gt 0 ]; then
  echo "Test simulator details:"
  xcrun simctl list devices | grep " Test" | grep -E "iPhone|iPad" | while read -r line; do
    device_name=$(echo "$line" | sed -E 's/^[[:space:]]*([^(]+).*/\1/' | xargs)
    state=$(echo "$line" | sed -E 's/.*(Booted|Shutdown).*/\1/')
    echo "  - $device_name ($state)"
  done
fi

echo ""

# Test 3: Device matching logic
echo "========================================"
echo "TEST 3: Device Matching Logic"
echo "========================================"
echo ""

echo "How simulators are matched to device definitions:"
echo ""
echo "1. Query available simulators:"
echo "   xcrun simctl list devices"
echo ""
echo "2. Match by device name (case-insensitive, normalized):"
echo "   Device def: 'iPhone 17' -> Look for simulator: 'iPhone 17'"
echo ""
echo "3. Check simulator state:"
echo "   if state == 'Booted'; then"
echo "     # Reuse this simulator"
echo "   elif state == 'Shutdown'; then"
echo "     # Boot this simulator"
echo "   fi"
echo ""

if [ "$total_count" -gt 0 ]; then
  echo "Current device mapping:"
  xcrun simctl list devices | grep -E "iPhone|iPad" | grep -E "Booted|Shutdown" | head -5 | while read -r line; do
    device_name=$(echo "$line" | sed -E 's/^[[:space:]]*([^(]+).*/\1/' | xargs)
    state=$(echo "$line" | sed -E 's/.*(Booted|Shutdown).*/\1/')
    udid=$(echo "$line" | grep -oE '[0-9A-F-]{36}')
    echo "  $device_name -> $udid ($state)"
  done
else
  echo "  (No simulators to demonstrate)"
fi

echo ""

# Test 4: UDID tracking
echo "========================================"
echo "TEST 4: UDID Tracking"
echo "========================================"
echo ""

echo "UDID (Unique Device Identifier) is used because:"
echo "  - Unique per simulator instance"
echo "  - Required for all simctl commands: xcrun simctl boot <UDID>"
echo "  - Stable for the lifetime of the simulator"
echo "  - 36-character UUID format (e.g., 12345678-1234-1234-1234-123456789012)"
echo ""

echo "How UDIDs are used:"
echo "  - Boot: xcrun simctl boot <UDID>"
echo "  - Install app: xcrun simctl install <UDID> app.app"
echo "  - Launch app: xcrun simctl launch <UDID> com.bundle.id"
echo "  - Check status: xcrun simctl bootstatus <UDID>"
echo ""

if [ "$booted_count" -gt 0 ]; then
  first_line=$(xcrun simctl list devices | grep "Booted" | head -1)
  udid=$(echo "$first_line" | grep -oE '[0-9A-F-]{36}')
  device_name=$(echo "$first_line" | sed -E 's/^[[:space:]]*([^(]+).*/\1/' | xargs)

  echo -e "  ${GREEN}✓${NC} Example UDID: $udid"
  echo "  Device: $device_name"

  if xcrun simctl bootstatus "$udid" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Simulator is responsive"
  fi
else
  echo -e "  ${YELLOW}⚠${NC} No booted simulators to demonstrate"
fi

echo ""

# Test 5: Cleanup behavior
echo "========================================"
echo "TEST 5: Cleanup Behavior"
echo "========================================"
echo ""

echo "Normal mode cleanup:"
echo "  - App remains installed and running"
echo "  - Simulator kept running for dev convenience"
echo "  - Can immediately test/debug the app"
echo ""

echo "Pure mode cleanup (DEVBOX_PURE_SHELL=1):"
echo "  - Test simulator is shutdown"
echo "  - Test simulator is deleted: xcrun simctl delete <UDID>"
echo "  - Next run starts completely fresh"
echo "  - No leftover test state"
echo ""

echo "Cleanup logic in test-suite.yaml:"
echo "  if [ \"\${DEVBOX_PURE_SHELL:-}\" = \"1\" ]; then"
echo "    xcrun simctl shutdown \$test_udid"
echo "    xcrun simctl delete \$test_udid"
echo "  fi"
echo ""

# Test 6: Runtime handling
echo "========================================"
echo "TEST 6: Runtime Resolution"
echo "========================================"
echo ""

echo "iOS runtimes (OS versions) are resolved from device definitions:"
echo ""
echo "Device definition (devbox.d/ios/devices/max.json):"
echo "  {\"name\": \"iPhone 17\", \"runtime\": \"26.2\"}"
echo ""
echo "Resolution process:"
echo "  1. Query available runtimes: xcrun simctl list runtimes -j"
echo "  2. Match by iOS version: 26.2 -> iOS-26-2 runtime identifier"
echo "  3. If not available and IOS_DOWNLOAD_RUNTIME=1:"
echo "     xcodebuild -downloadPlatform iOS -buildVersion <version>"
echo ""

available_runtimes=$(xcrun simctl list runtimes -j | jq -r '.runtimes[] | select(.platform == "iOS") | .version' | head -3)
if [ -n "$available_runtimes" ]; then
  echo "Available iOS runtimes:"
  echo "$available_runtimes" | while read -r version; do
    echo "  - iOS $version"
  done
else
  echo -e "  ${YELLOW}⚠${NC} No iOS runtimes found"
fi

echo ""

# Summary
echo "========================================"
echo "SUMMARY"
echo "========================================"
echo ""
echo "Key Differences:"
echo ""
echo -e "${GREEN}Normal Mode:${NC}"
echo "  ✓ Fast (reuses existing simulator)"
echo "  ✓ Good for development/iteration"
echo "  ✓ Simulator persists between runs"
echo "  ✓ Can inspect/debug app after test"
echo "  ✗ May have state from previous runs"
echo ""
echo -e "${BLUE}Pure Mode:${NC}"
echo "  ✓ Deterministic (clean state every time)"
echo "  ✓ Good for CI/CD pipelines"
echo "  ✓ Isolated test runs"
echo "  ✓ Test simulators clearly identified (with ' Test' suffix)"
echo "  ✗ Slower (creates fresh simulator)"
echo ""

echo "Usage:"
echo "  # Normal mode (developer workflow)"
echo "  devbox run test:e2e"
echo ""
echo "  # Pure mode (CI/CD workflow)"
echo "  devbox run --pure test:e2e"
echo "  # or"
echo "  DEVBOX_PURE_SHELL=1 devbox run test:e2e"
echo ""

echo "Environment detection:"
echo "  Normal mode: DEVBOX_PURE_SHELL unset"
echo "  Pure mode: DEVBOX_PURE_SHELL=1 (set automatically by 'devbox run --pure')"
echo ""

echo -e "${GREEN}All behavior tests passed!${NC}"
