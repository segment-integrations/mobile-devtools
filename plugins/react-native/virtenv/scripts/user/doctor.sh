#!/usr/bin/env bash
# React Native Plugin - Doctor Script
# Comprehensive health check for React Native environment with exit codes
#
# Exit codes:
#   0 = All checks passed
#   1 = Warnings detected (non-fatal issues)
#   2 = Fatal errors (critical failures)

set -eu

# Initialize combined doctor state
DOCTOR_CHECKS_PASSED=0
DOCTOR_CHECKS_WARNED=0
DOCTOR_CHECKS_ERRORED=0
DOCTOR_WARNINGS=()
DOCTOR_ERRORS=()

# Source RN doctor library if available
if [ -n "${RN_SCRIPTS_DIR:-}" ] && [ -f "${RN_SCRIPTS_DIR}/lib/doctor.sh" ]; then
  . "${RN_SCRIPTS_DIR}/lib/doctor.sh"
fi

# Print header
echo ""
printf '\033[1mReact Native Environment Check\033[0m\n'
echo "=============================="

# ============================================================================
# Section 1: Node.js and Package Manager
# ============================================================================

echo ""
printf '\033[1mNode.js and Package Manager\033[0m\n'
echo ""

# Check Node.js version (>= 18.x recommended)
rn_check_node_version 18

# Check npm
if command -v npm >/dev/null 2>&1; then
  DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
  printf "  \033[32m✓\033[0m npm\n"
  npm_version=$(npm --version 2>/dev/null || echo "unknown")
  printf "  \033[32mℹ\033[0m npm: v%s\n" "$npm_version"
else
  DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
  printf "  \033[31m✗\033[0m npm\n"
  printf "    \033[31mCommand not found: npm\033[0m\n"
fi

# Check yarn (optional but common)
if command -v yarn >/dev/null 2>&1; then
  DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
  printf "  \033[32m✓\033[0m yarn (optional)\n"
else
  printf "  \033[32mℹ\033[0m yarn: not installed (optional)\n"
fi

# ============================================================================
# Section 2: React Native Project
# ============================================================================

echo ""
printf '\033[1mReact Native Project\033[0m\n'
echo ""

# Check package.json and dependencies
rn_check_package_json
rn_check_node_modules

# Check for platform directories
if [ -d "android" ]; then
  DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
  printf "  \033[32m✓\033[0m android/ directory found\n"
else
  DOCTOR_CHECKS_WARNED=$((DOCTOR_CHECKS_WARNED + 1))
  printf "  \033[33m⚠\033[0m android/ directory found\n"
  printf "    \033[33mandroid/ directory not found\033[0m\n"
fi

if [ -d "ios" ]; then
  DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
  printf "  \033[32m✓\033[0m ios/ directory found\n"
else
  DOCTOR_CHECKS_WARNED=$((DOCTOR_CHECKS_WARNED + 1))
  printf "  \033[33m⚠\033[0m ios/ directory found\n"
  printf "    \033[33mios/ directory not found\033[0m\n"
fi

# ============================================================================
# Section 3: Development Tools
# ============================================================================

echo ""
printf '\033[1mDevelopment Tools\033[0m\n'
echo ""

# Check Watchman (recommended for React Native)
if command -v watchman >/dev/null 2>&1; then
  DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
  printf "  \033[32m✓\033[0m Watchman\n"
  watchman_version=$(watchman --version 2>/dev/null | head -1 || echo "unknown")
  printf "  \033[32mℹ\033[0m Watchman: %s\n" "$watchman_version"
else
  DOCTOR_CHECKS_WARNED=$((DOCTOR_CHECKS_WARNED + 1))
  printf "  \033[33m⚠\033[0m Watchman\n"
  printf "    \033[33mWatchman not found (recommended for React Native file watching)\033[0m\n"
fi

# Check Metro port availability
rn_check_metro_port 8081

# ============================================================================
# Section 4: Android Platform
# ============================================================================

echo ""
printf '\033[1mAndroid Platform\033[0m\n'
echo ""

# Check if Android setup should be skipped
if [ "${ANDROID_SKIP_SETUP:-0}" = "1" ]; then
  printf "  \033[32mℹ\033[0m Android checks skipped (ANDROID_SKIP_SETUP=1)\n"
