#!/usr/bin/env bash
# Android Plugin - AVD Manager Operations
# Extracted from avd.sh to eliminate circular dependencies

set -e

if ! (return 0 2>/dev/null); then
  echo "ERROR: avd_manager.sh must be sourced, not executed directly" >&2
  exit 1
fi

if [ "${ANDROID_AVD_MANAGER_LOADED:-}" = "1" ] && [ "${ANDROID_AVD_MANAGER_LOADED_PID:-}" = "$$" ]; then
  return 0 2>/dev/null || exit 0
fi
ANDROID_AVD_MANAGER_LOADED=1
ANDROID_AVD_MANAGER_LOADED_PID="$$"

# Source dependencies
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ]; then
  if [ -f "${ANDROID_SCRIPTS_DIR}/lib/lib.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/lib/lib.sh"
  fi
  if [ -f "${ANDROID_SCRIPTS_DIR}/platform/core.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/platform/core.sh"
  fi
  if [ -f "${ANDROID_SCRIPTS_DIR}/platform/device_config.sh" ]; then
    . "${ANDROID_SCRIPTS_DIR}/platform/device_config.sh"
  fi
fi

# ============================================================================
# Device Hardware Profile Resolution
# ============================================================================

# Resolve device hardware profile (exact match only)
android_resolve_device_hardware() {
  desired_device="$1"

  if [ -z "$desired_device" ]; then
    return 1
  fi

  # Check if device exists in avdmanager list (exact match)
  if avdmanager list device 2>/dev/null | grep -q "^id: .* or \"$desired_device\"$"; then
    printf '%s\n' "$desired_device"
    return 0
  fi

  # Device not found
  return 1
}

# ============================================================================
# ABI Selection
# ============================================================================

# Get ABI candidates based on preference and host architecture
android_get_abi_candidates() {
  preferred_abi="${1:-}"
  host_arch="${2:-$(uname -m)}"

  # If user specified a preference, only try that one
  if [ -n "$preferred_abi" ]; then
    printf '%s' "$preferred_abi"
    return 0
  fi

  # Otherwise, select based on host architecture
  # arm64/aarch64 hosts: Prefer arm64-v8a, then x86_64, then x86
  # Other hosts: Prefer x86_64, then x86, then arm64-v8a
  case "$host_arch" in
    arm64|aarch64)
      printf '%s' "arm64-v8a x86_64 x86"
      ;;
    *)
      printf '%s' "x86_64 x86 arm64-v8a"
      ;;
  esac
}

# ============================================================================
# System Image Resolution
# ============================================================================

# Find system image matching API level, tag, and ABI preference
android_pick_system_image() {
  api_level="$1"
  system_image_tag="$2"
  preferred_abi="${3:-}"

  # Get ABI candidates in priority order
  abi_candidates="$(android_get_abi_candidates "$preferred_abi")"

  # Try each ABI until we find an installed image
  for abi in $abi_candidates; do
    image_path="${ANDROID_SDK_ROOT}/system-images/android-${api_level}/${system_image_tag}/${abi}"
    image_package="system-images;android-${api_level};${system_image_tag};${abi}"

    if android_debug_enabled; then
      android_debug_log "Checking system image: $image_path"
    fi

    if [ -d "$image_path" ]; then
      printf '%s\n' "$image_package"
      return 0
    fi
  done

  return 1
}

# ============================================================================
# Java Resolution
# ============================================================================

# Resolve Java home directory (ANDROID_JAVA_HOME > JAVA_HOME > PATH)
android_resolve_java_home() {
  # Priority 1: ANDROID_JAVA_HOME
  if [ -n "${ANDROID_JAVA_HOME:-}" ] && [ -x "$ANDROID_JAVA_HOME/bin/java" ]; then
    printf '%s\n' "$ANDROID_JAVA_HOME"
    return 0
  fi

  # Priority 2: JAVA_HOME
  if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    printf '%s\n' "$JAVA_HOME"
    return 0
  fi

  # Priority 3: java in PATH
  java_bin="$(command -v java 2>/dev/null || true)"
  if [ -n "$java_bin" ]; then
    # Derive JAVA_HOME from binary location
    java_home="$(cd "$(dirname "$java_bin")/.." && pwd)"
    if [ -x "$java_home/bin/java" ]; then
      printf '%s\n' "$java_home"
      return 0
    fi
  fi

  return 1
}

# ============================================================================
# AVD Manager Operations
# ============================================================================

