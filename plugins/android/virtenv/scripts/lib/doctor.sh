#!/usr/bin/env bash
# Android Plugin - Shared Doctor Library
# Provides reusable health check functions with standardized output and exit codes
#
# Exit codes:
#   0 = All checks passed
#   1 = Warnings detected (non-fatal issues)
#   2 = Fatal errors (critical failures)

if ! (return 0 2>/dev/null); then
  echo "ERROR: doctor.sh must be sourced, not executed directly" >&2
  exit 1
fi

# Guard against multiple sourcing
if [ "${ANDROID_DOCTOR_LIB_LOADED:-}" = "1" ]; then
  return 0
fi
ANDROID_DOCTOR_LIB_LOADED=1

# ============================================================================
# State Management
# ============================================================================

# Counters for check results
DOCTOR_CHECKS_PASSED=0
DOCTOR_CHECKS_WARNED=0
DOCTOR_CHECKS_ERRORED=0

# Arrays to store messages (for summary)
DOCTOR_WARNINGS=()
DOCTOR_ERRORS=()

# Current section name (for context)
DOCTOR_CURRENT_SECTION=""

# ============================================================================
# CI Detection
# ============================================================================

doctor_is_ci() {
  [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${JENKINS_HOME:-}" ] || [ -n "${BUILDKITE:-}" ]
}

# ============================================================================
# Output Formatting
# ============================================================================

doctor_color_green() {
  if doctor_is_ci; then
    printf '%s' "$*"
  else
    printf '\033[32m%s\033[0m' "$*"
  fi
}

doctor_color_yellow() {
  if doctor_is_ci; then
    printf '%s' "$*"
  else
    printf '\033[33m%s\033[0m' "$*"
  fi
}

doctor_color_red() {
  if doctor_is_ci; then
    printf '%s' "$*"
  else
    printf '\033[31m%s\033[0m' "$*"
  fi
}

doctor_color_bold() {
  if doctor_is_ci; then
    printf '%s' "$*"
  else
    printf '\033[1m%s\033[0m' "$*"
  fi
}

# ============================================================================
# Initialization
# ============================================================================

doctor_init() {
  DOCTOR_CHECKS_PASSED=0
  DOCTOR_CHECKS_WARNED=0
  DOCTOR_CHECKS_ERRORED=0
  DOCTOR_WARNINGS=()
  DOCTOR_ERRORS=()
  DOCTOR_CURRENT_SECTION=""
}

# ============================================================================
# Section Management
# ============================================================================

doctor_print_section() {
  local section_name="$1"
  DOCTOR_CURRENT_SECTION="$section_name"
  echo ""
  doctor_color_bold "$section_name"
  echo ""
}

# ============================================================================
# Check Result Recording
# ============================================================================

doctor_check_pass() {
  local check_name="$1"
  DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
  printf "  %s %s\n" "$(doctor_color_green "✓")" "$check_name"
}

doctor_check_warn() {
  local check_name="$1"
  local message="$2"
  DOCTOR_CHECKS_WARNED=$((DOCTOR_CHECKS_WARNED + 1))

  local full_message="$check_name: $message"
  if [ -n "$DOCTOR_CURRENT_SECTION" ]; then
    full_message="[$DOCTOR_CURRENT_SECTION] $full_message"
  fi
  DOCTOR_WARNINGS+=("$full_message")

  printf "  %s %s\n" "$(doctor_color_yellow "⚠")" "$check_name"
  printf "    %s\n" "$(doctor_color_yellow "$message")"
}

doctor_check_error() {
  local check_name="$1"
  local message="$2"
  DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))

  local full_message="$check_name: $message"
  if [ -n "$DOCTOR_CURRENT_SECTION" ]; then
    full_message="[$DOCTOR_CURRENT_SECTION] $full_message"
  fi
  DOCTOR_ERRORS+=("$full_message")

  printf "  %s %s\n" "$(doctor_color_red "✗")" "$check_name"
  printf "    %s\n" "$(doctor_color_red "$message")"
}

# ============================================================================
# Exit Code Calculation
# ============================================================================

doctor_get_exit_code() {
  if [ "$DOCTOR_CHECKS_ERRORED" -gt 0 ]; then
    echo 2
  elif [ "$DOCTOR_CHECKS_WARNED" -gt 0 ]; then
    echo 1
  else
    echo 0
  fi
}

# ============================================================================
# Summary Output
# ============================================================================

