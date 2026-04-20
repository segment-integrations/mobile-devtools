#!/usr/bin/env bash
# Android Plugin - Doctor Init Check
# Lightweight health check run on shell init
# Shows ✓ if all good, warnings if issues detected

set -eu

# Silent mode - only output if there are issues
issues=()

# Check 1: SDK Root
if [ -z "${ANDROID_SDK_ROOT:-}" ] || [ ! -d "${ANDROID_SDK_ROOT:-}" ]; then
  issues+=("Android SDK not found")
fi

# Check 2: Essential tools
if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
  if ! command -v adb >/dev/null 2>&1; then
    issues+=("adb not in PATH")
  fi
  if ! command -v emulator >/dev/null 2>&1; then
    issues+=("emulator not in PATH")
  fi
fi

# Check 3: Configuration drift (android.lock out of sync with env vars)
config_dir="${ANDROID_CONFIG_DIR:-./devbox.d/android}"
android_lock="${config_dir}/android.lock"
drift_detected=false
drift_details=""

if [ -f "$android_lock" ] && command -v jq >/dev/null 2>&1; then
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
fi

if [ "$drift_detected" = true ]; then
  issues+=("Config drift: env vars don't match android.lock")
fi

# Output results
if [ ${#issues[@]} -eq 0 ]; then
  echo "✓ Android"
else
  echo "⚠️  Android issues detected:" >&2
  for issue in "${issues[@]}"; do
    echo "  - $issue" >&2
  done

  # If drift detected, show details
  if [ "$drift_detected" = true ]; then
    echo "" >&2
    echo "  Config differences:" >&2
    printf "$drift_details" >&2
    echo "  Fix: devbox run android:sync" >&2
  fi

  echo "  Run 'devbox run doctor' for more details" >&2
fi
