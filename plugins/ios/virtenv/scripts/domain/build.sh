#!/usr/bin/env sh
# iOS Plugin - Build Command
# Auto-detects Xcode project and builds with sensible defaults

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: build.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${IOS_BUILD_LOADED:-}" = "1" ] && [ "${IOS_BUILD_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_BUILD_LOADED=1
IOS_BUILD_LOADED_PID="$$"

# Source dependencies
if [ -n "${IOS_SCRIPTS_DIR:-}" ]; then
  if [ -f "${IOS_SCRIPTS_DIR}/lib/lib.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/lib/lib.sh"
  fi
  if [ -f "${IOS_SCRIPTS_DIR}/platform/core.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/platform/core.sh"
  fi
fi

ios_log_debug "build.sh loaded"

# ============================================================================
# Project Detection
# ============================================================================

# Find Xcode project (.xcworkspace or .xcodeproj) in a directory.
# Prefers .xcworkspace over .xcodeproj.
# Args: directory
# Returns: path to project file, or empty string
_ios_find_project_in_dir() {
  _dir="$1"
  [ -d "$_dir" ] || return 1

  for _f in "$_dir"/*.xcworkspace; do
    if [ -d "$_f" ]; then
      # Skip Pods workspace
      case "$(basename "$_f")" in
        Pods.xcworkspace) continue ;;
      esac
      printf '%s\n' "$_f"
      return 0
    fi
  done

  for _f in "$_dir"/*.xcodeproj; do
    if [ -d "$_f" ]; then
      printf '%s\n' "$_f"
      return 0
    fi
  done

  return 1
}

# Auto-detect Xcode project using standard search order.
# Search order:
#   1. Current working directory
#   2. $DEVBOX_PROJECT_ROOT (if different from PWD)
#   3. $PWD/ios/ (React Native convention)
#   4. $DEVBOX_PROJECT_ROOT/ios/ (if different)
# Returns: path to .xcworkspace or .xcodeproj
ios_detect_project() {
  _project_root="${DEVBOX_PROJECT_ROOT:-}"

  # 1. Current working directory
  _proj="$(_ios_find_project_in_dir "$PWD" 2>/dev/null || true)"
  if [ -n "$_proj" ]; then
    printf '%s\n' "$_proj"
    return 0
  fi

  # 2. DEVBOX_PROJECT_ROOT (if different)
  if [ -n "$_project_root" ]; then
    _root_real="$(cd "$_project_root" && pwd -P 2>/dev/null || true)"
    _cwd_real="$(cd "$PWD" && pwd -P 2>/dev/null || true)"
    if [ "$_root_real" != "$_cwd_real" ]; then
      _proj="$(_ios_find_project_in_dir "$_project_root" 2>/dev/null || true)"
      if [ -n "$_proj" ]; then
        printf '%s\n' "$_proj"
        return 0
      fi
    fi
  fi

  # 3. PWD/ios/ (React Native convention)
  if [ -d "$PWD/ios" ]; then
    _proj="$(_ios_find_project_in_dir "$PWD/ios" 2>/dev/null || true)"
    if [ -n "$_proj" ]; then
      printf '%s\n' "$_proj"
      return 0
    fi
  fi

  # 4. DEVBOX_PROJECT_ROOT/ios/ (if different)
  if [ -n "$_project_root" ] && [ -d "$_project_root/ios" ]; then
    _root_real="$(cd "$_project_root" && pwd -P 2>/dev/null || true)"
    _cwd_real="$(cd "$PWD" && pwd -P 2>/dev/null || true)"
    if [ "$_root_real" != "$_cwd_real" ]; then
      _proj="$(_ios_find_project_in_dir "$_project_root/ios" 2>/dev/null || true)"
      if [ -n "$_proj" ]; then
        printf '%s\n' "$_proj"
        return 0
      fi
    fi
  fi

  return 1
}

# ============================================================================
# Build Function
# ============================================================================

# Build an iOS project with xcodebuild.
#
# Args (all optional, parsed as flags):
#   --config Debug|Release     Build configuration (default: $IOS_BUILD_CONFIG or Debug)
#   --scheme name              Xcode scheme (default: $IOS_APP_SCHEME or auto-detect)
#   --workspace path           Path to .xcworkspace
#   --project path             Path to .xcodeproj
#   --derived-data path        DerivedData path (default: $IOS_DERIVED_DATA_PATH)
#   --quiet                    Suppress xcodebuild output
#   --action build|test        xcodebuild action (default: build)
#   -- extra_args...           Extra arguments passed to xcodebuild
ios_build() {
  _config="${IOS_BUILD_CONFIG:-Debug}"
  _scheme="${IOS_APP_SCHEME:-}"
  _workspace=""
  _project_path=""
  _derived_data="${IOS_DERIVED_DATA_PATH:-}"
  _quiet=0
  _action="build"

  # Parse arguments - everything after -- stays in "$@" for passthrough
  while [ $# -gt 0 ]; do
    case "$1" in
      --config)
        _config="$2"
        shift 2
        ;;
      --scheme)
        _scheme="$2"
        shift 2
        ;;
      --workspace)
        _workspace="$2"
        shift 2
        ;;
      --project)
        _project_path="$2"
        shift 2
        ;;
      --derived-data)
        _derived_data="$2"
        shift 2
        ;;
      --quiet)
        _quiet=1
        shift
        ;;
      --action)
        _action="$2"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        ios_log_error "build.sh" "Unknown flag: $1"
        return 1
        ;;
    esac
  done
  # After the loop, "$@" contains any extra args passed after --

  # Resolve project if not explicitly provided
  if [ -z "$_workspace" ] && [ -z "$_project_path" ]; then
    _explicit="${IOS_APP_PROJECT:-}"
    if [ -n "$_explicit" ]; then
      case "$_explicit" in
        *.xcworkspace) _workspace="$_explicit" ;;
        *.xcodeproj)   _project_path="$_explicit" ;;
        *)
          ios_log_error "build.sh" "IOS_APP_PROJECT must be a .xcworkspace or .xcodeproj path"
          return 1
          ;;
      esac
    else
      _detected="$(ios_detect_project || true)"
      if [ -z "$_detected" ]; then
        ios_log_error "build.sh" "No Xcode project found. Searched: PWD, DEVBOX_PROJECT_ROOT, PWD/ios/, DEVBOX_PROJECT_ROOT/ios/"
        ios_log_error "build.sh" "Use --workspace or --project to specify explicitly, or set IOS_APP_PROJECT"
        return 1
      fi
      case "$_detected" in
        *.xcworkspace) _workspace="$_detected" ;;
        *.xcodeproj)   _project_path="$_detected" ;;
      esac
    fi
  fi

  # Determine xcodebuild flag
  if [ -n "$_workspace" ]; then
    _xc_flag="-workspace"
    _xc_path="$_workspace"
  else
    _xc_flag="-project"
    _xc_path="$_project_path"
  fi

  # Derive scheme from project name if not set
  if [ -z "$_scheme" ]; then
    _scheme="$(basename "$_xc_path" | sed 's/\.\(xcworkspace\|xcodeproj\)$//')"
  fi

  # Default DerivedData path
  if [ -z "$_derived_data" ]; then
    if [ -n "${DEVBOX_PROJECT_ROOT:-}" ]; then
      _derived_data="${DEVBOX_PROJECT_ROOT}/.devbox/virtenv/ios/DerivedData"
    else
      _derived_data="$PWD/.devbox/virtenv/ios/DerivedData"
    fi
  fi

  mkdir -p "$_derived_data"

  # Build xcodebuild command
  ios_log_info "build.sh" "Building: $_xc_path (scheme=$_scheme, config=$_config, action=$_action)"

  # Build the full argument list preserving quoting for all values
  # Prepend xcodebuild flags to the remaining "$@" (extra args after --)
  set -- "$_xc_flag" "$_xc_path" \
    -scheme "$_scheme" \
    -configuration "$_config" \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$_derived_data" \
    "$@"

  if [ "$_quiet" = "1" ]; then
    set -- "$@" -quiet
  fi

  # Append the action (build, test, etc.)
  set -- "$@" "$_action"

  xcodebuild "$@"
}
