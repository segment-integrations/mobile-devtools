#!/usr/bin/env bash
# Android Plugin - Configuration Drift Detection
# Detects when environment variables don't match android.lock

# android_check_config_drift
# Compares Android env vars with android.lock and detects drift
# Sets global variables:
#   ANDROID_DRIFT_DETECTED - "true" if drift detected, "false" otherwise
#   ANDROID_DRIFT_DETAILS - formatted string with drift details (for printf %s)
android_check_config_drift() {
  local config_dir="${ANDROID_CONFIG_DIR:-./devbox.d/android}"
  local android_lock="${config_dir}/android.lock"

  ANDROID_DRIFT_DETECTED="false"
  ANDROID_DRIFT_DETAILS=""

  # Only check if lock file exists and jq is available
  if [ ! -f "$android_lock" ]; then
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  # Compare each env var with android.lock
  local vars="ANDROID_BUILD_TOOLS_VERSION ANDROID_CMDLINE_TOOLS_VERSION ANDROID_COMPILE_SDK ANDROID_TARGET_SDK ANDROID_SYSTEM_IMAGE_TAG ANDROID_INCLUDE_NDK ANDROID_NDK_VERSION ANDROID_INCLUDE_CMAKE ANDROID_CMAKE_VERSION"

  for var in $vars; do
    local env_val="${!var:-}"
    local lock_val
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

    # Detect drift
    if [ "$env_val" != "$lock_val" ]; then
      ANDROID_DRIFT_DETECTED="true"
      ANDROID_DRIFT_DETAILS="${ANDROID_DRIFT_DETAILS}    ${var}: \"${env_val}\" (env) vs \"${lock_val}\" (lock)\n"
    fi
  done

  export ANDROID_DRIFT_DETECTED
  export ANDROID_DRIFT_DETAILS
}