# Run avdmanager with correct Java environment
android_run_avdmanager() {
  if [ -n "${ANDROID_JAVA_HOME:-}" ]; then
    JAVA_HOME="$ANDROID_JAVA_HOME" \
    PATH="$ANDROID_JAVA_HOME/bin:$PATH" \
      avdmanager "$@"
  else
    avdmanager "$@"
  fi
}

# Check if an AVD exists
android_avd_exists() {
  avd_name="$1"

  android_run_avdmanager list avd | grep -q "Name: ${avd_name}"
}

# ============================================================================
# AVD Configuration Readers
# ============================================================================

# Get AVD configuration file path
android_get_avd_config_path() {
  avd_name="$1"
  avd_home="${ANDROID_AVD_HOME:-$HOME/.android/avd}"

  printf '%s\n' "${avd_home}/${avd_name}.avd/config.ini"
}

# Read API level from AVD config.ini
# Returns: API level (e.g., "31") or empty if not found
android_get_avd_api() {
  avd_name="$1"
  config_path="$(android_get_avd_config_path "$avd_name")"

  if [ ! -f "$config_path" ]; then
    return 1
  fi

  # Parse image.sysdir.1=system-images/android-31/google_apis/x86_64/
  # Extract the API level (31 in this example)
  api="$(grep '^image\.sysdir\.1=' "$config_path" | sed 's/.*android-\([0-9]*\).*/\1/')"

  if [ -n "$api" ]; then
    printf '%s\n' "$api"
    return 0
  fi

  return 1
}

# Read tag from AVD config.ini
# Returns: tag (e.g., "google_apis", "default") or empty if not found
android_get_avd_tag() {
  avd_name="$1"
  config_path="$(android_get_avd_config_path "$avd_name")"

  if [ ! -f "$config_path" ]; then
    return 1
  fi

  # Read tag.id from config
  tag="$(grep '^tag\.id=' "$config_path" | cut -d'=' -f2 | tr -d ' \r\n')"

  if [ -n "$tag" ]; then
    printf '%s\n' "$tag"
    return 0
  fi

  return 1
}

# Read ABI from AVD config.ini
# Returns: ABI (e.g., "x86_64", "arm64-v8a") or empty if not found
android_get_avd_abi() {
  avd_name="$1"
  config_path="$(android_get_avd_config_path "$avd_name")"

  if [ ! -f "$config_path" ]; then
    return 1
  fi

  # Read abi.type from config
  abi="$(grep '^abi\.type=' "$config_path" | cut -d'=' -f2 | tr -d ' \r\n')"

  if [ -n "$abi" ]; then
    printf '%s\n' "$abi"
    return 0
  fi

  return 1
}

# ============================================================================
# AVD Creation and Deletion
# ============================================================================

# Create an Android Virtual Device (AVD)
android_create_avd() {
  avd_name="$1"
  device_hardware="$2"
  system_image_package="$3"

  # Extract ABI from package name (last component after ;)
  image_abi="${system_image_package##*;}"

  # Check if AVD already exists
  if android_avd_exists "$avd_name"; then
    echo "AVD already exists: ${avd_name}"
    return 0
  fi

  # Create the AVD
  echo "Creating AVD: ${avd_name} with ${system_image_package}..."

  android_run_avdmanager create avd \
    --force \
    --name "$avd_name" \
    --package "$system_image_package" \
    --device "$device_hardware" \
    --abi "$image_abi" \
    --sdcard 512M
}

# Delete specific AVD(s) by name
android_delete_avd() {
  avd_name="$1"

  if [ -z "$avd_name" ]; then
    return 1
  fi

  if ! android_avd_exists "$avd_name"; then
    echo "AVD not found: $avd_name"
    return 0
  fi

  echo "Deleting AVD: $avd_name"
  android_run_avdmanager delete avd --name "$avd_name"
  echo "  ✓ AVD deleted: $avd_name"
}

# ============================================================================
# AVD Setup
# ============================================================================

