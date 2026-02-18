#!/usr/bin/env sh
# React Native Plugin - Core Utilities

set -eu

if ! (return 0 2>/dev/null); then
  echo "ERROR: lib.sh must be sourced" >&2
  exit 1
fi

if [ "${RN_LIB_LOADED:-}" = "1" ] && [ "${RN_LIB_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
RN_LIB_LOADED=1
RN_LIB_LOADED_PID="$$"

# ============================================================================
# Metro Port Management
# ============================================================================

# Find available port in range
rn_find_available_port() {
  start_port="${1:-${RN_METRO_PORT_START:-8091}}"
  end_port="${2:-${RN_METRO_PORT_END:-8199}}"

  for port in $(seq "$start_port" "$end_port"); do
    # Check if port is available (works on macOS and Linux)
    if ! lsof -i ":$port" >/dev/null 2>&1; then
      echo "$port"
      return 0
    fi
  done

  return 1
}

# Generate unique run ID for this test suite run
# Usage: rn_generate_run_id [suite_name]
rn_generate_run_id() {
  suite_name="${1:-default}"
  metro_dir="${REACT_NATIVE_VIRTENV}/metro"
  run_id_file="$metro_dir/run-id-${suite_name}.txt"

  mkdir -p "$metro_dir"

  # Check if run ID already exists for this suite
  if [ -f "$run_id_file" ]; then
    cat "$run_id_file"
    return 0
  fi

  # Generate unique ID: timestamp-pid
  run_id="$(date +%s)-$$"
  echo "$run_id" > "$run_id_file"
  echo "$run_id"
}

# Get the run ID for a test suite (generates if doesn't exist)
# Usage: rn_get_run_id [suite_name]
rn_get_run_id() {
  suite_name="${1:-default}"
  metro_dir="${REACT_NATIVE_VIRTENV}/metro"
  run_id_file="$metro_dir/run-id-${suite_name}.txt"

  if [ -f "$run_id_file" ]; then
    cat "$run_id_file"
  else
    rn_generate_run_id "$suite_name"
  fi
}

# Allocate Metro port for a specific test suite run
# Usage: rn_allocate_metro_port [suite_name]
rn_allocate_metro_port() {
  suite_name="${1:-default}"
  metro_dir="${REACT_NATIVE_VIRTENV}/metro"

  # Generate unique run ID
  run_id=$(rn_generate_run_id "$suite_name")
  unique_id="${suite_name}-${run_id}"

  port_file="$metro_dir/port-${unique_id}.txt"

  mkdir -p "$metro_dir"

  # Check if port already allocated and still available
  if [ -f "$port_file" ]; then
    allocated_port=$(cat "$port_file")
    # Verify port is still available
    if ! lsof -i ":$allocated_port" >/dev/null 2>&1; then
      echo "$allocated_port"
      return 0
    fi
  fi

  # Find new port
  available_port=$(rn_find_available_port)
  if [ -z "$available_port" ]; then
    echo "ERROR: No available ports in range 8091-8199" >&2
    return 1
  fi

  # Save port
  echo "$available_port" > "$port_file"
  echo "$available_port"
}

# Get allocated Metro port for a specific test suite
# Usage: rn_get_metro_port [suite_name]
rn_get_metro_port() {
  suite_name="${1:-default}"
  metro_dir="${REACT_NATIVE_VIRTENV}/metro"
  port_file="$metro_dir/port-${suite_name}.txt"

  if [ -f "$port_file" ]; then
    cat "$port_file"
  else
    rn_allocate_metro_port "$suite_name"
  fi
}

# Clean Metro state for a specific test suite run
# Usage: rn_clean_metro [suite_name]
rn_clean_metro() {
  suite_name="${1:-default}"
  metro_dir="${REACT_NATIVE_VIRTENV}/metro"

  # Get run ID if it exists
  run_id_file="$metro_dir/run-id-${suite_name}.txt"
  if [ -f "$run_id_file" ]; then
    run_id=$(cat "$run_id_file")
    unique_id="${suite_name}-${run_id}"

    # Remove files for this specific run
    rm -f "$metro_dir/port-${unique_id}.txt"
    rm -f "$metro_dir/env-${unique_id}.sh"
    rm -f "$metro_dir/pid-${unique_id}.txt"
    rm -f "$run_id_file"
  fi

  # Remove symlinks
  rm -f "$metro_dir/env-${suite_name}.sh"
  rm -f "$metro_dir/port-${suite_name}.txt"
  rm -f "$metro_dir/pid-${suite_name}.txt"

  # Optionally clear cache
  if [ "${RN_CLEAR_CACHE:-0}" = "1" ]; then
    rm -rf "$metro_dir/cache"
  fi
}

# Export Metro environment variables for a test suite
# Usage: rn_export_metro_env [suite_name] [port_file]
rn_export_metro_env() {
  suite_name="${1:-default}"
  port_file="${2:-}"

  # Get port from file if provided, otherwise allocate
  if [ -n "$port_file" ] && [ -f "$port_file" ]; then
    metro_port=$(cat "$port_file")
  else
    metro_port=$(rn_get_metro_port "$suite_name")
  fi

  export RCT_METRO_PORT="$metro_port"
  export METRO_PORT="$metro_port"
  export REACT_NATIVE_PACKAGER_HOSTNAME="localhost"
}

# Save Metro environment to file for process-compose processes to source
# Usage: rn_save_metro_env <suite_name> <port>
rn_save_metro_env() {
  suite_name="${1:-default}"
  metro_port="$2"
  metro_dir="${REACT_NATIVE_VIRTENV}/metro"

  # Get run ID for this suite
  run_id=$(rn_get_run_id "$suite_name")
  unique_id="${suite_name}-${run_id}"

  env_file="$metro_dir/env-${unique_id}.sh"
  # Also create a symlink with just suite name for convenience
  env_link="$metro_dir/env-${suite_name}.sh"

  mkdir -p "$metro_dir"

  cat > "$env_file" <<EOF
# Metro environment for test suite: $suite_name (run: $run_id)
# Generated: $(date)
export RCT_METRO_PORT="$metro_port"
export METRO_PORT="$metro_port"
export REACT_NATIVE_PACKAGER_HOSTNAME="localhost"
export METRO_CACHE_DIR="${REACT_NATIVE_VIRTENV}/metro/cache"
EOF

  chmod +x "$env_file"

  # Create symlink for easy access (overwrites old symlink)
  rm -f "$env_link"
  ln -s "$env_file" "$env_link"

  echo "$env_file"
}

# Track Metro PID to ensure we only kill processes we started
# Usage: rn_track_metro_pid <suite_name> <pid>
rn_track_metro_pid() {
  suite_name="${1:-default}"
  metro_pid="$2"
  metro_dir="${REACT_NATIVE_VIRTENV}/metro"

  # Get run ID for this suite
  run_id=$(rn_get_run_id "$suite_name")
  unique_id="${suite_name}-${run_id}"

  pid_file="$metro_dir/pid-${unique_id}.txt"

  mkdir -p "$metro_dir"
  echo "$metro_pid" > "$pid_file"
}

# Get tracked Metro PID
# Usage: rn_get_metro_pid <suite_name>
rn_get_metro_pid() {
  suite_name="${1:-default}"
  metro_dir="${REACT_NATIVE_VIRTENV}/metro"

  # Try to find PID file for this run
  run_id_file="$metro_dir/run-id-${suite_name}.txt"
  if [ -f "$run_id_file" ]; then
    run_id=$(cat "$run_id_file")
    unique_id="${suite_name}-${run_id}"
    pid_file="$metro_dir/pid-${unique_id}.txt"

    if [ -f "$pid_file" ]; then
      cat "$pid_file"
      return 0
    fi
  fi

  return 1
}

# Stop Metro ONLY if we started it (checks our tracked PID)
# Usage: rn_stop_metro <suite_name>
rn_stop_metro() {
  suite_name="${1:-default}"
  metro_dir="${REACT_NATIVE_VIRTENV}/metro"
  pid_file="$metro_dir/pid-${suite_name}.txt"

  if [ ! -f "$pid_file" ]; then
    echo "No Metro PID tracked for suite: $suite_name (we didn't start it)"
    return 0
  fi

  metro_pid=$(cat "$pid_file")

  # Verify process exists and is actually Metro
  if ps -p "$metro_pid" >/dev/null 2>&1; then
    process_cmd=$(ps -p "$metro_pid" -o command= 2>/dev/null || true)
    if echo "$process_cmd" | grep -q "react-native start"; then
      echo "Stopping Metro (PID: $metro_pid)..."
      kill "$metro_pid" 2>/dev/null || true
      sleep 1
      # Force kill if still running
      if ps -p "$metro_pid" >/dev/null 2>&1; then
        kill -9 "$metro_pid" 2>/dev/null || true
      fi
      echo "✓ Metro stopped"
    else
      echo "PID $metro_pid is not Metro, skipping"
    fi
  fi

  # Remove tracking file
  rm -f "$pid_file"
}

# Stop Metro by finding it via its allocated port
# Usage: rn_stop_metro_by_port <suite_name>
# This is useful when Metro is managed by process-compose and we don't track the PID
rn_stop_metro_by_port() {
  suite_name="${1:-default}"
  metro_dir="${REACT_NATIVE_VIRTENV}/metro"

  # Try to use symlink first (points to current run's env file)
  env_file="$metro_dir/env-${suite_name}.sh"

  # Source the environment file to get METRO_PORT
  if [ ! -f "$env_file" ] && [ ! -L "$env_file" ]; then
    echo "No Metro environment file found for suite: $suite_name"
    return 0
  fi

  # shellcheck disable=SC1090
  . "$env_file"

  if [ -z "${METRO_PORT:-}" ]; then
    echo "METRO_PORT not set in environment file"
    return 0
  fi

  # Find all processes listening on Metro port
  metro_pids=$(lsof -ti:"${METRO_PORT}" 2>/dev/null || true)

  if [ -z "$metro_pids" ]; then
    echo "No Metro process found on port ${METRO_PORT}"
    # Clean up files even if Metro not running
    rn_clean_metro "$suite_name"
    return 0
  fi

  # Kill all processes on the Metro port
  echo "Stopping Metro on port ${METRO_PORT} (PIDs: $metro_pids)..."
  for pid in $metro_pids; do
    kill "$pid" 2>/dev/null || true
  done

  sleep 1

  # Force kill any that are still running
  for pid in $metro_pids; do
    if ps -p "$pid" >/dev/null 2>&1; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  done

  echo "✓ Metro stopped (port ${METRO_PORT})"

  # Clean up files after stopping
  rn_clean_metro "$suite_name"
}
