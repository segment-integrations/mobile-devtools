#!/usr/bin/env sh
# React Native Plugin - Initialization Hook
# Adds React Native scripts to PATH
# NOTE: This file is sourced (not executed) by devbox init_hook,
# so it must be POSIX sh compatible (no bash-isms).

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
