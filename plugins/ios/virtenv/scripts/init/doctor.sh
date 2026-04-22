#!/usr/bin/env bash
# iOS Plugin - Doctor Init Check
# Lightweight health check run on shell init with exit codes
# Shows ✓ if all good, warnings if issues detected
#
# Exit codes:
#   0 = All checks passed
#   1 = Warnings detected (non-fatal issues)
#   2 = Fatal errors (critical failures)

set -eu

# Source doctor library
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -f "${IOS_SCRIPTS_DIR}/lib/doctor.sh" ]; then
  . "${IOS_SCRIPTS_DIR}/lib/doctor.sh"
fi

# Initialize doctor state
doctor_init

# Suppress output - collect issues silently
issues=()

# Check 1: Xcode command line tools
if ! xcrun --show-sdk-path >/dev/null 2>&1; then
  issues+=("Xcode command line tools not available")
  DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
else
  DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
fi

# Check 2: Essential tools
if ! command -v xcrun >/dev/null 2>&1; then
  issues+=("xcrun not in PATH")
  DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
else
  DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
fi

if ! xcrun simctl list devices >/dev/null 2>&1; then
  issues+=("xcrun simctl not working")
  DOCTOR_CHECKS_ERRORED=$((DOCTOR_CHECKS_ERRORED + 1))
else
  DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
fi

# Check 3: Device lock file
config_dir=$(doctor_resolve_config_dir 2>/dev/null || echo "${IOS_CONFIG_DIR:-./devbox.d/ios}")
devices_dir="${IOS_DEVICES_DIR:-${config_dir}/devices}"
lock_file="${devices_dir}/devices.lock"

if [ ! -f "$lock_file" ]; then
  issues+=("devices.lock not found (run devbox shell to generate)")
  DOCTOR_CHECKS_WARNED=$((DOCTOR_CHECKS_WARNED + 1))
else
  DOCTOR_CHECKS_PASSED=$((DOCTOR_CHECKS_PASSED + 1))
fi

# Output results
if [ ${#issues[@]} -eq 0 ]; then
  echo "✓ iOS"
else
  echo "⚠️  iOS issues detected:" >&2
  for issue in "${issues[@]}"; do
    echo "  - $issue" >&2
  done
  echo "  Run 'devbox run doctor' for more details" >&2
fi

# Exit with appropriate code
exit $(doctor_get_exit_code)
