#!/usr/bin/env bash
# iOS Plugin - Core Xcode and Environment Setup
# Extracted from env.sh to eliminate circular dependencies

set -e

if ! (return 0 2>/dev/null); then
  echo "ERROR: core.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${IOS_CORE_LOADED:-}" = "1" ] && [ "${IOS_CORE_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_CORE_LOADED=1
IOS_CORE_LOADED_PID="$$"

# Source dependencies
if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -f "${IOS_SCRIPTS_DIR}/lib/lib.sh" ]; then
  . "${IOS_SCRIPTS_DIR}/lib/lib.sh"
fi

# ============================================================================
# Debug Utilities
# ============================================================================

ios_debug_enabled() {
  [ "${IOS_DEBUG:-}" = "1" ] || [ "${DEBUG:-}" = "1" ]
}

ios_debug_log_script() {
  if ios_debug_enabled; then
    if (return 0 2>/dev/null); then
      context="sourced"
    else
      context="run"
    fi
    ios_log_debug "$1 ($context)"
  fi
}

ios_debug_dump_vars() {
  if ios_debug_enabled; then
    for var in "$@"; do
      value="$(eval "printf '%s' \"\${$var-}\"")"
      ios_log_debug "${var}=${value}"
    done
  fi
}

# ============================================================================
# Xcode Discovery
# ============================================================================

# Get latest Xcode developer directory by version
ios_latest_xcode_dev_dir() {
  entries=""
  for app in /Applications/Xcode*.app /Applications/Xcode.app; do
    [ -d "$app/Contents/Developer" ] || continue
    version="0"
    if [ -x /usr/libexec/PlistBuddy ] && [ -f "$app/Contents/Info.plist" ]; then
      version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist" 2>/dev/null || printf '0')"
    fi
    entries="${entries}${version}|${app}/Contents/Developer
"
  done
  if [ -n "$entries" ]; then
    printf '%s' "$entries" | sort -Vr | head -n1 | cut -d'|' -f2
  fi
}

# Resolve developer directory with multiple fallback strategies
# Priority: IOS_DEVELOPER_DIR env > xcode-select > latest Xcode scan > fallback
ios_resolve_developer_dir() {
  desired="${IOS_DEVELOPER_DIR:-}"
  if [ -n "$desired" ] && [ -d "$desired" ]; then
    printf '%s\n' "$desired"
    return 0
  fi

  # Prefer xcode-select (respects system/CI Xcode pinning via sudo xcode-select -s)
  if command -v xcode-select >/dev/null 2>&1; then
    desired="$(xcode-select -p 2>/dev/null || true)"
    if [ -n "$desired" ] && [ -d "$desired" ]; then
      printf '%s\n' "$desired"
      return 0
    fi
  fi

  # Fallback: scan /Applications for highest-version Xcode
  desired="$(ios_latest_xcode_dev_dir 2>/dev/null || true)"
  if [ -n "$desired" ] && [ -d "$desired" ]; then
    printf '%s\n' "$desired"
    return 0
  fi

  if [ -d /Applications/Xcode.app/Contents/Developer ]; then
    printf '%s\n' "/Applications/Xcode.app/Contents/Developer"
    return 0
  fi

  return 1
}

# ============================================================================
# Devbox Binary Resolution
# ============================================================================