else
  # Check ANDROID_SDK_ROOT
  if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
    DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
    printf "  \033[32m✓\033[0m ANDROID_SDK_ROOT is set\n"

    if [ -d "${ANDROID_SDK_ROOT}" ]; then
      DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
      printf "  \033[32m✓\033[0m SDK directory exists\n"
    else
      DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
      printf "  \033[31m✗\033[0m SDK directory exists\n"
      printf "    \033[31mDirectory not found: %s\033[0m\n" "${ANDROID_SDK_ROOT}"
    fi
  else
    DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
    printf "  \033[31m✗\033[0m ANDROID_SDK_ROOT is set\n"
    printf "    \033[31mEnvironment variable not set\033[0m\n"
  fi

  # Check Android tools
  if command -v adb >/dev/null 2>&1; then
    DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
    printf "  \033[32m✓\033[0m adb\n"
  else
    DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
    printf "  \033[31m✗\033[0m adb\n"
    printf "    \033[31mCommand not found: adb\033[0m\n"
  fi

  if command -v emulator >/dev/null 2>&1; then
    DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
    printf "  \033[32m✓\033[0m emulator\n"
  else
    DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
    printf "  \033[31m✗\033[0m emulator\n"
    printf "    \033[31mCommand not found: emulator\033[0m\n"
  fi

  # Check Android device configuration
  if [ -d "android" ]; then
    android_devices_dir="${ANDROID_DEVICES_DIR:-./devbox.d/segment-integrations.devbox-plugins.android/devices}"
    if [ -d "$android_devices_dir" ]; then
      device_count=$(find "$android_devices_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
      DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
      printf "  \033[32m✓\033[0m Android devices configured (%s)\n" "$device_count"
    fi
  fi
fi

# ============================================================================
# Section 5: iOS Platform
# ============================================================================

echo ""
printf '\033[1miOS Platform\033[0m\n'
echo ""

# Check if iOS setup should be skipped
if [ "${IOS_SKIP_SETUP:-0}" = "1" ]; then
  printf "  \033[32mℹ\033[0m iOS checks skipped (IOS_SKIP_SETUP=1)\n"
else
  # Only run iOS checks on macOS
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # Check Xcode command line tools
    if xcrun --show-sdk-path >/dev/null 2>&1; then
      DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
      printf "  \033[32m✓\033[0m Xcode command line tools\n"
    else
      DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
      printf "  \033[31m✗\033[0m Xcode command line tools\n"
      printf "    \033[31mNot found. Install with: xcode-select --install\033[0m\n"
    fi

    # Check xcrun
    if command -v xcrun >/dev/null 2>&1; then
      DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
      printf "  \033[32m✓\033[0m xcrun\n"
    else
      DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
      printf "  \033[31m✗\033[0m xcrun\n"
      printf "    \033[31mCommand not found: xcrun\033[0m\n"
    fi

    # Check simctl
    if xcrun simctl list devices >/dev/null 2>&1; then
      DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
      printf "  \033[32m✓\033[0m xcrun simctl working\n"
    else
      DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
      printf "  \033[31m✗\033[0m xcrun simctl working\n"
      printf "    \033[31msimctl not functioning correctly\033[0m\n"
    fi

    # Check CocoaPods
    if [ -f "ios/Podfile" ]; then
      if command -v pod >/dev/null 2>&1; then
        DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
        printf "  \033[32m✓\033[0m CocoaPods\n"

        if [ -d "ios/Pods" ]; then
          DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
          printf "  \033[32m✓\033[0m Pods installed\n"
        else
          DOCTOR_CHECKS_WARNED=$((DOCTOR_CHECKS_WARNED + 1))
          printf "  \033[33m⚠\033[0m Pods installed\n"
          printf "    \033[33mRun: cd ios && pod install\033[0m\n"
        fi
      else
        DOCTOR_CHECKS_WARNED=$((DOCTOR_CHECKS_WARNED + 1))
        printf "  \033[33m⚠\033[0m CocoaPods\n"
        printf "    \033[33mPodfile found but CocoaPods not installed\033[0m\n"
      fi
    fi

    # Check iOS device configuration
    if [ -d "ios" ]; then
      ios_devices_dir="${IOS_DEVICES_DIR:-./devbox.d/segment-integrations.devbox-plugins.ios/devices}"
      if [ -d "$ios_devices_dir" ]; then
        device_count=$(find "$ios_devices_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
        DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
        printf "  \033[32m✓\033[0m iOS devices configured (%s)\n" "$device_count"
      fi
    fi
  else
    printf "  \033[32mℹ\033[0m iOS checks skipped (not macOS)\n"
  fi
fi

# ============================================================================
# Print Summary and Exit
# ============================================================================

echo ""
printf '\033[1mSummary\033[0m\n'
echo ""

total_checks=$((DOCTOR_CHECKS_PASSED + DOCTOR_CHECKS_WARNED + DOCTOR_CHECKS_ERRORED))
printf "  Checks: %s total\n" "$total_checks"
printf "    \033[32m✓\033[0m Passed: %s\n" "$DOCTOR_CHECKS_PASSED"

if [ "$DOCTOR_CHECKS_WARNED" -gt 0 ]; then
  printf "    \033[33m⚠\033[0m Warnings: %s\n" "$DOCTOR_CHECKS_WARNED"
fi

if [ "$DOCTOR_CHECKS_ERRORED" -gt 0 ]; then
  printf "    \033[31m✗\033[0m Errors: %s\n" "$DOCTOR_CHECKS_ERRORED"
fi

echo ""

# Determine exit code
if [ "$DOCTOR_CHECKS_ERRORED" -gt 0 ]; then
  printf "  Status: \033[31m✗ Critical errors detected\033[0m\n"
  exit_code=2
elif [ "$DOCTOR_CHECKS_WARNED" -gt 0 ]; then
  printf "  Status: \033[33m⚠ Warnings detected\033[0m\n"
  exit_code=1
else
  printf "  Status: \033[32m✓ All checks passed\033[0m\n"
  exit_code=0
fi

# Print exit code for CI
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
  echo ""
  printf "  Exit Code: %s\n" "$exit_code"
fi

echo ""

exit $exit_code
