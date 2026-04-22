#!/usr/bin/env bash
# iOS Plugin - Doctor Script
# Comprehensive health check for iOS environment with exit codes
#
# Exit codes:
#   0 = All checks passed
#   1 = Warnings detected (non-fatal issues)
#   2 = Fatal errors (critical failures)

set -eu

# Source doctor library
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -f "${IOS_SCRIPTS_DIR}/lib/doctor.sh" ]; then
  . "${IOS_SCRIPTS_DIR}/lib/doctor.sh"
else
  echo "ERROR: Doctor library not found" >&2
  exit 2
fi

# Initialize doctor state
doctor_init

# Print header
echo ""
doctor_color_bold "iOS Environment Check"
echo "===================="

# ============================================================================
# Section 1: Xcode and Developer Tools
# ============================================================================

doctor_print_section "Xcode and Developer Tools"

# Check IOS_DEVELOPER_DIR
if [ -n "${IOS_DEVELOPER_DIR:-}" ]; then
  doctor_check_pass "IOS_DEVELOPER_DIR is set"

  # Verify directory exists
  if [ -d "${IOS_DEVELOPER_DIR}" ]; then
    doctor_check_pass "Developer directory exists"
  else
    doctor_check_error "Developer directory exists" "Directory not found: ${IOS_DEVELOPER_DIR}"
  fi
else
  doctor_check_pass "IOS_DEVELOPER_DIR (using xcode-select default)"
fi

# Check Xcode command line tools
if xcrun --show-sdk-path >/dev/null 2>&1; then
  doctor_check_pass "Xcode command line tools available"

  # Show SDK path for reference
  sdk_path=$(xcrun --show-sdk-path 2>/dev/null || echo "unknown")
  printf "  %s SDK path: %s\n" "$(doctor_color_green "ℹ")" "$sdk_path"
else
  doctor_check_error "Xcode command line tools available" "Not found. Install with: xcode-select --install"
fi

# Check Xcode version if available
if command -v xcodebuild >/dev/null 2>&1; then
  xcode_version=$(xcodebuild -version 2>/dev/null | head -1 || echo "unknown")
  doctor_check_pass "xcodebuild available"
  printf "  %s Xcode: %s\n" "$(doctor_color_green "ℹ")" "$xcode_version"

  # Check if version matches IOS_XCODE_VERSION env var
  if [ -n "${IOS_XCODE_VERSION:-}" ]; then
    if echo "$xcode_version" | grep -q "${IOS_XCODE_VERSION}"; then
      doctor_check_pass "Xcode version matches IOS_XCODE_VERSION"
    else
      doctor_check_warn "Xcode version matches IOS_XCODE_VERSION" "Expected ${IOS_XCODE_VERSION}, found ${xcode_version}"
    fi
  fi
else
  doctor_check_warn "xcodebuild available" "Not found (Xcode may not be fully installed)"
fi

# ============================================================================
# Section 2: Essential Tools
# ============================================================================

doctor_print_section "Essential Tools"

# Critical tools (errors if missing)
doctor_check_command "xcrun" "xcrun" "true"

# Check simctl specifically through xcrun
if xcrun simctl list devices >/dev/null 2>&1; then
  doctor_check_pass "xcrun simctl working"
else
  doctor_check_error "xcrun simctl working" "simctl not functioning correctly"
fi

# Nice-to-have tools (warnings if missing)
doctor_check_command "xcodebuild" "xcodebuild" "false"
doctor_check_command "xcbeautify" "xcbeautify (for pretty build output)" "false"
doctor_check_command "pod" "CocoaPods" "false"

# Check jq (needed for config operations)
doctor_check_command "jq" "jq (for config operations)" "false"

# ============================================================================
# Section 3: Simulator Environment
# ============================================================================

doctor_print_section "Simulator Environment"

# Check simulator runtime home
if [ -n "${IOS_SIMULATOR_HOME:-}" ]; then
  doctor_check_pass "IOS_SIMULATOR_HOME is set"
  doctor_check_dir_exists "${IOS_SIMULATOR_HOME}" "Simulator home directory" "false"
fi

# List available runtimes
if command -v xcrun >/dev/null 2>&1; then
  runtime_count=$(xcrun simctl list runtimes --json 2>/dev/null | jq -r '.runtimes | length' 2>/dev/null || echo "0")
  if [ "$runtime_count" -gt 0 ]; then
    doctor_check_pass "iOS runtimes available ($runtime_count found)"

    # Show available runtimes
    printf "  %s Available runtimes:\n" "$(doctor_color_green "ℹ")"
    xcrun simctl list runtimes --json 2>/dev/null | jq -r '.runtimes[] | "    - \(.name) (\(.identifier))"' 2>/dev/null | head -5
  else
    doctor_check_warn "iOS runtimes available" "No runtimes found. Download via Xcode → Preferences → Components"
  fi
fi

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

