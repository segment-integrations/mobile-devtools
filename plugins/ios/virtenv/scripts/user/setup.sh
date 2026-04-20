#!/usr/bin/env bash
# iOS Plugin - Setup Script
# Ensures iOS development environment is ready
# Safe to call multiple times (idempotent)

set -eu

# Skip if IOS_SKIP_SETUP=1
if [ "${IOS_SKIP_SETUP:-0}" = "1" ]; then
  echo "⏭️  [SKIP] Skipping iOS setup (IOS_SKIP_SETUP=1)"
  exit 0
fi

# Only run on macOS
if [ "$(uname -s)" != "Darwin" ]; then
  echo "⏭️  [SKIP] Skipping iOS setup (not macOS)"
  exit 0
fi

echo "🔧 [SETUP] Setting up iOS environment..."

# Source the init setup if not already initialized
# (Skip if IOS_DEVELOPER_DIR is already set from devbox init_hook)
if [ -z "${IOS_DEVELOPER_DIR:-}" ]; then
  if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -f "${IOS_SCRIPTS_DIR}/init/setup.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/init/setup.sh"
  fi
fi

# Verify Xcode is available
if ! command -v xcrun >/dev/null 2>&1; then
  echo "❌ [ERROR] iOS setup failed: xcrun not found (Xcode not installed?)" >&2
  exit 1
fi

# Verify simctl works
if ! xcrun simctl list devices >/dev/null 2>&1; then
  echo "❌ [ERROR] iOS setup failed: xcrun simctl not working" >&2
  exit 1
fi

# Verify IOS_DEVELOPER_DIR is set
if [ -z "${IOS_DEVELOPER_DIR:-}" ]; then
  echo "⚠️  [WARN] IOS_DEVELOPER_DIR not set" >&2
fi

echo "✅ [OK] iOS environment ready"
echo "✅ [OK] iOS setup complete"

# Run lightweight doctor check
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -f "${IOS_SCRIPTS_DIR}/user/doctor-init.sh" ]; then
  bash "${IOS_SCRIPTS_DIR}/user/doctor-init.sh" 2>&1
fi