doctor_print_summary() {
  local exit_code
  exit_code=$(doctor_get_exit_code)

  echo ""
  doctor_color_bold "Summary"
  echo ""

  local total_checks=$((DOCTOR_CHECKS_PASSED + DOCTOR_CHECKS_WARNED + DOCTOR_CHECKS_ERRORED))
  echo "  Checks: $total_checks total"
  echo "    $(doctor_color_green "✓") Passed: $DOCTOR_CHECKS_PASSED"

  if [ "$DOCTOR_CHECKS_WARNED" -gt 0 ]; then
    echo "    $(doctor_color_yellow "⚠") Warnings: $DOCTOR_CHECKS_WARNED"
  fi

  if [ "$DOCTOR_CHECKS_ERRORED" -gt 0 ]; then
    echo "    $(doctor_color_red "✗") Errors: $DOCTOR_CHECKS_ERRORED"
  fi

  echo ""

  # Print status
  if [ "$exit_code" -eq 0 ]; then
    echo "  Status: $(doctor_color_green "✓ All checks passed")"
  elif [ "$exit_code" -eq 1 ]; then
    echo "  Status: $(doctor_color_yellow "⚠ Warnings detected")"
  else
    echo "  Status: $(doctor_color_red "✗ Critical errors detected")"
  fi

  # Print exit code for CI
  if doctor_is_ci; then
    echo ""
    echo "  Exit Code: $exit_code"
  fi

  echo ""
}

# ============================================================================
# Path Resolution
# ============================================================================

doctor_resolve_config_dir() {
  # Try environment variable first
  if [ -n "${ANDROID_CONFIG_DIR:-}" ]; then
    echo "$ANDROID_CONFIG_DIR"
    return 0
  fi

  # Try common locations
  for candidate in \
    "./devbox.d/android" \
    "./devbox.d/segment-integrations.devbox-plugins.android" \
    "./.devbox/virtenv/android"; do
    if [ -d "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done

  # Default fallback
  echo "./devbox.d/android"
  return 1
}

doctor_resolve_devices_dir() {
  local config_dir
  config_dir=$(doctor_resolve_config_dir)
  echo "$config_dir/devices"
}

# ============================================================================
# Common Health Checks
# ============================================================================

doctor_check_env_var() {
  local var_name="$1"
  local check_name="${2:-$var_name}"
  local is_critical="${3:-false}"

  if [ -n "${!var_name:-}" ]; then
    doctor_check_pass "$check_name"
    return 0
  else
    if [ "$is_critical" = "true" ]; then
      doctor_check_error "$check_name" "$var_name is not set"
      return 2
    else
      doctor_check_warn "$check_name" "$var_name is not set"
      return 1
    fi
  fi
}

doctor_check_dir_exists() {
  local dir_path="$1"
  local check_name="$2"
  local is_critical="${3:-false}"

  if [ -d "$dir_path" ]; then
    doctor_check_pass "$check_name"
    return 0
  else
    if [ "$is_critical" = "true" ]; then
      doctor_check_error "$check_name" "Directory not found: $dir_path"
      return 2
    else
      doctor_check_warn "$check_name" "Directory not found: $dir_path"
      return 1
    fi
  fi
}

doctor_check_file_exists() {
  local file_path="$1"
  local check_name="$2"
  local is_critical="${3:-false}"

  if [ -f "$file_path" ]; then
    doctor_check_pass "$check_name"
    return 0
  else
    if [ "$is_critical" = "true" ]; then
      doctor_check_error "$check_name" "File not found: $file_path"
      return 2
    else
      doctor_check_warn "$check_name" "File not found: $file_path"
      return 1
    fi
  fi
}

doctor_check_command() {
  local cmd="$1"
  local check_name="${2:-$cmd}"
  local is_critical="${3:-false}"

  if command -v "$cmd" >/dev/null 2>&1; then
    doctor_check_pass "$check_name"
    return 0
  else
    if [ "$is_critical" = "true" ]; then
      doctor_check_error "$check_name" "Command not found: $cmd"
      return 2
    else
      doctor_check_warn "$check_name" "Command not found: $cmd"
      return 1
    fi
  fi
}

doctor_check_disk_space() {
  local min_gb="${1:-5}"
  local check_name="Disk space (>= ${min_gb}GB free)"

  if command -v df >/dev/null 2>&1; then
    # Use awk for floating-point division to get accurate GB with one decimal place
    local available_gb
    available_gb=$(df -k . | tail -1 | awk '{printf "%.1f", $4/1024/1024}')

    # Use awk for floating-point comparison since bash only does integers
    if awk -v avail="$available_gb" -v min="$min_gb" 'BEGIN {exit !(avail >= min)}'; then
      doctor_check_pass "$check_name"
      return 0
    else
      doctor_check_warn "$check_name" "Only ${available_gb}GB available (recommended: >= ${min_gb}GB)"
      return 1
    fi
  else
    doctor_check_warn "$check_name" "Unable to check disk space (df command not found)"
    return 1
  fi
}