ios_resolve_devbox_bin() {
  if [ -n "${DEVBOX_BIN:-}" ] && [ -x "$DEVBOX_BIN" ]; then
    printf '%s\n' "$DEVBOX_BIN"
    return 0
  fi
  if command -v devbox >/dev/null 2>&1; then
    command -v devbox
    return 0
  fi
  if [ -n "${DEVBOX_INIT_PATH:-}" ]; then
    devbox_bin="$(PATH="$DEVBOX_INIT_PATH:$PATH" command -v devbox 2>/dev/null || true)"
    if [ -n "$devbox_bin" ]; then
      DEVBOX_BIN="$devbox_bin"
      export DEVBOX_BIN
      printf '%s\n' "$devbox_bin"
      return 0
    fi
  fi
  for candidate in "$HOME/.nix-profile/bin/devbox" "/usr/local/bin/devbox" "/opt/homebrew/bin/devbox"; do
    if [ -x "$candidate" ]; then
      DEVBOX_BIN="$candidate"
      export DEVBOX_BIN
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# ============================================================================
# Environment Setup
# ============================================================================

# Setup Darwin environment for iOS (use system Xcode/tools instead of Nix)
#
# Nix's mkShell/stdenv sets ~80 build environment variables (CC, NIX_CFLAGS_COMPILE,
# DEVELOPER_DIR pointing to Nix's apple-sdk, etc.) that interfere with Xcode's native
# build system. This function strips those variables so xcodebuild uses Apple's toolchain.
#
# This is equivalent to what `devbox shellenv --omit-nix-env` does, but implemented
# explicitly so we don't depend on an undocumented flag.
ios_setup_native_toolchain() {
  if [ "${IOS_NATIVE_TOOLCHAIN_APPLIED:-}" = "1" ]; then
    return 0
  fi

  if [ "$(uname -s)" = "Darwin" ]; then
    # --- Unset Nix stdenv build variables ---

    # Standard build tool overrides
    unset AR AS LD NM OBJCOPY OBJDUMP RANLIB SIZE STRINGS STRIP

    # Compiler flags (Nix injects -isystem and -L paths to Nix store)
    unset CFLAGS LDFLAGS
    unset NIX_CFLAGS_COMPILE NIX_LDFLAGS

    # Nix toolchain pointers
    unset NIX_CC NIX_BINTOOLS
    unset NIX_HARDENING_ENABLE
    unset NIX_ENFORCE_NO_NATIVE
    unset NIX_DONT_SET_RPATH NIX_DONT_SET_RPATH_FOR_BUILD NIX_NO_SELF_RPATH
    unset NIX_IGNORE_LD_THROUGH_GCC NIX_BUILD_CORES
    unset NIX_APPLE_SDK_VERSION

    # Unset platform-specific Nix wrapper target variables
    # (e.g., NIX_CC_WRAPPER_TARGET_HOST_arm64_apple_darwin)
    for _ntc_var in $(env 2>/dev/null | sed -n 's/^\(NIX_[A-Z_]*WRAPPER_TARGET_HOST[^=]*\)=.*/\1/p'); do
      unset "$_ntc_var"
    done

    # SDK/deployment variables (let Xcode resolve these from DEVELOPER_DIR)
    # DEVELOPER_DIR from Nix points to Nix's apple-sdk, not real Xcode
    unset SDKROOT DEVELOPER_DIR MACOSX_DEPLOYMENT_TARGET LD_DYLD_PATH

    # --- Set native Apple toolchain ---

    if [ -x /usr/bin/clang ]; then
      CC=/usr/bin/clang
      CXX=/usr/bin/clang++
      export CC CXX
    fi

    dev_dir="$(ios_resolve_developer_dir 2>/dev/null || true)"
    if [ -n "$dev_dir" ]; then
      DEVELOPER_DIR="$dev_dir"
      export DEVELOPER_DIR
    fi

    # --- Clean PATH: remove Nix build toolchain, keep packages ---
    # Nix stdenv adds clang-wrapper, cctools, xcbuild to PATH which shadow
    # system/Xcode tools. Filter those out while keeping everything else.
    # Nix package binaries remain accessible via .devbox/nix/profile/default/bin.
    _ntc_clean=""
    _ntc_oifs="$IFS"
    IFS=":"
    for _ntc_dir in $PATH; do
      case "$_ntc_dir" in
        /nix/store/*clang-wrapper*) continue ;;
        /nix/store/*clang-[0-9]*) continue ;;
        /nix/store/*cctools*) continue ;;
        /nix/store/*xcbuild*) continue ;;
      esac
      _ntc_clean="${_ntc_clean:+$_ntc_clean:}$_ntc_dir"
    done
    IFS="$_ntc_oifs"

    # Prepend Xcode and system tool paths
    PATH="/usr/bin:/bin:/usr/sbin:/sbin"
    if [ -n "${DEVELOPER_DIR:-}" ]; then
      PATH="$DEVELOPER_DIR/usr/bin:$PATH"
    fi
    PATH="$PATH:$_ntc_clean"
    export PATH
  fi

  export IOS_NATIVE_TOOLCHAIN_APPLIED=1
}

# Setup macOS system PATH and DEVELOPER_DIR
ios_setup_environment() {
  # Add macOS system tools to PATH for pure environments
  if [ "$(uname -s)" = "Darwin" ]; then
    PATH="/usr/bin:${PATH}"
    export PATH
    ios_log_debug "Added /usr/bin to PATH for macOS system tools"
  fi

  # Setup omit-nix-env
  ios_setup_native_toolchain

  # Ensure DEVELOPER_DIR is set
  if [ "$(uname -s)" = "Darwin" ]; then
    PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
    export PATH
    if [ -z "${DEVELOPER_DIR:-}" ]; then
      dev_dir="$(ios_resolve_developer_dir 2>/dev/null || true)"
      if [ -n "${dev_dir:-}" ] && [ -d "$dev_dir" ]; then
        DEVELOPER_DIR="$dev_dir"
        PATH="$DEVELOPER_DIR/usr/bin:$PATH"
        export DEVELOPER_DIR PATH
      fi
    fi
  fi

  # Detect Node.js binary
  if [ -z "${IOS_NODE_BINARY:-}" ] && command -v node >/dev/null 2>&1; then
    IOS_NODE_BINARY="$(command -v node)"
    export IOS_NODE_BINARY
  fi

  # Make scripts executable and add to PATH
  if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -d "${IOS_SCRIPTS_DIR}" ]; then
    # Make all scripts executable
    find "${IOS_SCRIPTS_DIR}" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

    # Add user/ directory to PATH (contains ios.sh, devices.sh)
    if [ -d "${IOS_SCRIPTS_DIR}/user" ]; then
      PATH="${IOS_SCRIPTS_DIR}/user:$PATH"
      export PATH
    fi
  fi
}

# ============================================================================
# Summary Display
# ============================================================================

ios_show_summary() {
  ios_runtime="${IOS_DEFAULT_RUNTIME:-}"
  if [ -z "$ios_runtime" ] && command -v xcrun >/dev/null 2>&1; then
    ios_runtime="$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null || true)"
  fi

  xcode_dir="${DEVELOPER_DIR:-}"
  if [ -z "$xcode_dir" ] && command -v xcode-select >/dev/null 2>&1; then
    xcode_dir="$(xcode-select -p 2>/dev/null || true)"
  fi

  xcode_version="unknown"
  if command -v xcodebuild >/dev/null 2>&1; then
    xcode_version="$(xcodebuild -version 2>/dev/null | awk 'NR==1{print $2}')"
  fi

  ios_target_device="${IOS_DEFAULT_DEVICE:-}"
  ios_target_runtime="${ios_runtime:-}"

  echo "Resolved iOS SDK"
  echo "  DEVELOPER_DIR: ${xcode_dir:-not set}"
  echo "  XCODE_VERSION: ${xcode_version:-unknown}"
  echo "  IOS_RUNTIME: ${ios_runtime:-not set}"
  echo "  IOS_SIM_TARGET: device=${ios_target_device:-unknown} runtime=${ios_target_runtime:-not set}"
}

ios_debug_log_script "core.sh"
