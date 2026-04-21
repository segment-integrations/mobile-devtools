#!/usr/bin/env bash
# Android Plugin - Doctor Init Check
# Lightweight health check run on shell init
# Shows ✓ if all good, warnings if issues detected

set -eu

# Source drift detection if available
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/platform/drift.sh" ]; then
  . "${ANDROID_SCRIPTS_DIR}/platform/drift.sh"
fi

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
if command -v android_check_config_drift >/dev/null 2>&1; then
  android_check_config_drift
  if [ "${ANDROID_DRIFT_DETECTED:-false}" = true ]; then
    issues+=("Config drift: env vars don't match android.lock")
  fi
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
  if [ "${ANDROID_DRIFT_DETECTED:-false}" = true ]; then
    echo "" >&2
    echo "  Config differences:" >&2
    printf '%s' "${ANDROID_DRIFT_DETAILS}" >&2
    echo "  Fix: devbox run android:sync" >&2
  fi

  echo "  Run 'devbox run doctor' for more details" >&2
fi
