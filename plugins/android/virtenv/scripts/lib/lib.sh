#!/usr/bin/env sh
# Android Plugin - Core Utilities
# See SCRIPTS.md for detailed documentation

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: lib.sh must be sourced" >&2
  exit 1
fi

if [ "${ANDROID_LIB_LOADED:-}" = "1" ] && [ "${ANDROID_LIB_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_LIB_LOADED=1
ANDROID_LIB_LOADED_PID="$$"

# ============================================================================
# Logging Utilities
# ============================================================================

# Detect script name from caller (works for sourced and executed scripts)
_android_get_script_name() {
  # Try to get script name from $0 first
  if [ -n "${0:-}" ] && [ "$0" != "sh" ] && [ "$0" != "bash" ] && [ "$0" != "-sh" ] && [ "$0" != "-bash" ]; then
    basename "$0" 2>/dev/null || echo "android"
  else
    echo "android"
  fi
}

# Log with level and optional script name
# Usage: _android_log "LEVEL" "script-name" "message" or _android_log "LEVEL" "message"
_android_log() {
  level="$1"
  shift

  # Check if first arg looks like a script name (ends in .sh or is short)
  if [ $# -eq 2 ]; then
    script_name="$1"
    message="$2"
  else
    script_name="$(_android_get_script_name)"
    message="$1"
  fi

  printf '[%s] [%s] %s\n' "$level" "$script_name" "$message" >&2
}

# Debug logging (only shown when DEBUG=1 or ANDROID_DEBUG=1)
android_log_debug() {
  if [ "${ANDROID_DEBUG:-}" = "1" ] || [ "${DEBUG:-}" = "1" ]; then
    _android_log "DEBUG" "$@"
  fi
}

# Info logging (always shown)
android_log_info() {
  _android_log "INFO" "$@"
}

# Warning logging (always shown)
android_log_warn() {
  _android_log "WARN" "$@"
}

# Error logging (always shown)
android_log_error() {
  _android_log "ERROR" "$@"
}

# String normalization for fuzzy matching
android_normalize_name() {
  input_string="$1"
  printf '%s' "$input_string" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

# Sanitize string for AVD name (allows ._- chars)
android_sanitize_avd_name() {
  raw_name="$1"
  if [ -z "$raw_name" ]; then
    return 1
  fi
  cleaned_name="$(printf '%s' "$raw_name" | tr ' ' '_' | tr -cd 'A-Za-z0-9._-')"
  if [ -z "$cleaned_name" ]; then
    return 1
  fi
  printf '%s\n' "$cleaned_name"
}

# Compute SHA-256 checksum of device definition files
# IMPORTANT: Files must be sorted for stable checksums
android_compute_devices_checksum() {
  devices_dir="$1"
  if [ -z "$devices_dir" ] || [ ! -d "$devices_dir" ]; then
    return 1
  fi

  # Sort files to ensure consistent ordering (filesystem order is non-deterministic)
  if command -v sha256sum >/dev/null 2>&1; then
    find "$devices_dir" -name "*.json" -type f -exec cat {} \; 2>/dev/null | \
      sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    find "$devices_dir" -name "*.json" -type f -exec cat {} \; 2>/dev/null | \
      shasum -a 256 | cut -d' ' -f1
  else
    return 1
  fi
}

# Path resolution with fallback priority:
# ANDROID_CONFIG_DIR > DEVBOX_PROJECT_ROOT > DEVBOX_PROJECT_DIR > DEVBOX_WD > ./
android_resolve_project_path() {
  subpath="${1:-}"
  if [ -z "$subpath" ]; then
    return 1
  fi

  if [ -n "${ANDROID_CONFIG_DIR:-}" ]; then
    candidate_path="${ANDROID_CONFIG_DIR%/}/${subpath#/}"
    if [ -e "$candidate_path" ]; then
      printf '%s\n' "$candidate_path"
      return 0
    fi
  fi

  for base_var_name in DEVBOX_PROJECT_ROOT DEVBOX_PROJECT_DIR DEVBOX_WD; do
    base_path="$(eval "printf '%s' \"\${${base_var_name}:-}\"")"
    if [ -n "$base_path" ]; then
      candidate_path="${base_path%/}/devbox.d/android/${subpath#/}"
      if [ -e "$candidate_path" ]; then
        printf '%s\n' "$candidate_path"
        return 0
      fi
    fi
  done

  candidate_path="./devbox.d/android/${subpath#/}"
  if [ -e "$candidate_path" ]; then
    printf '%s\n' "$candidate_path"
    return 0
  fi

  return 1
}

android_resolve_config_dir() {
  if [ -n "${ANDROID_CONFIG_DIR:-}" ] && [ -d "${ANDROID_CONFIG_DIR}" ]; then
    printf '%s\n' "${ANDROID_CONFIG_DIR}"
    return 0
  fi

  for base_var_name in DEVBOX_PROJECT_ROOT DEVBOX_PROJECT_DIR DEVBOX_WD; do
    base_path="$(eval "printf '%s' \"\${${base_var_name}:-}\"")"
    if [ -n "$base_path" ]; then
      candidate_dir="${base_path%/}/devbox.d/android"
      if [ -d "$candidate_dir" ]; then
        printf '%s\n' "$candidate_dir"
        return 0
      fi
    fi
  done

  if [ -d "./devbox.d/android" ]; then
    printf '%s\n' "./devbox.d/android"
    return 0
  fi

  return 1
}

# Requirement checks
android_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required" >&2
    exit 1
  fi
}

android_require_tool() {
  tool_name="$1"
  error_message="${2:-Missing required tool: $tool_name}"
  if ! command -v "$tool_name" >/dev/null 2>&1; then
    echo "ERROR: $error_message" >&2
    exit 1
  fi
}

android_require_dir_contains() {
  base_dir="$1"
  required_subpath="$2"
  error_message="${3:-Missing required path: $base_dir/$required_subpath}"
  full_path="${base_dir%/}/${required_subpath#/}"
  if [ ! -e "$full_path" ]; then
    echo "ERROR: $error_message" >&2
    exit 1
  fi
}
