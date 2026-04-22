#!/usr/bin/env bash
# Android Plugin - Doctor Script
# Comprehensive health check for Android environment with exit codes
#
# Exit codes:
#   0 = All checks passed
#   1 = Warnings detected (non-fatal issues)
#   2 = Fatal errors (critical failures)

set -eu

# Source doctor library
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/lib/doctor.sh" ]; then
  . "${ANDROID_SCRIPTS_DIR}/lib/doctor.sh"
else
  echo "ERROR: Doctor library not found" >&2
  exit 2
fi

# Source drift detection if available
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ] && [ -f "${ANDROID_SCRIPTS_DIR}/platform/drift.sh" ]; then
  . "${ANDROID_SCRIPTS_DIR}/platform/drift.sh"
fi

# Initialize doctor state
doctor_init

# Print header
echo ""
doctor_color_bold "Android Environment Check"
echo "========================="

# ============================================================================
# Section 1: Android SDK
# ============================================================================

doctor_print_section "Android SDK"

# Check ANDROID_SDK_ROOT is set
if [ -n "${ANDROID_SDK_ROOT:-}" ]; then
  doctor_check_pass "ANDROID_SDK_ROOT is set"

  # Check SDK directory exists
  if [ -d "${ANDROID_SDK_ROOT}" ]; then
    doctor_check_pass "SDK directory exists"
  else
    doctor_check_error "SDK directory exists" "Directory not found: ${ANDROID_SDK_ROOT}"
  fi
else
  doctor_check_error "ANDROID_SDK_ROOT is set" "Environment variable not set"
fi

# Check ANDROID_HOME consistency
if [ -n "${ANDROID_HOME:-}" ]; then
  if [ "${ANDROID_HOME}" = "${ANDROID_SDK_ROOT:-}" ]; then
    doctor_check_pass "ANDROID_HOME matches ANDROID_SDK_ROOT"
  else
    doctor_check_warn "ANDROID_HOME matches ANDROID_SDK_ROOT" "ANDROID_HOME=${ANDROID_HOME} != ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-}"
  fi
fi

# ============================================================================
# Section 2: AVD Environment
# ============================================================================

doctor_print_section "AVD Environment"

# Check ANDROID_AVD_HOME
if [ -n "${ANDROID_AVD_HOME:-}" ]; then
  doctor_check_pass "ANDROID_AVD_HOME is set"

  # Check directory is writable
  if [ -d "${ANDROID_AVD_HOME}" ]; then
    if [ -w "${ANDROID_AVD_HOME}" ]; then
      doctor_check_pass "AVD directory is writable"
    else
      doctor_check_warn "AVD directory is writable" "Directory exists but is not writable: ${ANDROID_AVD_HOME}"
    fi
  else
    doctor_check_warn "AVD directory exists" "Directory will be created on first use: ${ANDROID_AVD_HOME}"
  fi
else
  doctor_check_warn "ANDROID_AVD_HOME is set" "Environment variable not set"
fi

# Check ANDROID_USER_HOME
doctor_check_env_var "ANDROID_USER_HOME" "ANDROID_USER_HOME is set" "false"

# ============================================================================
# Section 3: Essential Tools
# ============================================================================

doctor_print_section "Essential Tools"

# Critical tools (errors if missing)
doctor_check_command "adb" "adb" "true"
doctor_check_command "emulator" "emulator" "true"

# Nice-to-have tools (warnings if missing)
doctor_check_command "avdmanager" "avdmanager" "false"
doctor_check_command "sdkmanager" "sdkmanager" "false"

# Check jq (needed for config operations)
doctor_check_command "jq" "jq (for config operations)" "false"

# ============================================================================
# Section 4: Device Configuration
# ============================================================================

doctor_print_section "Device Configuration"

# Resolve device directory
config_dir=$(doctor_resolve_config_dir)
devices_dir="$config_dir/devices"

# Check devices directory exists
if [ -d "$devices_dir" ]; then
  doctor_check_pass "Devices directory exists"

  # Count device definition files
  device_count=$(find "$devices_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$device_count" -gt 0 ]; then
    doctor_check_pass "Device definitions found ($device_count files)"
  else
    doctor_check_warn "Device definitions found" "No device JSON files in $devices_dir"
  fi

  # Check devices.lock file
  if [ -f "$devices_dir/devices.lock" ]; then
    doctor_check_pass "devices.lock exists"
  else
    doctor_check_warn "devices.lock exists" "Lock file not generated yet. Run: devbox shell"
  fi
