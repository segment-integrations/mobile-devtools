#!/usr/bin/env bash
# Android Plugin - Doctor Init Check
# Lightweight health check run on shell init with exit codes
# Shows ✓ if all good, warnings if issues detected
#
# Exit codes:
#   0 = All checks passed
#   1 = Warnings detected (non-fatal issues)
#   2 = Fatal errors (critical failures)

set -eu

# Source doctor library
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/lib/doctor.sh" ]; then
  . "${ANDROID_SCRIPTS_DIR}/lib/doctor.sh"
fi

# Source drift detection if available
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/platform/drift.sh" ]; then
  . "${ANDROID_SCRIPTS_DIR}/platform/drift.sh"
fi

# Initialize doctor state
doctor_init

# Suppress output - collect issues silently
issues=()

# Check 1: SDK Root
if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
  issues+=("ANDROID_SDK_ROOT not set")
  DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
elif [ ! -d "${ANDROID_SDK_ROOT:-}" ]; then
  issues+=("Android SDK directory not found: ${ANDROID_SDK_ROOT}")
  DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
else
  DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
fi

# Check 2: Essential tools
if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
  if ! command -v adb >/dev/null 2>&1; then
    issues+=("adb not in PATH")
    DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
  else
    DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
  fi

  if ! command -v emulator >/dev/null 2>&1; then
    issues+=("emulator not in PATH")
    DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
  else
    DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
  fi
fi

# Check 3: Configuration drift (android.lock out of sync with env vars)
if command -v android_check_config_drift >/dev/null 2>&1; then
  android_check_config_drift
  if [ "${ANDROID_DRIFT_DETECTED:-false}" = true ]; then
    issues+=("Config drift: env vars don't match android.lock")
    DOCTOR_CHECKS_WARNED=$((DOCTOR_CHECKS_WARNED + 1))
  else
    DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
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

# Exit with appropriate code
exit $(doctor_get_exit_code)
