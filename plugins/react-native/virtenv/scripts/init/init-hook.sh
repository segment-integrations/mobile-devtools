#!/usr/bin/env bash
# React Native Plugin - Initialization Hook
# Adds React Native scripts to PATH
# NOTE: This file is sourced (not executed) by devbox init_hook,
# so it must be POSIX sh compatible (no bash-isms).

# ============================================================================
# Smart Platform Detection
# Automatically skip unnecessary platform setup to speed up initialization
# ============================================================================

# Skip if user explicitly wants all platforms
if [ "${RN_REQUIRE_ALL_PLATFORMS:-0}" != "1" ]; then
  # 1. Command-based detection (highest priority)
  if [ -n "${DEVBOX_RUN_COMMAND:-}" ]; then
    case "$DEVBOX_RUN_COMMAND" in
      # iOS commands - skip Android
      *ios.sh*|*pod\ *|*xcodebuild*|*xcrun*|*simulator*)
        export ANDROID_SKIP_SETUP=1
        ;;
      # Android commands - skip iOS
      *android.sh*|*gradlew*|*adb*|*emulator*|*/android/*)
        export IOS_SKIP_SETUP=1
        ;;
    esac
  fi

  # 2. Project structure detection (fallback)
  # Only applies if skip flags not already set
  if [ -z "${ANDROID_SKIP_SETUP:-}" ] && [ -z "${IOS_SKIP_SETUP:-}" ]; then
    project_root="${DEVBOX_PROJECT_ROOT:-${PWD}}"
    has_ios=0
    has_android=0

    [ -d "$project_root/ios" ] && has_ios=1
    [ -d "$project_root/android" ] && has_android=1

    # iOS-only project
    if [ $has_ios -eq 1 ] && [ $has_android -eq 0 ]; then
      export ANDROID_SKIP_SETUP=1
    fi

    # Android-only project
    if [ $has_android -eq 1 ] && [ $has_ios -eq 0 ]; then
      export IOS_SKIP_SETUP=1
    fi
  fi
fi

# Add React Native scripts to PATH if not already present
if [ -n "${REACT_NATIVE_SCRIPTS_DIR:-}" ] && [ -d "${REACT_NATIVE_SCRIPTS_DIR}" ]; then
  # Add user-facing scripts (rn.sh, metro.sh) to PATH
  USER_SCRIPTS_DIR="${REACT_NATIVE_SCRIPTS_DIR}/user"
  if [ -d "$USER_SCRIPTS_DIR" ]; then
    # Make scripts executable
    chmod +x "$USER_SCRIPTS_DIR"/*.sh 2>/dev/null || true

    # Add to PATH if not already present
    case ":$PATH:" in
      *":$USER_SCRIPTS_DIR:"*) ;;
      *) export PATH="$USER_SCRIPTS_DIR:$PATH" ;;
    esac
  fi
fi
