#!/usr/bin/env sh
# iOS Plugin - App Building and Deployment
# See REFERENCE.md for detailed documentation

set -e

if ! (return 0 2>/dev/null); then
  echo "ERROR: deploy.sh must be sourced" >&2
  exit 1
fi

if [ "${IOS_DEPLOY_LOADED:-}" = "1" ] && [ "${IOS_DEPLOY_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
IOS_DEPLOY_LOADED=1
IOS_DEPLOY_LOADED_PID="$$"

# Source dependencies
if [ -n "${IOS_SCRIPTS_DIR:-}" ]; then
  if [ -f "${IOS_SCRIPTS_DIR}/lib/lib.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/lib/lib.sh"
  fi
  if [ -f "${IOS_SCRIPTS_DIR}/platform/core.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/platform/core.sh"
  fi
fi

ios_log_debug "deploy.sh loaded"

# ============================================================================
# Project Resolution
# ============================================================================

# Resolve project root directory
ios_resolve_project_root() {
  if [ -n "${DEVBOX_PROJECT_ROOT:-}" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_ROOT%/}"
    return 0
  fi
  if [ -n "${DEVBOX_PROJECT_DIR:-}" ]; then
    printf '%s\n' "${DEVBOX_PROJECT_DIR%/}"
    return 0
  fi
  if [ -n "${DEVBOX_WD:-}" ]; then
    printf '%s\n' "${DEVBOX_WD%/}"
    return 0
  fi
  printf '%s\n' "$PWD"
}

# ============================================================================
# App Resolution
# ============================================================================

# Resolve .app path from glob pattern
# Args: project_root, app_pattern
# Returns: first matching .app directory
ios_resolve_app_glob() {
  _arg_root="$1"
  _arg_pattern="$2"

  if [ -z "$_arg_pattern" ]; then
    return 1
  fi

  # Make pattern absolute if it's relative
  if [ "${_arg_pattern#/}" = "$_arg_pattern" ]; then
    _arg_pattern="${_arg_root%/}/$_arg_pattern"
  fi

  set +f
  _matched=""
  for _candidate in $_arg_pattern; do
    if [ -d "$_candidate" ]; then
      _matched="${_matched}${_matched:+
}$_candidate"
    fi
  done
  set -f

  if [ -z "$_matched" ]; then
    return 1
  fi

  _count="$(printf '%s\n' "$_matched" | wc -l | tr -d ' ')"
  if [ "$_count" -gt 1 ]; then
    ios_log_warn "deploy.sh" "Multiple app bundles matched pattern: $_arg_pattern; using first match"
  fi

  printf '%s\n' "$_matched" | head -n1
}

# Query xcodebuild for .app path
# Args: project_root
# Returns: .app path (sets IOS_XCODEBUILD_BUNDLE_ID as side effect)
ios_resolve_app_via_xcodebuild() {
  _xc_root="$1"

  # Find Xcode project or workspace
  _xc_proj=""
  for _f in "$_xc_root"/*.xcworkspace; do
    if [ -d "$_f" ]; then
      # Skip Pods workspace
      case "$(basename "$_f")" in
        Pods.xcworkspace) continue ;;
      esac
      _xc_proj="$_f"
      break
    fi
  done
  if [ -z "$_xc_proj" ]; then
    for _f in "$_xc_root"/*.xcodeproj; do
      if [ -d "$_f" ]; then
        _xc_proj="$_f"
        break
      fi
    done
  fi

  if [ -z "$_xc_proj" ]; then
    return 1
  fi

  # Determine flag type
  case "$_xc_proj" in
    *.xcworkspace) _xc_flag="-workspace" ;;
    *.xcodeproj)   _xc_flag="-project" ;;
    *)             return 1 ;;
  esac

  # Derive scheme from project name
  _xc_scheme="$(basename "$_xc_proj" | sed 's/\.\(xcworkspace\|xcodeproj\)$//')"

  # Resolve DerivedData path (must match ios_build defaults)
  _xc_derived_data="${IOS_DERIVED_DATA_PATH:-}"
  if [ -z "$_xc_derived_data" ]; then
    if [ -n "${DEVBOX_PROJECT_ROOT:-}" ]; then
      _xc_derived_data="${DEVBOX_PROJECT_ROOT}/.devbox/virtenv/ios/DerivedData"
    else
      _xc_derived_data="$PWD/.devbox/virtenv/ios/DerivedData"
    fi
  fi

  # Query build settings with matching DerivedData path
  _settings="$(xcodebuild "$_xc_flag" "$_xc_proj" -scheme "$_xc_scheme" \
    -configuration Debug -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$_xc_derived_data" \
    -showBuildSettings 2>/dev/null || true)"

  if [ -z "$_settings" ]; then
    return 1
  fi

  _built_dir="$(printf '%s\n' "$_settings" | awk '/^\s*BUILT_PRODUCTS_DIR = /{print $3; exit}')"
  _product_name="$(printf '%s\n' "$_settings" | awk '/^\s*FULL_PRODUCT_NAME = /{print $3; exit}')"
  _bundle_id="$(printf '%s\n' "$_settings" | awk '/^\s*PRODUCT_BUNDLE_IDENTIFIER = /{print $3; exit}')"

  if [ -z "$_built_dir" ] || [ -z "$_product_name" ]; then
    return 1
  fi

  _app_path="${_built_dir%/}/$_product_name"

  if [ ! -d "$_app_path" ]; then
    return 1
  fi

  # Export bundle ID as side effect for caller
  if [ -n "$_bundle_id" ]; then
    IOS_XCODEBUILD_BUNDLE_ID="$_bundle_id"
    export IOS_XCODEBUILD_BUNDLE_ID
  fi

  printf '%s\n' "$_app_path"
}

# Find .app bundle using auto-detect precedence chain
# Args: project_root
# Precedence:
#   1. IOS_APP_ARTIFACT env var (glob resolved relative to project_root)
#   2. xcodebuild -showBuildSettings query
#   3. DerivedData search (matches ios_build default output location)
#   4. Recursive search of project_root for *.app directories
#   5. Recursive search of $PWD (skipped if PWD == project_root)
#   6. Error with guidance
ios_find_app() {
  _find_root="$1"

  # 1. IOS_APP_ARTIFACT env var
  if [ -n "${IOS_APP_ARTIFACT:-}" ]; then
    _app="$(ios_resolve_app_glob "$_find_root" "$IOS_APP_ARTIFACT" || true)"
    if [ -n "$_app" ] && [ -d "$_app" ]; then
      ios_log_info "deploy.sh" "App resolved via IOS_APP_ARTIFACT env var: $_app"
      printf '%s\n' "$_app"
      return 0
    fi
  fi

  # 2. xcodebuild query
  if command -v xcodebuild >/dev/null 2>&1; then
    _app="$(ios_resolve_app_via_xcodebuild "$_find_root" || true)"
    if [ -n "$_app" ] && [ -d "$_app" ]; then
      ios_log_info "deploy.sh" "App resolved via xcodebuild: $_app"
      printf '%s\n' "$_app"
      return 0
    fi
  fi

  # 3. DerivedData search (matches ios_build default output location)
  _dd_path="${IOS_DERIVED_DATA_PATH:-}"
  if [ -z "$_dd_path" ]; then
    if [ -n "${DEVBOX_PROJECT_ROOT:-}" ]; then
      _dd_path="${DEVBOX_PROJECT_ROOT}/.devbox/virtenv/ios/DerivedData"
    else
      _dd_path="${_find_root}/.devbox/virtenv/ios/DerivedData"
    fi
  fi
  if [ -d "$_dd_path" ]; then
    _app="$(find "$_dd_path" -name '*.app' -type d \
      -not -path '*/ModuleCache/*' \
      2>/dev/null | head -n1)"
    if [ -n "$_app" ] && [ -d "$_app" ]; then
      ios_log_info "deploy.sh" "App resolved via DerivedData: $_app"
      printf '%s\n' "$_app"
      return 0
    fi
  fi

  # 4. Recursive search of project_root
  _app="$(find "$_find_root" -name '*.app' -type d \
    -not -path '*/Pods/*' \
    -not -path '*/.build/*' \
    -not -path '*/SourcePackages/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/.devbox/*' \
    -not -path '*/DerivedData/ModuleCache/*' \
    2>/dev/null | head -n1)"
  if [ -n "$_app" ] && [ -d "$_app" ]; then
    ios_log_info "deploy.sh" "App resolved via project search: $_app"
    printf '%s\n' "$_app"
    return 0
  fi

  # 5. Recursive search of $PWD (skip if same as project_root)
  _cwd="$(cd "$PWD" && pwd -P)"
  _root_real="$(cd "$_find_root" && pwd -P)"
  if [ "$_cwd" != "$_root_real" ]; then
    _app="$(find "$PWD" -name '*.app' -type d \
      -not -path '*/Pods/*' \
      -not -path '*/.build/*' \
      -not -path '*/SourcePackages/*' \
      -not -path '*/node_modules/*' \
      -not -path '*/.devbox/*' \
      -not -path '*/DerivedData/ModuleCache/*' \
      2>/dev/null | head -n1)"
    if [ -n "$_app" ] && [ -d "$_app" ]; then
      ios_log_info "deploy.sh" "App resolved via directory search: $_app"
      printf '%s\n' "$_app"
      return 0
    fi
  fi

  # 6. Error
  ios_log_error "deploy.sh" "No .app bundle found. Searched: IOS_APP_ARTIFACT env var, xcodebuild settings, project root, current directory."
  ios_log_error "deploy.sh" "Set IOS_APP_ARTIFACT in devbox.json env, or pass a path: ios.sh run /path/to/MyApp.app"
  ios_log_error "deploy.sh" "See: plugins/ios/REFERENCE.md for app resolution details."
  return 1
}

# ============================================================================
# Bundle ID Extraction
# ============================================================================

# Extract CFBundleIdentifier from .app bundle
# Args: app_path
# Returns: bundle identifier
ios_extract_bundle_id() {
  _app_path="$1"

  _plist="${_app_path%/}/Info.plist"
  if [ ! -f "$_plist" ]; then
    ios_log_error "deploy.sh" "Info.plist not found in: $_app_path"
    return 1
  fi

  _bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$_plist" 2>/dev/null || true)"
  if [ -z "$_bundle_id" ]; then
    ios_log_error "deploy.sh" "Unable to read CFBundleIdentifier from: $_plist"
    return 1
  fi

  ios_log_info "deploy.sh" "Bundle ID: $_bundle_id"
  printf '%s\n' "$_bundle_id"
}

# ============================================================================
# Build Functions
# ============================================================================

# Run iOS build using devbox
# Args: project_root
ios_run_build() {
  _build_root="$1"

  _devbox_bin="$(ios_resolve_devbox_bin 2>/dev/null || true)"
  if [ -z "$_devbox_bin" ]; then
    ios_log_debug "deploy.sh" "devbox not found; skipping build step"
    return 0
  fi

  # Try platform-specific build command first, then fall back to generic
  if (cd "$_build_root" && "$_devbox_bin" run --list 2>/dev/null | grep -q "build:ios"); then
    ios_log_info "deploy.sh" "Running build:ios"
    (cd "$_build_root" && "$_devbox_bin" run --pure build:ios)
  elif (cd "$_build_root" && "$_devbox_bin" run --list 2>/dev/null | grep -q "build"); then
    ios_log_info "deploy.sh" "Running build"
    (cd "$_build_root" && "$_devbox_bin" run --pure build)
  else
    ios_log_error "deploy.sh" "No build:ios or build script found in devbox.json."
    ios_log_error "deploy.sh" "Define a build script using native tools (e.g., xcodebuild)."
    return 1
  fi
}

# ============================================================================
# App Deployment
# ============================================================================

# Build, install, and launch app on simulator
# Usage: ios_run_app [app_path] [device]
#   app_path - Optional path to .app bundle. If provided, skips build step.
#   device   - Optional device name. If omitted, uses IOS_DEFAULT_DEVICE.
ios_run_app() {
  # Parse arguments - first arg could be .app path or device name
  app_arg=""
  device_choice=""

  if [ $# -gt 0 ]; then
    # If first arg looks like a path (contains / or ends with .app), treat as app path
    if printf '%s' "$1" | grep -q -e '/' -e '\.app$'; then
      app_arg="$1"
      shift
    fi
  fi

  # Remaining arg is device choice
  device_choice="${1:-}"

  # ---- Start Deployment ----

  echo "================================================"
  echo "iOS App Deployment"
  echo "================================================"
  echo ""

  # ---- Start Simulator ----

  # Source simulator if not already loaded
  if [ -n "${IOS_SCRIPTS_DIR:-}" ] && [ -f "${IOS_SCRIPTS_DIR}/domain/simulator.sh" ]; then
    . "${IOS_SCRIPTS_DIR}/domain/simulator.sh"
  fi

  ios_start "$device_choice"

  # ---- Resolve App Path ----

  if [ -n "$app_arg" ]; then
    # App provided as argument - use directly
    app_path="$app_arg"

    # Make absolute if relative
    if [ "${app_path#/}" = "$app_path" ]; then
      app_path="$PWD/$app_path"
    fi

    if [ ! -d "$app_path" ]; then
      ios_log_error "deploy.sh" "App bundle not found: $app_path"
      exit 1
    fi

    echo "Using provided app: $(basename "$app_path")"
  else
    # No app provided - build and locate

    project_root="$(ios_resolve_project_root)"
    if [ -z "$project_root" ] || [ ! -d "$project_root" ]; then
      ios_log_error "deploy.sh" "Unable to resolve project root for iOS build"
      exit 1
    fi

    echo "Project root: $project_root"
    echo ""

    # ---- Build App ----

    ios_run_build "$project_root"

    # ---- Find App ----

    echo ""
    echo "Locating .app bundle..."

    app_path="$(ios_find_app "$project_root" || true)"

    if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
      exit 1
    fi

    echo "Found app: $(basename "$app_path")"
  fi

  # ---- Extract Bundle ID ----

  echo ""
  # Try xcodebuild-provided bundle ID first (set as side effect of ios_find_app)
  bundle_id="${IOS_XCODEBUILD_BUNDLE_ID:-}"
  if [ -z "$bundle_id" ]; then
    bundle_id="$(ios_extract_bundle_id "$app_path")"
  else
    ios_log_info "deploy.sh" "Bundle ID (from xcodebuild): $bundle_id"
  fi

  if [ -z "$bundle_id" ]; then
    ios_log_error "deploy.sh" "Unable to resolve bundle identifier for: $app_path"
    exit 1
  fi

  # ---- Deploy to Simulator ----

  udid="${IOS_SIM_UDID:-}"
  if [ -z "$udid" ]; then
    ios_log_error "deploy.sh" "iOS simulator UDID not available; ensure the simulator is booted"
    exit 1
  fi

  echo ""
  echo "Deploying to: ${IOS_SIM_NAME:-$udid}"
  echo ""

  echo "Installing app: $(basename "$app_path")"
  xcrun simctl install "$udid" "$app_path"
  echo "✓ App installed"

  echo ""
  echo "Launching app: $bundle_id"
  xcrun simctl launch "$udid" "$bundle_id"
  echo "✓ App launched"

  echo ""
  echo "================================================"
  echo "✓ Deployment complete!"
  echo "================================================"
}