# Setup AVDs from device definition files
android_setup_avds() {
  # ---- Validate Environment ----

  # Ensure SDK is available
  if [ -z "${ANDROID_SDK_ROOT:-}" ] && [ -z "${ANDROID_HOME:-}" ]; then
    echo "ERROR: ANDROID_SDK_ROOT/ANDROID_HOME must be set" >&2
    echo "       Ensure the Devbox Android SDK package is installed" >&2
    exit 1
  fi

  # Set ANDROID_HOME for compatibility
  ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
  export ANDROID_HOME

  # Require necessary tools
  android_require_tool avdmanager
  android_require_tool emulator
  android_require_tool jq

  # Resolve and export Java home
  java_home="$(android_resolve_java_home 2>/dev/null || true)"
  if [ -n "$java_home" ]; then
    ANDROID_JAVA_HOME="$java_home"
    export ANDROID_JAVA_HOME
  fi

  # ---- Find Lock File ----

  config_dir="$(android_resolve_config_dir 2>/dev/null || true)"
  if [ -z "$config_dir" ]; then
    echo "ERROR: Android config directory not found" >&2
    echo "       Expected devbox.d/android or ANDROID_CONFIG_DIR" >&2
    exit 1
  fi

  devices_dir="$(android_get_devices_dir 2>/dev/null || printf '%s/devices' "$config_dir")"
  lock_file="${devices_dir%/}/devices.lock"
  if [ ! -f "$lock_file" ]; then
    echo "ERROR: devices.lock not found at ${lock_file}" >&2
    echo "       Run 'devbox run android.sh devices eval' to generate it" >&2
    exit 1
  fi

  # Read devices from lock file
  devices_json="$(jq -c '.devices[]' "$lock_file" 2>/dev/null || echo "")"
  if [ -z "$devices_json" ]; then
    echo "ERROR: No devices found in ${lock_file}" >&2
    echo "       Run 'devbox run android.sh devices eval' to regenerate" >&2
    exit 1
  fi

  # Filter devices based on ANDROID_DEVICES if set
  if [ -n "${ANDROID_DEVICES:-}" ]; then
    IFS=',' read -ra selected_devices <<< "${ANDROID_DEVICES}"

    # Show filtering context for transparency
    echo ""
    echo "Filtering devices: ANDROID_DEVICES=${ANDROID_DEVICES}"
    echo ""
    echo "Available devices in lock file:"
    missing_filename=false
    for device_json in $devices_json; do
      d_filename="$(echo "$device_json" | jq -r '.filename // empty')"
      d_name="$(echo "$device_json" | jq -r '.name // empty')"
      d_api="$(echo "$device_json" | jq -r '.api // empty')"
      if [ -n "$d_filename" ]; then
        echo "  - $d_filename (name: $d_name, API $d_api)"
      else
        echo "  - [MISSING FILENAME] (name: $d_name, API $d_api)"
        missing_filename=true
      fi
    done
    echo ""

    if [ "$missing_filename" = true ]; then
      echo "ERROR: Lock file missing filename metadata (old format)" >&2
      echo "       Regenerate with: devbox run android.sh devices eval" >&2
      exit 1
    fi

    filtered_json=""
    for device_json in $devices_json; do
      device_filename="$(echo "$device_json" | jq -r '.filename // empty')"

      # Check if device matches filter (filename only)
      should_include=false
      for selected in "${selected_devices[@]}"; do
        if [ "$device_filename" = "$selected" ]; then
          should_include=true
          break
        fi
      done

      if [ "$should_include" = true ]; then
        filtered_json="${filtered_json}${device_json}"$'\n'
      fi
    done

    devices_json="$filtered_json"

    if [ -z "$devices_json" ]; then
      echo "ERROR: No devices match ANDROID_DEVICES filter: ${ANDROID_DEVICES}" >&2
      echo "       All devices were filtered out" >&2
      echo ""
      echo "HINT: Filter matches device filename (e.g., min, max)" >&2
      echo "      Check available devices listed above" >&2
      exit 1
    fi

    echo "Proceeding with filtered device list"
    echo ""
  fi

  # Get lock file checksum for AVD validation
  lock_checksum="$(jq -r '.checksum // ""' "$lock_file" 2>/dev/null || echo "")"

  # ---- Process Each Device from Lock File ----

  # Track first AVD name for convenience (export to file since loop is in subshell)
  first_avd_file="${ANDROID_AVD_HOME}/.first_avd"
  rm -f "$first_avd_file"

  # Track skipped devices (loop runs in subshell, so use temp file)
  skip_count_file="$(mktemp "${TMPDIR:-/tmp}/android-avd-skips-XXXXXX")"
  echo "0" > "$skip_count_file"

  # Get default system image tag
  default_image_tag="${ANDROID_SYSTEM_IMAGE_TAG:-google_apis}"

  echo "$devices_json" | while IFS= read -r device_json; do
    echo ""
    echo "Processing device from lock file..."

    # Parse device definition from lock file
    device_name="$(echo "$device_json" | jq -r '.name // empty')"
    api_level="$(echo "$device_json" | jq -r '.api // empty')"
    device_hardware="$(echo "$device_json" | jq -r '.device // empty')"
    image_tag="$(echo "$device_json" | jq -r '.tag // empty')"
    preferred_abi="$(echo "$device_json" | jq -r '.preferred_abi // empty')"

    # Validate required fields
    if [ -z "$api_level" ] || [ -z "$device_hardware" ]; then
      echo "ERROR: Device definition missing required fields (api, device)" >&2
      echo "$(( $(cat "$skip_count_file") + 1 ))" > "$skip_count_file"
      continue
    fi

    # Use default tag if not specified
    if [ -z "$image_tag" ]; then
      image_tag="$default_image_tag"
    fi

    echo "  Device: $device_hardware"
    echo "  API: $api_level"
    echo "  Tag: $image_tag"
    [ -n "$preferred_abi" ] && echo "  Preferred ABI: $preferred_abi"

    # Validate device hardware profile exists
    if ! android_resolve_device_hardware "$device_hardware" >/dev/null 2>&1; then
      echo "ERROR: Device '$device_hardware' not found in avdmanager" >&2
      echo "       Run: avdmanager list device" >&2
      echo "       Use exact device ID from the list" >&2
      echo "$(( $(cat "$skip_count_file") + 1 ))" > "$skip_count_file"
      continue
    fi

    # Find compatible system image
    system_image="$(android_pick_system_image "$api_level" "$image_tag" "$preferred_abi" 2>/dev/null || true)"
    if [ -z "$system_image" ]; then
      echo "ERROR: No compatible system image found for API ${api_level} (${image_tag})" >&2
      echo "       Preferred ABI: ${preferred_abi:-auto}" >&2
      echo "       Check: ${ANDROID_SDK_ROOT}/system-images/android-${api_level}" >&2
      echo "       Re-enter devbox shell to download system images" >&2
      echo "$(( $(cat "$skip_count_file") + 1 ))" > "$skip_count_file"
      continue
    fi

    # Generate AVD name
    if [ -n "$device_name" ]; then
      avd_name="$device_name"
    else
      # Auto-generate name from device and API
      image_abi="${system_image##*;}"
      safe_abi="$(printf '%s' "$image_abi" | tr '-' '_')"
      safe_device="$(android_sanitize_avd_name "$device_hardware" || echo "device")"
      avd_name="${safe_device}_API${api_level}_${safe_abi}"
    fi

    echo "  AVD name: $avd_name"

    # Check if AVD exists and is consistent with lock file
    avd_needs_recreation=false
    if android_avd_exists "$avd_name"; then
      # Read checksum from AVD config
      avd_config="${ANDROID_AVD_HOME}/${avd_name}.avd/config.ini"
      if [ -f "$avd_config" ]; then
        avd_checksum="$(grep '^devbox.lock.checksum=' "$avd_config" 2>/dev/null | cut -d'=' -f2 || echo "")"
        if [ "$avd_checksum" != "$lock_checksum" ]; then
          echo "  ⚠ AVD checksum mismatch (lock file changed)"
          echo "  ⚠ Recreating AVD to match lock file..."
          avd_needs_recreation=true
        else
          echo "  ✓ AVD exists and matches lock file"
        fi
      else
        # Old AVD without checksum - recreate
        echo "  ⚠ AVD missing checksum metadata (old format)"
        echo "  ⚠ Recreating AVD..."
        avd_needs_recreation=true
      fi
    else
      avd_needs_recreation=true
    fi

    # Create or recreate the AVD if needed
    if [ "$avd_needs_recreation" = true ]; then
      # Delete old AVD if it exists
      if android_avd_exists "$avd_name"; then
        echo "  Deleting old AVD..."
        android_run_avdmanager delete avd --name "$avd_name" >/dev/null 2>&1 || true
      fi

      # Create the AVD
      android_create_avd "$avd_name" "$device_hardware" "$system_image"

      # Store lock file checksum in AVD config for consistency checking
      avd_config="${ANDROID_AVD_HOME}/${avd_name}.avd/config.ini"
      if [ -f "$avd_config" ] && [ -n "$lock_checksum" ]; then
        echo "devbox.lock.checksum=${lock_checksum}" >> "$avd_config"
      fi

      echo "  ✓ AVD created: ${avd_name}"
    fi

    # Track first AVD (write to file since we're in a subshell)
    if [ ! -f "$first_avd_file" ]; then
      echo "$avd_name" > "$first_avd_file"
    fi
  done

  # Export first AVD name for convenience
  if [ -f "$first_avd_file" ]; then
    first_avd_name="$(cat "$first_avd_file")"
    rm -f "$first_avd_file"
    if [ -n "$first_avd_name" ]; then
      ANDROID_RESOLVED_AVD="$first_avd_name"
      export ANDROID_RESOLVED_AVD
      echo ""
      echo "Default AVD: $first_avd_name"
    fi
  fi

  # Check for skipped devices in strict mode
  avd_skips="$(cat "$skip_count_file" 2>/dev/null || echo "0")"
  rm -f "$skip_count_file"
  if [ "$avd_skips" -gt 0 ]; then
    if [ "${DEVBOX_PURE_SHELL:-}" = "1" ] || [ "${ANDROID_STRICT_SYNC:-}" = "1" ]; then
      echo ""
      echo "ERROR: $avd_skips device(s) skipped due to missing system images (strict mode)" >&2
      echo "       Re-enter devbox shell to download system images or update device definitions" >&2
      exit 1
    fi
  fi

  echo ""
  echo "AVD setup complete!"
  echo "Start emulator: emulator -avd <name> --netdelay none --netspeed full"
}

