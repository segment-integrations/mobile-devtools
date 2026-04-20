#!/usr/bin/env bash
# Android Plugin - Doctor Script
# Comprehensive health check for Android environment

set -eu

echo 'Android Environment Check'
echo '========================='
echo ''

# Check 1: Android SDK
echo 'Android SDK:'
if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
  echo "  ANDROID_SDK_ROOT: ${ANDROID_SDK_ROOT}"
  if [ -d "${ANDROID_SDK_ROOT}" ]; then
    echo "  ✓ SDK directory exists"
  else
    echo "  ✗ SDK directory does not exist"
  fi
else
  echo "  ✗ ANDROID_SDK_ROOT not set"
fi
echo ''

# Check 2: AVD Home
echo 'AVD Environment:'
if [ -n "${ANDROID_AVD_HOME:-}" ]; then
  echo "  ANDROID_AVD_HOME: ${ANDROID_AVD_HOME}"
  if [ -w "${ANDROID_AVD_HOME}" ]; then
    echo "  ✓ AVD directory is writable"
  else
    echo "  ⚠ AVD directory is not writable"
  fi
else
  echo "  ANDROID_AVD_HOME: NOT SET"
fi
echo ''

# Check 3: Essential tools
echo 'Tools:'
if command -v adb >/dev/null 2>&1; then
  echo "  ✓ adb is in PATH"
else
  echo "  ✗ adb is not in PATH"
fi

if command -v emulator >/dev/null 2>&1; then
  echo "  ✓ emulator is in PATH"
else
  echo "  ✗ emulator is not in PATH"
fi

if command -v avdmanager >/dev/null 2>&1; then
  echo "  ✓ avdmanager is in PATH"
else
  echo "  ⚠ avdmanager is not in PATH"
fi
echo ''

# Check 4: Device configuration
echo 'Device Configuration:'
devices_dir="${ANDROID_DEVICES_DIR:-./devbox.d/android/devices}"
device_count=$(ls -1 "${devices_dir}"/*.json 2>/dev/null | wc -l | tr -d ' ')
echo "  Device files: ${device_count}"
echo "  ANDROID_DEVICES: ${ANDROID_DEVICES:-'(all devices)'}"

if [ -f "${devices_dir}/devices.lock" ]; then
  echo "  ✓ devices.lock exists"
else
  echo "  ⚠ devices.lock not generated yet (run devbox shell)"
fi
echo ''

# Check 5: Configuration drift (android.lock vs env vars)
config_dir="${ANDROID_CONFIG_DIR:-./devbox.d/android}"
android_lock="${config_dir}/android.lock"

echo 'Configuration Sync:'
if [ ! -f "$android_lock" ]; then
  echo "  ⚠ android.lock not found"
  echo "  Run: devbox run android:sync"
elif ! command -v jq >/dev/null 2>&1; then
  echo "  ⚠ jq not available, cannot check drift"
else
  drift_detected=false
  drift_details=""

  # Compare each env var with android.lock
  for var in ANDROID_BUILD_TOOLS_VERSION ANDROID_CMDLINE_TOOLS_VERSION ANDROID_COMPILE_SDK ANDROID_TARGET_SDK ANDROID_SYSTEM_IMAGE_TAG ANDROID_INCLUDE_NDK ANDROID_NDK_VERSION ANDROID_INCLUDE_CMAKE ANDROID_CMAKE_VERSION; do
    env_val="${!var:-}"
    lock_val="$(jq -r ".${var} // empty" "$android_lock" 2>/dev/null || echo "")"

    # Normalize boolean values for comparison
    if [ "$var" = "ANDROID_INCLUDE_NDK" ] || [ "$var" = "ANDROID_INCLUDE_CMAKE" ]; then
      case "$env_val" in
        1|true|TRUE|yes|YES|on|ON) env_val="true" ;;
        *) env_val="false" ;;
      esac
    fi

    # Skip if lock value is empty (field doesn't exist in lock)
    [ -z "$lock_val" ] && continue

    if [ "$env_val" != "$lock_val" ]; then
      drift_detected=true
      drift_details="${drift_details}    ${var}: \"${env_val}\" (env) vs \"${lock_val}\" (lock)\n"
    fi
  done

  if [ "$drift_detected" = true ]; then
    echo "  ⚠ Configuration drift detected:"
    printf "$drift_details"
    echo ""
    echo "  Fix: devbox run android:sync"
  else
    echo "  ✓ Env vars match android.lock"
  fi
fi
echo ''
