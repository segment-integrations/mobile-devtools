#!/usr/bin/env bash
# Android Plugin - Configuration Drift Detection
# Detects when environment variables don't match android.lock

# Android configuration variables to check for drift
readonly ANDROID_CONFIG_VARS=(
  "ANDROID_BUILD_TOOLS_VERSION"
  "ANDROID_CMDLINE_TOOLS_VERSION"
  "ANDROID_COMPILE_SDK"
  "ANDROID_TARGET_SDK"
  "ANDROID_SYSTEM_IMAGE_TAG"
  "ANDROID_INCLUDE_NDK"
  "ANDROID_NDK_VERSION"
  "ANDROID_INCLUDE_CMAKE"
  "ANDROID_CMAKE_VERSION"
)

# Normalize boolean value (consistent with jq test("true|1|yes|on"; "i"))
# Accepts: true/1/yes/on (case-insensitive)
android_normalize_bool() {
  local val="$1"
  # Convert to lowercase for case-insensitive comparison
  case "${val,,}" in
    1|true|yes|on) echo "true" ;;
    *) echo "false" ;;
  esac
}

# android_check_config_drift
# Compares Android env vars with android.lock and detects drift
# Sets global variables:
#   ANDROID_DRIFT_DETECTED - "true" if drift detected, "false" if no drift, "unknown" if cannot check
#   ANDROID_DRIFT_DETAILS - formatted string with drift details (for printf %s)
android_check_config_drift() {
  local config_dir="${ANDROID_CONFIG_DIR:-./devbox.d/android}"
  local android_lock="${config_dir}/android.lock"

  ANDROID_DRIFT_DETECTED="false"
  ANDROID_DRIFT_DETAILS=""

  # Check if lock file exists
  if [ ! -f "$android_lock" ]; then
    return 0
  fi

  # Check if jq is available
  if ! command -v jq >/dev/null 2>&1; then
    ANDROID_DRIFT_DETECTED="unknown"
    ANDROID_DRIFT_DETAILS="    jq not available, cannot check configuration drift\n"
    export ANDROID_DRIFT_DETECTED
    export ANDROID_DRIFT_DETAILS
    return 0
  fi

  # Compare each env var with android.lock
  for var in "${ANDROID_CONFIG_VARS[@]}"; do
    local env_val="${!var:-}"
    local lock_val
    lock_val="$(jq -r ".${var} // empty" "$android_lock" 2>/dev/null || echo "")"

    # Normalize boolean values for comparison
    if [ "$var" = "ANDROID_INCLUDE_NDK" ] || [ "$var" = "ANDROID_INCLUDE_CMAKE" ]; then
      env_val=$(android_normalize_bool "$env_val")
      # lock_val is already normalized in android.lock (true/false)
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
