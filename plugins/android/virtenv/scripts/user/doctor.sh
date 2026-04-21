#!/usr/bin/env bash
# Android Plugin - Doctor Script
# Comprehensive health check for Android environment

set -eu

# Source drift detection if available
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/platform/drift.sh" ]; then
  . "${ANDROID_SCRIPTS_DIR}/platform/drift.sh"
fi

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
elif command -v android_check_config_drift >/dev/null 2>&1; then
  # Use shared drift detection function
  android_check_config_drift

  if [ "${ANDROID_DRIFT_DETECTED}" = true ]; then
    echo "  ⚠ Configuration drift detected:"
    printf '%s' "${ANDROID_DRIFT_DETAILS}"
    echo ""
    echo "  Fix: devbox run android:sync"
  else
    echo "  ✓ Env vars match android.lock"
  fi
else
  echo "  ⚠ Cannot check drift (drift detection not available)"
fi
echo ''

# Check 6: Hash overrides validation
echo 'Hash Overrides:'
if [ -f "$android_lock" ] && command -v jq >/dev/null 2>&1; then
  if jq -e '.hash_overrides' "$android_lock" >/dev/null 2>&1; then
    override_count=$(jq '.hash_overrides | length' "$android_lock")
    if [ "$override_count" -gt 0 ]; then
      echo "  ⚠ $override_count hash override(s) active"
      jq -r '.hash_overrides | to_entries[] | "    - \(.key | split("/") | last)"' "$android_lock"

      # Test if overrides are still needed
      echo "  Testing override validity..."

      # Create temporary android.lock without overrides
      temp_lock=$(mktemp)
      jq 'del(.hash_overrides)' "$android_lock" > "$temp_lock"

      # Try building SDK without overrides (quick check, no full build)
      if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/platform/core.sh" ]; then
        # Source core to get SDK resolution function
        . "${ANDROID_SCRIPTS_DIR}/platform/core.sh" 2>/dev/null || true

        # Temporarily swap lock file
        mv "$android_lock" "${android_lock}.backup"
        mv "$temp_lock" "$android_lock"

        # Try resolving SDK (this will fail fast if hash mismatch)
        test_output=$(android_resolve_sdk_root 2>&1 || true)

        # Restore original lock file
        mv "$android_lock" "$temp_lock"
        mv "${android_lock}.backup" "$android_lock"

        # Check result
        if echo "$test_output" | grep -q "hash mismatch"; then
          echo "  ✓ Overrides are still needed (upstream not fixed)"
        elif echo "$test_output" | grep -qE "^/nix/store/"; then
          echo "  ⚠ Overrides may no longer be needed!"
          echo "    Test: android.sh hash clear && devbox shell"
          echo "    If successful, commit the fix"
        else
          echo "  ? Cannot validate overrides (SDK resolution failed for other reasons)"
        fi

        rm -f "$temp_lock"
      else
        echo "  ? Cannot validate (core.sh not available)"
      fi

      echo "  View: android.sh hash show"
      echo "  Clear: android.sh hash clear"
    else
      echo "  ✓ No hash overrides (using upstream hashes)"
    fi
  else
    echo "  ✓ No hash overrides (using upstream hashes)"
  fi
else
  echo "  ⚠ Cannot check (android.lock not found or jq unavailable)"
fi
echo ''