else
  doctor_check_error "Devices directory exists" "Directory not found: $devices_dir"
fi

# Check ANDROID_DEVICES filter
if [ -n "${ANDROID_DEVICES:-}" ]; then
  printf "  %s ANDROID_DEVICES filter: %s\n" "$(doctor_color_green "ℹ")" "$ANDROID_DEVICES"
else
  printf "  %s ANDROID_DEVICES filter: (all devices)\n" "$(doctor_color_green "ℹ")"
fi

# ============================================================================
# Section 5: Configuration Sync
# ============================================================================

doctor_print_section "Configuration Sync"

android_lock="$config_dir/android.lock"

# Check android.lock exists
if [ ! -f "$android_lock" ]; then
  doctor_check_warn "android.lock exists" "Lock file not found. Run: devbox run android:sync"
elif ! command -v jq >/dev/null 2>&1; then
  doctor_check_warn "Configuration drift check" "jq not available, cannot check drift"
elif command -v android_check_config_drift >/dev/null 2>&1; then
  # Use shared drift detection function
  android_check_config_drift

  if [ "${ANDROID_DRIFT_DETECTED:-false}" = true ]; then
    doctor_check_warn "Configuration drift" "Env vars don't match android.lock. Fix: devbox run android:sync"
  else
    doctor_check_pass "Configuration drift"
  fi
else
  doctor_check_warn "Configuration drift check" "Drift detection function not available"
fi

# ============================================================================
# Section 6: Hash Overrides
# ============================================================================

doctor_print_section "Hash Overrides"

if [ -f "$android_lock" ] && command -v jq >/dev/null 2>&1; then
  if jq -e '.hash_overrides' "$android_lock" >/dev/null 2>&1; then
    override_count=$(jq '.hash_overrides | length' "$android_lock")
    if [ "$override_count" -gt 0 ]; then
      doctor_check_warn "Hash overrides" "$override_count override(s) active. View: android.sh hash show"
    else
      doctor_check_pass "Hash overrides (none active)"
    fi
  else
    doctor_check_pass "Hash overrides (none active)"
  fi
else
  doctor_check_warn "Hash overrides check" "Cannot check (android.lock not found or jq unavailable)"
fi

# ============================================================================
# Section 7: Project Structure
# ============================================================================

doctor_print_section "Project Structure"

# Check for android/ directory (common structure)
if [ -d "android" ]; then
  doctor_check_pass "android/ directory found"

  # Check for build.gradle or build.gradle.kts
  if [ -f "android/build.gradle" ] || [ -f "android/build.gradle.kts" ]; then
    doctor_check_pass "Gradle build file found"
  else
    doctor_check_warn "Gradle build file" "No build.gradle or build.gradle.kts in android/"
  fi

  # Check for app module
  if [ -d "android/app" ]; then
    doctor_check_pass "app module found"
  else
    doctor_check_warn "app module" "No android/app directory found"
  fi
else
  # Not an error - may be using plugin without an Android project
  printf "  %s android/ directory: not found (may not be an Android project)\n" "$(doctor_color_green "ℹ")"
fi

# ============================================================================
# Section 8: System Resources
# ============================================================================

doctor_print_section "System Resources"

# Check disk space (warn if < 10GB free)
doctor_check_disk_space 10

# Check available memory (if possible)
if command -v free >/dev/null 2>&1; then
  available_mb=$(free -m | awk '/^Mem:/ {print $7}')
  if [ "$available_mb" -gt 2048 ]; then
    doctor_check_pass "Available memory (>= 2GB)"
  else
    doctor_check_warn "Available memory" "Only ${available_mb}MB available (recommended: >= 2GB for emulator)"
  fi
elif command -v vm_stat >/dev/null 2>&1; then
  # macOS
  free_pages=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
  available_mb=$((free_pages * 4096 / 1024 / 1024))
  if [ "$available_mb" -gt 2048 ]; then
    doctor_check_pass "Available memory (>= 2GB)"
  else
    doctor_check_warn "Available memory" "Only ${available_mb}MB available (recommended: >= 2GB for emulator)"
  fi
fi

# ============================================================================
# Print Summary and Exit
# ============================================================================

doctor_print_summary

exit $(doctor_get_exit_code)