# ============================================================================
# AVD Sync - Ensure AVD matches device definition
# ============================================================================

# Ensure AVD matches device definition, recreating if necessary
# Args: device_json_path
# Returns: 0=matched, 1=recreated, 2=created
android_ensure_avd_from_definition() {
  device_json="$1"

  if [ ! -f "$device_json" ]; then
    echo "ERROR: Device definition not found: $device_json" >&2
    return 1
  fi

  # Parse device definition
  name="$(jq -r '.name // empty' "$device_json")"
  api="$(jq -r '.api // empty' "$device_json")"
  device="$(jq -r '.device // empty' "$device_json")"
  tag="$(jq -r '.tag // empty' "$device_json")"
  preferred_abi="$(jq -r '.preferred_abi // empty' "$device_json")"

  if [ -z "$name" ] || [ -z "$api" ] || [ -z "$device" ] || [ -z "$tag" ]; then
    echo "ERROR: Invalid device definition in $device_json" >&2
    return 1
  fi

  # Resolve device hardware
  device_hardware="$(android_resolve_device_hardware "$device" || true)"
  if [ -z "$device_hardware" ]; then
    echo "  ⚠ Device hardware '$device' not available, skipping $name"
    return 3
  fi

  # Pick system image
  system_image="$(android_pick_system_image "$api" "$tag" "$preferred_abi" || true)"
  if [ -z "$system_image" ]; then
    echo "  ⚠ System image not available (API $api, tag $tag), skipping $name"
    return 3
  fi

  # Extract expected ABI from system image package
  expected_abi="${system_image##*;}"

  # Check if AVD exists
  if ! android_avd_exists "$name"; then
    # Create new AVD
    echo "  ➕ Creating AVD: $name (API $api, $tag, $expected_abi)"
    android_create_avd "$name" "$device_hardware" "$system_image" >/dev/null 2>&1
    return 2
  fi

  # AVD exists - check if it matches the definition
  current_api="$(android_get_avd_api "$name" || true)"
  current_tag="$(android_get_avd_tag "$name" || true)"
  current_abi="$(android_get_avd_abi "$name" || true)"

  if [ "$current_api" = "$api" ] && [ "$current_tag" = "$tag" ] && [ "$current_abi" = "$expected_abi" ]; then
    echo "  ✓ Matched: $name (API $api, $tag, $expected_abi)"
    return 0
  fi

  # Mismatch or new AVD - create/recreate
  if [ -z "$current_api" ]; then
    echo "  ➕ Creating new AVD: $name (API $api, $tag, $expected_abi)"
  else
    echo "  🔄 Recreating AVD: $name (API $current_api → $api, $current_tag → $tag, $current_abi → $expected_abi)"
  fi
  android_delete_avd "$name" >/dev/null 2>&1
  android_create_avd "$name" "$device_hardware" "$system_image" >/dev/null 2>&1
  return 1
}

android_debug_log_script "avd_manager.sh"