# Check IOS_DEVICES filter
if [ -n "${IOS_DEVICES:-}" ]; then
  printf "  %s IOS_DEVICES filter: %s\n" "$(doctor_color_green "ℹ")" "$IOS_DEVICES"
else
  printf "  %s IOS_DEVICES filter: (all devices)\n" "$(doctor_color_green "ℹ")"
fi

# ============================================================================
# Section 5: Runtime Availability
# ============================================================================

doctor_print_section "Runtime Availability"

# Check if required runtimes are available for configured devices
if [ -f "$devices_dir/devices.lock" ] && command -v jq >/dev/null 2>&1 && command -v xcrun >/dev/null 2>&1; then
  # Get required runtimes from devices.lock
  required_runtimes=$(jq -r '.devices[].runtime' "$devices_dir/devices.lock" 2>/dev/null | sort -u)

  if [ -n "$required_runtimes" ]; then
    # Get available runtimes
    available_runtimes=$(xcrun simctl list runtimes --json 2>/dev/null | jq -r '.runtimes[].identifier' 2>/dev/null)

    missing_count=0
    while IFS= read -r runtime; do
      if echo "$available_runtimes" | grep -q "$runtime"; then
        doctor_check_pass "Runtime available: $runtime"
      else
        doctor_check_warn "Runtime available: $runtime" "Not installed. Download via Xcode or set IOS_DOWNLOAD_RUNTIME=1"
        missing_count=$((missing_count + 1))
      fi
    done <<< "$required_runtimes"

    if [ "$missing_count" -gt 0 ]; then
      printf "  %s Tip: Set IOS_DOWNLOAD_RUNTIME=1 to auto-download missing runtimes\n" "$(doctor_color_yellow "💡")"
    fi
  else
    doctor_check_warn "Runtime check" "No runtimes specified in devices.lock"
  fi
else
  doctor_check_warn "Runtime check" "Cannot verify (devices.lock, jq, or xcrun not available)"
fi

# ============================================================================
# Section 6: Project Structure
# ============================================================================

doctor_print_section "Project Structure"

# Check for common iOS project structures
found_project=false

# Check for .xcodeproj
if find . -maxdepth 2 -name "*.xcodeproj" -type d 2>/dev/null | grep -q .; then
  doctor_check_pass "Xcode project (.xcodeproj) found"
  found_project=true
fi

# Check for .xcworkspace
if find . -maxdepth 2 -name "*.xcworkspace" -type d 2>/dev/null | grep -q .; then
  doctor_check_pass "Xcode workspace (.xcworkspace) found"
  found_project=true
fi

# Check for Package.swift (Swift Package)
if [ -f "Package.swift" ]; then
  doctor_check_pass "Swift Package (Package.swift) found"
  found_project=true
fi

# Check for ios/ directory (React Native structure)
if [ -d "ios" ]; then
  doctor_check_pass "ios/ directory found"
  found_project=true

  # Check for Podfile in ios/
  if [ -f "ios/Podfile" ]; then
    doctor_check_pass "Podfile found"

    # Check if pods are installed
    if [ -d "ios/Pods" ]; then
      doctor_check_pass "CocoaPods installed"
    else
      doctor_check_warn "CocoaPods installed" "Pods directory not found. Run: cd ios && pod install"
    fi
  fi
fi

if [ "$found_project" = false ]; then
  # Not an error - may be using plugin without an iOS project
  printf "  %s No iOS project detected (may not be an iOS project)\n" "$(doctor_color_green "ℹ")"
fi

# ============================================================================
# Section 7: System Resources
# ============================================================================

doctor_print_section "System Resources"

# Check disk space (warn if < 20GB free - Xcode needs more space)
doctor_check_disk_space 20

# Check available memory (if possible)
if command -v vm_stat >/dev/null 2>&1; then
  # macOS
  free_pages=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
  available_mb=$((free_pages * 4096 / 1024 / 1024))
  if [ "$available_mb" -gt 4096 ]; then
    doctor_check_pass "Available memory (>= 4GB)"
  else
    doctor_check_warn "Available memory" "Only ${available_mb}MB available (recommended: >= 4GB for Xcode)"
  fi
fi

# ============================================================================
# Section 8: Configuration
# ============================================================================

doctor_print_section "Configuration"

# Check important iOS env vars
doctor_check_env_var "IOS_CONFIG_DIR" "IOS_CONFIG_DIR is set" "false"
doctor_check_env_var "IOS_DEVICES_DIR" "IOS_DEVICES_DIR is set" "false"

# Show download runtime setting
if [ "${IOS_DOWNLOAD_RUNTIME:-1}" = "1" ]; then
  printf "  %s IOS_DOWNLOAD_RUNTIME: enabled (will auto-download runtimes)\n" "$(doctor_color_green "ℹ")"
else
  printf "  %s IOS_DOWNLOAD_RUNTIME: disabled (manual runtime installation required)\n" "$(doctor_color_yellow "ℹ")"
fi

# ============================================================================
# Print Summary and Exit
# ============================================================================

doctor_print_summary

exit $(doctor_get_exit_code)
