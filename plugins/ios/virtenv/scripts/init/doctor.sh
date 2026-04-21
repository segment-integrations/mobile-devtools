#!/usr/bin/env bash
# iOS Plugin - Doctor Init Check
# Lightweight health check run on shell init
# Shows ✓ if all good, warnings if issues detected

set -eu

# Silent mode - only output if there are issues
issues=()

# Check 1: Xcode command line tools
if ! xcrun --show-sdk-path >/dev/null 2>&1; then
  issues+=("Xcode command line tools not available")
fi

# Check 2: Essential tools
if ! command -v xcrun >/dev/null 2>&1; then
  issues+=("xcrun not in PATH")
fi

if ! xcrun simctl list devices >/dev/null 2>&1; then
  issues+=("xcrun simctl not working")
fi

# Check 3: Device lock file
config_dir="${IOS_CONFIG_DIR:-./devbox.d/ios}"
devices_dir="${IOS_DEVICES_DIR:-${config_dir}/devices}"
lock_file="${devices_dir}/devices.lock"

if [ ! -f "$lock_file" ]; then
  issues+=("devices.lock not found (run devbox shell to generate)")
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
