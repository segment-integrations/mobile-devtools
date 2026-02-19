#!/usr/bin/env sh
# iOS Plugin - Core Utilities
# See REFERENCE.md for detailed documentation

set -e

if ! (return 0 2>/dev/null); then
  echo "ERROR: lib.sh must be sourced" >&2
  exit 1
fi

if [ "${IOS_LIB_LOADED:-}" = "1" ] && [ "${IOS_LIB_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_LIB_LOADED=1
IOS_LIB_LOADED_PID="$$"

# ============================================================================
# Logging Utilities
# ============================================================================

# Detect script name from caller (works for sourced and executed scripts)
_ios_get_script_name() {
  # Try to get script name from $0 first
  if [ -n "${0:-}" ] && [ "$0" != "sh" ] && [ "$0" != "bash" ] && [ "$0" != "-sh" ] && [ "$0" != "-bash" ]; then
    basename "$0" 2>/dev/null || echo "ios"
  else
    echo "ios"
  fi
}

# Log with level and optional script name
# Usage: _ios_log "LEVEL" "script-name" "message" or _ios_log "LEVEL" "message"
_ios_log() {
  level="$1"
  shift

  # Check if first arg looks like a script name (ends in .sh or is short)
  if [ $# -eq 2 ]; then
    script_name="$1"
    message="$2"
  else
    script_name="$(_ios_get_script_name)"
    message="$1"
  fi

  printf '[%s] [%s] %s\n' "$level" "$script_name" "$message" >&2
}

# Debug logging (only shown when DEBUG=1 or IOS_DEBUG=1)
ios_log_debug() {
  if [ "${IOS_DEBUG:-}" = "1" ] || [ "${DEBUG:-}" = "1" ]; then
    _ios_log "DEBUG" "$@"
  fi
}

# Info logging (always shown)
ios_log_info() {
  _ios_log "INFO" "$@"
}

# Warning logging (always shown)
ios_log_warn() {
  _ios_log "WARN" "$@"
}

# Error logging (always shown)
ios_log_error() {
  _ios_log "ERROR" "$@"
}

# Sanitize device name for iOS simulator (allows ._- and spaces)
ios_sanitize_device_name() {
  raw_name="$1"
  if [ -z "$raw_name" ]; then
    return 1
  fi
  # iOS simulator names can contain spaces, alphanumeric, dots, dashes, underscores
  cleaned_name="$(printf '%s' "$raw_name" | tr -cd 'A-Za-z0-9 ._-')"
  if [ -z "$cleaned_name" ]; then
    return 1
  fi
  printf '%s\n' "$cleaned_name"
}

# Compute SHA-256 checksum of device definition files
ios_compute_devices_checksum() {
  devices_dir="$1"
  if [ -z "$devices_dir" ] || [ ! -d "$devices_dir" ]; then
    return 1
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    find "$devices_dir" -name "*.json" -type f -exec cat {} + 2>/dev/null | \
      sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    find "$devices_dir" -name "*.json" -type f -exec cat {} + 2>/dev/null | \
      shasum -a 256 | cut -d' ' -f1
  else
    return 1
  fi
}

# Config directory resolution with fallback priority:
# IOS_CONFIG_DIR > DEVBOX_PROJECT_ROOT > DEVBOX_PROJECT_DIR > DEVBOX_WD > ./
ios_config_path() {
  if [ -n "${IOS_CONFIG_DIR:-}" ] && [ -d "$IOS_CONFIG_DIR" ]; then
    printf '%s\n' "$IOS_CONFIG_DIR"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_ROOT:-}" ] && [ -d "${DEVBOX_PROJECT_ROOT}/devbox.d/ios" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_ROOT}/devbox.d/ios"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_DIR:-}" ] && [ -d "${DEVBOX_PROJECT_DIR}/devbox.d/ios" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_DIR}/devbox.d/ios"
    return 0
  fi
  if [ -n "${DEVBOX_WD:-}" ] && [ -d "${DEVBOX_WD}/devbox.d/ios" ]; then
    printf '%s\n' "${DEVBOX_WD}/devbox.d/ios"
    return 0
  fi
  if [ -d "./devbox.d/ios" ]; then
    printf '%s\n' "./devbox.d/ios"
    return 0
  fi
  return 1
}

# Device directory resolution with fallback priority
ios_devices_dir() {
  if [ -n "${IOS_DEVICES_DIR:-}" ] && [ -d "$IOS_DEVICES_DIR" ]; then
    printf '%s\n' "$IOS_DEVICES_DIR"
    return 0
  fi
  if [ -n "${IOS_CONFIG_DIR:-}" ] && [ -d "${IOS_CONFIG_DIR}/devices" ]; then
    printf '%s\n' "${IOS_CONFIG_DIR}/devices"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_ROOT:-}" ] && [ -d "${DEVBOX_PROJECT_ROOT}/devbox.d/ios/devices" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_ROOT}/devbox.d/ios/devices"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_DIR:-}" ] && [ -d "${DEVBOX_PROJECT_DIR}/devbox.d/ios/devices" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_DIR}/devbox.d/ios/devices"
    return 0
  fi
  if [ -n "${DEVBOX_WD:-}" ] && [ -d "${DEVBOX_WD}/devbox.d/ios/devices" ]; then
    printf '%s\n' "${DEVBOX_WD}/devbox.d/ios/devices"
    return 0
  fi
  if [ -d "./devbox.d/ios/devices" ]; then
    printf '%s\n' "./devbox.d/ios/devices"
    return 0
  fi
  return 1
}

# Requirement checks
ios_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required" >&2
    exit 1
  fi
}

ios_require_tool() {
  tool_name="$1"
  error_message="${2:-Missing required tool: $tool_name}"
  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "ERROR: $error_message" >&2
    exit 1
  fi
}

ios_require_dir() {
  path="$1"
  error_message="${2:-Missing required directory: $path}"
  if [ ! -d "$path" ]; then
    echo "ERROR: $error_message" >&2
    exit 1
  fi
}

ios_require_dir_contains() {
  base_dir="$1"
  required_subpath="$2"
  error_message="${3:-Missing required path: $base_dir/$required_subpath}"
  full_path="${base_dir%/}/${required_subpath#/}"
  if [ ! -e "$full_path" ]; then
    echo "ERROR: $error_message" >&2
    exit 1
  fi
}

ios_log_debug "lib.sh loaded"
