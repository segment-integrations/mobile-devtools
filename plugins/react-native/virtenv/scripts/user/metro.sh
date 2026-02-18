#!/usr/bin/env sh
# React Native Metro Bundler CLI
# Manages Metro bundler lifecycle for test suites and development

set -eu

# Get script directory and source lib
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# shellcheck source=../lib/lib.sh
. "$LIB_DIR/lib.sh"

# ============================================================================
# Commands
# ============================================================================

metro_start() {
  suite_name="${1:-default}"

  echo "🚀 Starting Metro bundler for suite: $suite_name"

  # Allocate port
  metro_port=$(rn_allocate_metro_port "$suite_name")
  echo "📡 Allocated port: $metro_port"

  # Save environment
  env_file=$(rn_save_metro_env "$suite_name" "$metro_port")
  echo "✓ Environment saved: $env_file"

  # Source environment for current shell
  # shellcheck disable=SC1090
  . "$env_file"

  # Start Metro
  echo "Starting Metro on port $metro_port..."
  echo "Cache dir: ${REACT_NATIVE_VIRTENV}/metro/cache"

  # Start Metro with allocated port
  # Use exec to replace shell process - avoids "Terminated: 15" message on shutdown
  exec npx react-native start \
    --port "$metro_port" \
    --reset-cache
}

metro_stop() {
  suite_name="${1:-default}"

  echo "🛑 Stopping Metro bundler for suite: $suite_name"
  rn_stop_metro_by_port "$suite_name"
}

metro_status() {
  suite_name="${1:-default}"
  metro_dir="${REACT_NATIVE_VIRTENV}/metro"
  env_file="$metro_dir/env-${suite_name}.sh"

  if [ ! -f "$env_file" ]; then
    echo "No Metro configuration found for suite: $suite_name"
    return 1
  fi

  # shellcheck disable=SC1090
  . "$env_file"

  echo "Metro configuration for suite: $suite_name"
  echo "  Port: ${METRO_PORT}"
  echo "  Environment file: $env_file"

  # Check if Metro is running
  if metro_pid=$(lsof -ti:"${METRO_PORT}" 2>/dev/null); then
    echo "  Status: Running (PID: $metro_pid)"
    process_cmd=$(ps -p "$metro_pid" -o command= 2>/dev/null || true)
    echo "  Command: $process_cmd"
  else
    echo "  Status: Not running"
  fi
}

metro_clean() {
  suite_name="${1:-default}"

  echo "🧹 Cleaning Metro state for suite: $suite_name"
  rn_clean_metro "$suite_name"
  echo "✓ Metro state cleaned"
}

metro_health() {
  suite_name="${1:-default}"
  platform="${2:-ios}"  # Default to ios, can be android, ios, or all
  metro_dir="${REACT_NATIVE_VIRTENV}/metro"
  env_file="$metro_dir/env-${suite_name}.sh"

  # Check if Metro environment exists
  if [ ! -f "$env_file" ] && [ ! -L "$env_file" ]; then
    return 1
  fi

  # shellcheck disable=SC1090
  . "$env_file"

  # Check if port is set
  if [ -z "${METRO_PORT:-}" ]; then
    return 1
  fi

  # Check if Metro server is up
  if ! curl -sf "http://localhost:$METRO_PORT/status" >/dev/null 2>&1; then
    return 1
  fi

  # Verify Metro can serve bundles for the platform
  if ! curl -sf -I "http://localhost:$METRO_PORT/index.bundle?platform=$platform&dev=true" 2>/dev/null | grep -q "HTTP.*200"; then
    return 1
  fi

  return 0
}

# ============================================================================
# CLI
# ============================================================================

show_usage() {
  cat <<EOF
Metro Bundler CLI for React Native

Usage: metro.sh <command> [suite_name] [platform]

Commands:
  start [suite]         Start Metro bundler for test suite (default: default)
                        Allocates port, saves environment, starts Metro

  stop [suite]          Stop Metro bundler for test suite
                        Finds Metro by port and stops it gracefully

  status [suite]        Show Metro status for test suite
                        Displays port, PID, and running status

  health [suite] [plat] Health check for Metro (silent, exit code only)
                        Checks if Metro can serve bundles
                        Platform: ios, android, all (default: ios)

  clean [suite]         Clean Metro state files for test suite
                        Removes port allocation and environment files

Examples:
  metro.sh start android        # Start Metro for android test suite
  metro.sh stop ios             # Stop Metro for ios test suite
  metro.sh status all           # Check status of all platform suite
  metro.sh clean android        # Clean up android suite state

Suite Names:
  default           Default suite (for manual testing)
  android           Android E2E test suite
  ios               iOS E2E test suite
  all               All platforms E2E test suite

Environment Variables:
  REACT_NATIVE_VIRTENV    React Native plugin virtenv directory
  METRO_PORT              Port Metro is running on (auto-allocated)
  RCT_METRO_PORT          Same as METRO_PORT (React Native compatibility)

EOF
}

# Main command dispatcher
main() {
  if [ $# -lt 1 ]; then
    show_usage
    exit 1
  fi

  command="$1"
  shift

  case "$command" in
    start)
      metro_start "$@"
      ;;
    stop)
      metro_stop "$@"
      ;;
    status)
      metro_status "$@"
      ;;
    health)
      metro_health "$@"
      ;;
    clean)
      metro_clean "$@"
      ;;
    help|--help|-h)
      show_usage
      ;;
    *)
      echo "Error: Unknown command: $command" >&2
      echo "" >&2
      show_usage
      exit 1
      ;;
  esac
}

main "$@"
