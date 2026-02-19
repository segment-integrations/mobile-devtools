#!/usr/bin/env sh
# Android Plugin - Build Command
# Auto-detects Gradle project and builds with sensible defaults

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: build.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${ANDROID_BUILD_CMD_LOADED:-}" = "1" ] && [ "${ANDROID_BUILD_CMD_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_BUILD_CMD_LOADED=1
ANDROID_BUILD_CMD_LOADED_PID="$$"

# Source dependencies
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ]; then
  if [ -f "${ANDROID_SCRIPTS_DIR}/lib/lib.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/lib/lib.sh"
  fi
  if [ -f "${ANDROID_SCRIPTS_DIR}/platform/core.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/platform/core.sh"
  fi
fi

android_log_debug "build.sh loaded"

# ============================================================================
# Project Detection
# ============================================================================

# Check if a directory contains a Gradle project
# Args: directory
_android_is_gradle_dir() {
  _dir="$1"
  [ -d "$_dir" ] || return 1
  [ -f "$_dir/build.gradle" ] || [ -f "$_dir/build.gradle.kts" ] || [ -f "$_dir/settings.gradle" ] || [ -f "$_dir/settings.gradle.kts" ]
}

# Auto-detect Gradle project root using standard search order.
# Search order:
#   1. Current working directory
#   2. $DEVBOX_PROJECT_ROOT (if different from PWD)
#   3. $PWD/android/ (React Native convention)
#   4. $DEVBOX_PROJECT_ROOT/android/ (if different)
# Returns: path to Gradle project root
android_detect_project() {
  _project_root="${DEVBOX_PROJECT_ROOT:-}"

  # 1. Current working directory
  if _android_is_gradle_dir "$PWD"; then
    printf '%s\n' "$PWD"
    return 0
  fi

  # 2. DEVBOX_PROJECT_ROOT (if different)
  if [ -n "$_project_root" ]; then
    _root_real="$(cd "$_project_root" && pwd -P 2>/dev/null || true)"
    _cwd_real="$(cd "$PWD" && pwd -P 2>/dev/null || true)"
    if [ "$_root_real" != "$_cwd_real" ] && _android_is_gradle_dir "$_project_root"; then
      printf '%s\n' "$_project_root"
      return 0
    fi
  fi

  # 3. PWD/android/ (React Native convention)
  if [ -d "$PWD/android" ] && _android_is_gradle_dir "$PWD/android"; then
    printf '%s\n' "$PWD/android"
    return 0
  fi

  # 4. DEVBOX_PROJECT_ROOT/android/ (if different)
  if [ -n "$_project_root" ]; then
    _root_real="$(cd "$_project_root" && pwd -P 2>/dev/null || true)"
    _cwd_real="$(cd "$PWD" && pwd -P 2>/dev/null || true)"
    if [ "$_root_real" != "$_cwd_real" ] && [ -d "$_project_root/android" ] && _android_is_gradle_dir "$_project_root/android"; then
      printf '%s\n' "$_project_root/android"
      return 0
    fi
  fi

  return 1
}

# ============================================================================
# Build Function
# ============================================================================

# Build an Android project with Gradle.
#
# Args (all optional, parsed as flags):
#   --config Debug|Release     Build configuration (default: $ANDROID_BUILD_CONFIG or Debug)
#   --task gradle_task         Gradle task override (default: assembleDebug or assembleRelease)
#   --quiet                    Suppress Gradle output (use --quiet flag)
#   -- extra_args...           Extra arguments passed to gradle
android_build() {
  _config="${ANDROID_BUILD_CONFIG:-Debug}"
  _task="${ANDROID_BUILD_TASK:-}"
  _quiet=0

  # Parse arguments - everything after -- stays in "$@" for passthrough
  while [ $# -gt 0 ]; do
    case "$1" in
      --config)
        _config="$2"
        shift 2
        ;;
      --task)
        _task="$2"
        shift 2
        ;;
      --quiet)
        _quiet=1
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        android_log_error "build.sh" "Unknown flag: $1"
        return 1
        ;;
    esac
  done
  # After the loop, "$@" contains any extra args passed after --

  # Detect project
  _gradle_dir="$(android_detect_project || true)"
  if [ -z "$_gradle_dir" ]; then
    android_log_error "build.sh" "No Gradle project found. Searched: PWD, DEVBOX_PROJECT_ROOT, PWD/android/, DEVBOX_PROJECT_ROOT/android/"
    android_log_error "build.sh" "Ensure build.gradle or settings.gradle exists in your project"
    return 1
  fi

  # Derive task from config if not explicitly set
  if [ -z "$_task" ]; then
    _task="assemble${_config}"
  fi

  android_log_info "build.sh" "Building: $_gradle_dir (task=$_task)"

  # Find gradle wrapper or system gradle
  _gradle_cmd=""
  if [ -x "$_gradle_dir/gradlew" ]; then
    _gradle_cmd="$_gradle_dir/gradlew"
  elif command -v gradle >/dev/null 2>&1; then
    _gradle_cmd="gradle"
  else
    android_log_error "build.sh" "Neither gradlew nor gradle found. Install gradle or add a Gradle wrapper"
    return 1
  fi

  # Build the full argument list: task [--quiet] [extra_args...]
  # Prepend task and --quiet to the remaining "$@" (extra args)
  if [ "$_quiet" = "1" ]; then
    set -- "$_task" --quiet "$@"
  else
    set -- "$_task" "$@"
  fi

  # Run in subshell to cd without affecting caller
  (
    cd "$_gradle_dir"
    "$_gradle_cmd" "$@"
  )
}
