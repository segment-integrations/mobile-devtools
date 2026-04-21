#!/usr/bin/env bash
# Android Plugin - Device Management CLI
#
# This script manages Android device definitions stored in devbox.d/android/devices/
#
# User-Overridable Variables:
#   ANDROID_CONFIG_DIR - Android configuration directory (default: devbox.d/android)
#   ANDROID_DEVICES_DIR - Device definitions directory (default: $ANDROID_CONFIG_DIR/devices)
#   ANDROID_SCRIPTS_DIR - Scripts directory
#   DEVICES_CMD - Command to execute (alternative to $1)

set -eu

# Source dependencies
# Layer 1: Pure utilities
# Layer 2: Platform setup and device config
# Layer 3: Domain operations (AVD management)
if [ -n "${ANDROID_SCRIPTS_DIR:-}" ]; then
  . "${ANDROID_SCRIPTS_DIR}/lib/lib.sh"
  . "${ANDROID_SCRIPTS_DIR}/platform/core.sh"
  . "${ANDROID_SCRIPTS_DIR}/platform/device_config.sh"
  . "${ANDROID_SCRIPTS_DIR}/domain/avd.sh"
fi

# ============================================================================
# Usage and Help
# ============================================================================

usage() {
  cat >&2 <<'USAGE'
Usage: devices.sh <command> [args]
       DEVICES_CMD="list" devices.sh

Commands:
  list                                              List all device definitions
  show <name>                                       Show specific device JSON
  create <name> --api <n> --device <id> [options]  Create new device definition
  update <name> [options]                           Update existing device
  delete <name>                                     Remove device definition
  eval                                              Generate devices.lock from ANDROID_DEVICES
  sync                                              Generate locks and sync AVDs
  hash <subcommand> [args]                          Manage Nix hash overrides

Hash Subcommands:
  hash show                Show current hash overrides in android.lock
  hash update <url> <hash> Add/update a hash override (SHA1 hex, 40 chars)
  hash clear               Remove all hash overrides from android.lock

Device Creation Options:
  --api <n>         Android API level (required, e.g., 28, 34)
  --device <id>     Device hardware profile (required, e.g., pixel, Nexus 5X)
  --tag <tag>       System image tag (optional)
  --abi <abi>       Preferred ABI (optional)

Tag values: default google_apis google_apis_playstore play_store aosp_atd google_atd
ABI values: arm64-v8a x86_64 x86

Device Selection:
  Set ANDROID_DEVICES env var in devbox.json (comma-separated, empty = all):
    {"ANDROID_DEVICES": "min,max"}

Hash Overrides:
  When Google updates files on their servers but nixpkgs hasn't caught up,
  you may see hash mismatch errors. Use 'hash update' to add an override.
  By default, hash overrides are not set - only use as a temporary fix.

  Hash format: SHA1 hex string (40 characters), e.g., 8c4c926d0ca192376b2a04b0318484724319e67c

Examples:
  devices.sh list
  devices.sh create pixel_api28 --api 28 --device pixel --tag google_apis
  devices.sh eval
  devices.sh sync
  devices.sh hash show
  devices.sh hash update https://dl.google.com/android/repository/platform-tools_r37.0.0-darwin.zip 8c4c926d0ca192376b2a04b0318484724319e67c
  devices.sh hash clear
USAGE
  exit 1
}

# ============================================================================
# Initialize Variables
# ============================================================================

# Allow command to be passed via DEVICES_CMD environment variable
if [ -z "${1-}" ] && [ -n "${DEVICES_CMD:-}" ]; then
  # shellcheck disable=SC2086
  set -- $DEVICES_CMD
fi

command_name="${1-}"
if [ -z "$command_name" ] || [ "$command_name" = "help" ]; then
  usage
fi
shift || true

# Local variables (derived from user-overridable variables)
config_dir="${ANDROID_CONFIG_DIR:-./devbox.d/android}"
devices_dir="${ANDROID_DEVICES_DIR:-${config_dir%/}/devices}"
scripts_dir="${ANDROID_SCRIPTS_DIR:-${config_dir%/}/scripts}"
lock_file_path="${devices_dir%/}/devices.lock"

# Constants: Allowed values for validation
readonly ALLOWED_TAGS="default google_apis google_apis_playstore play_store aosp_atd google_atd"
readonly ALLOWED_ABIS="arm64-v8a x86_64 x86"

# ============================================================================
# Helper Functions
# ============================================================================

# Ensure lib.sh is loaded for shared utilities
ensure_lib_loaded() {
  # Check if lib.sh functions are available
  if ! command -v android_require_jq >/dev/null 2>&1; then
    # Try to source lib.sh
    if [ -f "${scripts_dir}/lib.sh" ]; then
      . "${scripts_dir}/lib.sh"
    else
      echo "ERROR: lib.sh not found. Cannot continue." >&2
      exit 1
    fi
  fi
}

# Resolve device file path from device name or filename
#
# Tries two strategies:
#   1. Match by filename: devices_dir/<name>.json
#   2. Match by .name field in JSON files
#
# Parameters:
#   $1 - selection: Device name to find
#
# Returns:
#   Prints full path to device JSON file
#
# Exit codes:
#   0 - Device found
#   1 - Device not found
resolve_device_file() {
  selection="$1"

  if [ -z "$selection" ]; then
    return 1
  fi

  # Strategy 1: Try direct filename match
  candidate_file="$devices_dir/${selection}.json"
  if [ -f "$candidate_file" ]; then
    printf '%s\n' "$candidate_file"
    return 0
  fi

  # Strategy 2: Search for .name field match in all device files
  for device_file in "$devices_dir"/*.json; do
    [ -f "$device_file" ] || continue

    device_name="$(jq -r '.name // empty' "$device_file")"
    if [ "$device_name" = "$selection" ]; then
      printf '%s\n' "$device_file"
      return 0
    fi
  done

  return 1
}

# Validate API level is numeric
#
# Parameters:
#   $1 - api_value: API level to validate
validate_api() {
  api_value="$1"

  case "$api_value" in
    ''|*[!0-9]*)
      echo "ERROR: Invalid api: $api_value (must be numeric, e.g., 28, 34)" >&2
      exit 1
      ;;
  esac
}

# Validate system image tag is in allowed list
#
# Parameters:
#   $1 - tag_value: Tag to validate
validate_tag() {
  tag_value="$1"

  for allowed_tag in $ALLOWED_TAGS; do
    if [ "$allowed_tag" = "$tag_value" ]; then
      return 0
    fi
  done

  echo "ERROR: Invalid tag: $tag_value" >&2
  echo "       Allowed: $ALLOWED_TAGS" >&2
  exit 1
}

# Validate ABI is in allowed list
#
# Parameters:
#   $1 - abi_value: ABI to validate
validate_abi() {
  abi_value="$1"

  for allowed_abi in $ALLOWED_ABIS; do
    if [ "$allowed_abi" = "$abi_value" ]; then
      return 0
    fi
  done

  echo "ERROR: Invalid abi: $abi_value" >&2
  echo "       Allowed: $ALLOWED_ABIS" >&2
  exit 1
}

# ============================================================================
# Initialize
# ============================================================================

# Load shared utilities (but don't require jq yet)
ensure_lib_loaded

# Setup jq wrapper - use system jq if available, otherwise use nix-shell
if command -v jq >/dev/null 2>&1; then
  # System jq available - use it directly
  jq() { command jq "$@"; }
elif command -v nix >/dev/null 2>&1; then
  # No system jq, but nix is available - use ephemeral shell
  jq() {
    # shellcheck disable=SC3050
    nix-shell -p jq --run "jq $(printf '%q ' "$@")" 2>/dev/null
  }
else
  # Neither jq nor nix available
  echo "ERROR: jq is required but not found" >&2
  echo "       Install jq or ensure nix is available" >&2
  exit 1
fi

# ============================================================================
# Sync Helper Functions
# ============================================================================

# Generate android.lock from environment variables
# Creates/updates android.lock with current Android SDK configuration from env vars
# Preserves hash_overrides field if it exists
android_generate_android_lock() {
  local android_lock_file="${config_dir}/android.lock"
  local android_lock_tmp="${android_lock_file}.tmp"

  # Preserve existing hash_overrides if present
  local hash_overrides_json="{}"
  if [ -f "$android_lock_file" ]; then
    hash_overrides_json="$(jq -c '.hash_overrides // {}' "$android_lock_file")"
  fi

  # Extract relevant Android env vars and create lock file
  # Convert boolean env vars (accepts: true/1/yes/on, case-insensitive)
  # Only include hash_overrides field if it has content
  if [ "$hash_overrides_json" = "{}" ]; then
    # No hash overrides - standard lock file
    jq -n \
      --arg build_tools "${ANDROID_BUILD_TOOLS_VERSION:-36.1.0}" \
      --arg cmdline_tools "${ANDROID_CMDLINE_TOOLS_VERSION:-19.0}" \
      --arg compile_sdk "${ANDROID_COMPILE_SDK:-36}" \
      --arg target_sdk "${ANDROID_TARGET_SDK:-36}" \
      --arg system_image_tag "${ANDROID_SYSTEM_IMAGE_TAG:-google_apis}" \
      --arg include_ndk "${ANDROID_INCLUDE_NDK:-false}" \
      --arg ndk_version "${ANDROID_NDK_VERSION:-27.0.12077973}" \
      --arg include_cmake "${ANDROID_INCLUDE_CMAKE:-false}" \
      --arg cmake_version "${ANDROID_CMAKE_VERSION:-3.22.1}" \
      '{
        ANDROID_BUILD_TOOLS_VERSION: $build_tools,
        ANDROID_CMDLINE_TOOLS_VERSION: $cmdline_tools,
        ANDROID_COMPILE_SDK: ($compile_sdk | tonumber),
        ANDROID_TARGET_SDK: ($target_sdk | tonumber),
        ANDROID_SYSTEM_IMAGE_TAG: $system_image_tag,
        ANDROID_INCLUDE_NDK: ($include_ndk | test("true|1|yes|on"; "i")),
        ANDROID_NDK_VERSION: $ndk_version,
        ANDROID_INCLUDE_CMAKE: ($include_cmake | test("true|1|yes|on"; "i")),
        ANDROID_CMAKE_VERSION: $cmake_version
      }' > "$android_lock_tmp"
  else
    # Has hash overrides - include them
    jq -n \
      --arg build_tools "${ANDROID_BUILD_TOOLS_VERSION:-36.1.0}" \
      --arg cmdline_tools "${ANDROID_CMDLINE_TOOLS_VERSION:-19.0}" \
      --arg compile_sdk "${ANDROID_COMPILE_SDK:-36}" \
      --arg target_sdk "${ANDROID_TARGET_SDK:-36}" \
      --arg system_image_tag "${ANDROID_SYSTEM_IMAGE_TAG:-google_apis}" \
      --arg include_ndk "${ANDROID_INCLUDE_NDK:-false}" \
      --arg ndk_version "${ANDROID_NDK_VERSION:-27.0.12077973}" \
      --arg include_cmake "${ANDROID_INCLUDE_CMAKE:-false}" \
      --arg cmake_version "${ANDROID_CMAKE_VERSION:-3.22.1}" \
      --argjson hash_overrides "$hash_overrides_json" \
      '{
        ANDROID_BUILD_TOOLS_VERSION: $build_tools,
        ANDROID_CMDLINE_TOOLS_VERSION: $cmdline_tools,
        ANDROID_COMPILE_SDK: ($compile_sdk | tonumber),
        ANDROID_TARGET_SDK: ($target_sdk | tonumber),
        ANDROID_SYSTEM_IMAGE_TAG: $system_image_tag,
        ANDROID_INCLUDE_NDK: ($include_ndk | test("true|1|yes|on"; "i")),
        ANDROID_NDK_VERSION: $ndk_version,
        ANDROID_INCLUDE_CMAKE: ($include_cmake | test("true|1|yes|on"; "i")),
        ANDROID_CMAKE_VERSION: $cmake_version,
        hash_overrides: $hash_overrides
      }' > "$android_lock_tmp"
  fi

  mv "$android_lock_tmp" "$android_lock_file"
  echo "✓ Generated android.lock"
}

# Regenerate devices.lock from device definitions
# Calls the eval command to regenerate devices.lock
android_regenerate_devices_lock() {
  local script_path="$0"

  echo ""
  echo "Evaluating device definitions..."

  # Call eval command to regenerate devices.lock
  DEVICES_CMD="eval" "$script_path" || {
    echo "ERROR: Failed to generate devices.lock" >&2
    return 1
  }

  return 0
}

# Sync AVDs with device definitions
# Ensures AVDs match the device definitions in devices.lock
android_sync_avds() {
  echo ""
  echo "Syncing AVDs with device definitions..."

  # Check if devices.lock exists
  if [ ! -f "$lock_file_path" ]; then
    echo "ERROR: devices.lock not found at $lock_file_path" >&2
    return 1
  fi

  # Validate lock file format
  if ! jq -e '.devices' "$lock_file_path" >/dev/null 2>&1; then
    echo "ERROR: Invalid devices.lock format" >&2
    return 1
  fi

  # Get device count
  local device_count
  device_count="$(jq '.devices | length' "$lock_file_path")"
  if [ "$device_count" -eq 0 ]; then
    echo "No devices defined in lock file"
    return 0
  fi

  # Parse ANDROID_DEVICES filter (comma-separated list)
  local selected_devices=()
  if [ -n "${ANDROID_DEVICES:-}" ]; then
    IFS=',' read -ra selected_devices <<< "${ANDROID_DEVICES}"
  fi

  echo "================================================"

  # Show available devices for filtering transparency
  if [ "${#selected_devices[@]}" -gt 0 ]; then
    echo "Filter: ANDROID_DEVICES=${ANDROID_DEVICES}"
    echo ""
    echo "Available devices in lock file:"
    local idx=0
    local missing_filename=false
    while [ "$idx" -lt "$device_count" ]; do
      local temp_json="$(jq -c ".devices[$idx]" "$lock_file_path")"
      local d_filename="$(echo "$temp_json" | jq -r '.filename // empty')"
      local d_name="$(echo "$temp_json" | jq -r '.name // empty')"
      local d_api="$(echo "$temp_json" | jq -r '.api // empty')"
      if [ -n "$d_filename" ]; then
        echo "  - $d_filename (name: $d_name, API $d_api)"
      else
        echo "  - [MISSING FILENAME] (name: $d_name, API $d_api)"
        missing_filename=true
      fi
      idx=$((idx + 1))
    done
    echo ""

    if [ "$missing_filename" = true ]; then
      echo "ERROR: Lock file missing filename metadata (old format)" >&2
      echo "       Regenerate with: devbox run android.sh devices eval" >&2
      return 1
    fi
  fi

  # Counters for summary
  local matched=0
  local recreated=0
  local created=0
  local skipped=0
  local filtered=0

  # Create temp files for each device definition
  local temp_dir
  temp_dir="$(mktemp -d)"

  # Extract each device from lock file and sync
  local device_index=0
  while [ "$device_index" -lt "$device_count" ]; do
    local device_json="$temp_dir/device_${device_index}.json"
    jq -c ".devices[$device_index]" "$lock_file_path" > "$device_json"

    # Get device identifier for filtering (filename only)
    local device_filename
    device_filename="$(jq -r '.filename // empty' "$device_json")"

    # Filter devices based on ANDROID_DEVICES if set
    if [ "${#selected_devices[@]}" -gt 0 ]; then
      local should_sync=false
      for selected in "${selected_devices[@]}"; do
        # Match against filename only (e.g., "min", "max")
        if [ "$device_filename" = "$selected" ]; then
          should_sync=true
          break
        fi
      done

      if [ "$should_sync" = false ]; then
        filtered=$((filtered + 1))
        device_index=$((device_index + 1))
        continue
      fi
    fi

    # Call ensure function and track result (use || true to prevent early exit)
    local result=0
    android_ensure_avd_from_definition "$device_json" || result=$?
    case $result in
      0) matched=$((matched + 1)) ;;
      1) recreated=$((recreated + 1)) ;;
      2) created=$((created + 1)) ;;
      3) skipped=$((skipped + 1)) ;;
      *) skipped=$((skipped + 1)) ;;
    esac

    device_index=$((device_index + 1))
  done

  echo "================================================"

  # Check if filtering resulted in zero devices being processed
  local total_processed=$((matched + recreated + created + skipped))
  if [ "${#selected_devices[@]}" -gt 0 ] && [ "$total_processed" -eq 0 ]; then
    echo ""
    echo "ERROR: No devices match ANDROID_DEVICES filter: ${ANDROID_DEVICES}" >&2
    echo "       All $filtered device(s) were filtered out" >&2
    echo ""
    echo "HINT: Filter matches device filename (e.g., min, max)" >&2
    echo "      Check available devices listed above" >&2
    rm -rf "$temp_dir"
    return 1
  fi

  echo "Sync complete:"
  echo "  ✓ Matched:   $matched"
  if [ "$recreated" -gt 0 ]; then
    echo "  🔄 Recreated: $recreated"
  fi
  if [ "$created" -gt 0 ]; then
    echo "  ➕ Created:   $created"
  fi
  if [ "$skipped" -gt 0 ]; then
    echo "  ⚠ Skipped:   $skipped (missing system images)"
  fi
  if [ "$filtered" -gt 0 ]; then
    echo "  ⊗ Filtered:  $filtered (ANDROID_DEVICES=${ANDROID_DEVICES})"
  fi

  # In strict mode (pure shell / CI), fail if any devices were skipped
  if [ "$skipped" -gt 0 ]; then
    if [ "${DEVBOX_PURE_SHELL:-}" = "1" ] || [ "${ANDROID_STRICT_SYNC:-}" = "1" ]; then
      echo ""
      echo "ERROR: $skipped device(s) skipped due to missing system images (strict mode)" >&2
      echo "       This is different from filtering - system images need to be downloaded" >&2
      echo "       Re-enter devbox shell to download system images or update device definitions" >&2
      rm -rf "$temp_dir"
      return 1
    fi
  fi

  rm -rf "$temp_dir"
  return 0
}

# ============================================================================
# Command Handlers
# ============================================================================

case "$command_name" in
  # --------------------------------------------------------------------------
  # list - Display all device definitions
  # --------------------------------------------------------------------------
  list)
    for device_file in "$devices_dir"/*.json; do
      [ -f "$device_file" ] || continue
      jq -r '"\(.name // "")\t\(.api // "")\t\(.device // "")\t\(.tag // "")\t\(.preferred_abi // "")\t\(. | @json)"' "$device_file"
    done
    ;;

  # --------------------------------------------------------------------------
  # show - Display specific device definition
  # --------------------------------------------------------------------------
  show)
    device_name="${1-}"
    [ -n "$device_name" ] || usage

    device_file="$(resolve_device_file "$device_name")" || {
      echo "ERROR: Device not found: $device_name" >&2
      exit 1
    }

    cat "$device_file"
    ;;

  # --------------------------------------------------------------------------
  # create - Create new device definition
  # --------------------------------------------------------------------------
  create)
    device_name="${1-}"
    [ -n "$device_name" ] || usage
    shift || true

    # Parse options
    api_level=""
    device_hardware=""
    image_tag=""
    preferred_abi=""

    while [ "${1-}" != "" ]; do
      case "$1" in
        --api)
          api_level="$2"
          shift 2
          ;;
        --device)
          device_hardware="$2"
          shift 2
          ;;
        --tag)
          image_tag="$2"
          shift 2
          ;;
        --abi)
          preferred_abi="$2"
          shift 2
          ;;
        *)
          usage
          ;;
      esac
    done

    # Validate required fields
    [ -n "$api_level" ] || {
      echo "ERROR: --api is required" >&2
      exit 1
    }
    [ -n "$device_hardware" ] || {
      echo "ERROR: --device is required" >&2
      exit 1
    }

    # Validate field values
    validate_api "$api_level"
    if [ -n "$image_tag" ]; then
      validate_tag "$image_tag"
    fi
    if [ -n "$preferred_abi" ]; then
      validate_abi "$preferred_abi"
    fi

    # Create devices directory if it doesn't exist
    mkdir -p "$devices_dir"

    # Build JSON object with conditional fields
    device_json="$(jq -n \
      --arg name "$device_name" \
      --argjson api "$api_level" \
      --arg device "$device_hardware" \
      --arg tag "$image_tag" \
      --arg abi "$preferred_abi" \
      '{name:$name, api:$api, device:$device}
      + (if $tag != "" then {tag:$tag} else {} end)
      + (if $abi != "" then {preferred_abi:$abi} else {} end)'
    )"

    output_file="$devices_dir/${device_name}.json"
    printf '%s\n' "$device_json" > "$output_file"
    echo "Created device definition: $output_file"
    ;;

  # --------------------------------------------------------------------------
  # update - Update existing device definition
  # --------------------------------------------------------------------------
  update)
    device_name="${1-}"
    [ -n "$device_name" ] || usage
    shift || true

    device_file="$(resolve_device_file "$device_name")" || {
      echo "ERROR: Device not found: $device_name" >&2
      exit 1
    }

    # Parse options
    new_name=""
    api_level=""
    device_hardware=""
    image_tag=""
    preferred_abi=""

    while [ "${1-}" != "" ]; do
      case "$1" in
        --name)
          new_name="$2"
          shift 2
          ;;
        --api)
          api_level="$2"
          shift 2
          ;;
        --device)
          device_hardware="$2"
          shift 2
          ;;
        --tag)
          image_tag="$2"
          shift 2
          ;;
        --abi)
          preferred_abi="$2"
          shift 2
          ;;
        *)
          usage
          ;;
      esac
    done

    # Validate provided values
    if [ -n "$api_level" ]; then
      validate_api "$api_level"
    fi
    if [ -n "$image_tag" ]; then
      validate_tag "$image_tag"
    fi
    if [ -n "$preferred_abi" ]; then
      validate_abi "$preferred_abi"
    fi

    # Update JSON using jq
    temp_file="${device_file}.tmp"
    jq \
      --arg name "$new_name" \
      --arg api "$api_level" \
      --arg device "$device_hardware" \
      --arg tag "$image_tag" \
      --arg abi "$preferred_abi" \
      '(if $name != "" then .name=$name else . end)
      | (if $api != "" then .api=($api|tonumber) else . end)
      | (if $device != "" then .device=$device else . end)
      | (if $tag != "" then .tag=$tag else . end)
      | (if $abi != "" then .preferred_abi=$abi else . end)' \
      "$device_file" > "$temp_file"

    mv "$temp_file" "$device_file"

    # If name changed, rename the file
    if [ -n "$new_name" ]; then
      new_file="$devices_dir/${new_name}.json"
      mv "$device_file" "$new_file"
      echo "Updated and renamed device definition: $new_file"
    else
      echo "Updated device definition: $device_file"
    fi
    ;;

  # --------------------------------------------------------------------------
  # delete - Remove device definition
  # --------------------------------------------------------------------------
  delete)
    device_name="${1-}"
    [ -n "$device_name" ] || usage

    device_file="$(resolve_device_file "$device_name")" || {
      echo "ERROR: Device not found: $device_name" >&2
      exit 1
    }

    rm -f "$device_file"
    echo "Deleted device definition: $device_file"
    ;;


  # --------------------------------------------------------------------------
  # eval - Generate devices.lock from device definitions
  # --------------------------------------------------------------------------
  eval)
    # Suppress SDK warnings during eval - SDK will be available after initialization
    export ANDROID_DEVICES_EVAL=1

    if [ ! -d "$devices_dir" ]; then
      echo "ERROR: Devices directory not found: $devices_dir" >&2
      exit 1
    fi

    # Check if any device files exist
    device_files="$(ls "$devices_dir"/*.json 2>/dev/null || true)"
    if [ -z "$device_files" ]; then
      echo "ERROR: No device definitions found in ${devices_dir}" >&2
      exit 1
    fi

    # Build JSON array of device information (include all fields + file metadata)
    devices_json="$(
      for device_file in $device_files; do
        device_basename="$(basename "$device_file" .json)"
        jq -c --arg path "$device_file" --arg filename "$device_basename" \
          '. + {file: $path, filename: $filename}' \
          "$device_file"
      done | jq -s '.'
    )"

    # Eval scans ALL device files (no filtering) and generates full lock file
    # Set ANDROID_DEVICES env var in devbox.json to filter devices

    # Check we have at least one device
    device_count="$(printf '%s\n' "$devices_json" | jq '. | length')"
    if [ "$device_count" -eq 0 ]; then
      echo "ERROR: No device definitions found in ${devices_dir}" >&2
      exit 1
    fi

    # Compute checksum using shared utility function
    checksum="$(android_compute_devices_checksum "$devices_dir" || echo "")"

    # Check if checksum changed (to determine if we need to update flake)
    old_checksum=""
    if [ -f "$lock_file_path" ]; then
      old_checksum="$(jq -r '.checksum // ""' "$lock_file_path" 2>/dev/null || echo "")"
    fi
    checksum_changed=false
    if [ "$old_checksum" != "$checksum" ]; then
      checksum_changed=true
    fi

    # Generate lock file with full device configs (strip .file path, keep .filename for filtering)
    temp_lock_file="${lock_file_path}.tmp"
    printf '%s\n' "$devices_json" | jq \
      --arg cs "$checksum" \
      'map(del(.file)) | {devices: ., checksum: $cs}' \
      > "$temp_lock_file"

    mv "$temp_lock_file" "$lock_file_path"

    # Print summary
    device_count="$(jq '.devices | length' "$lock_file_path")"
    api_list="$(jq -r '.devices | map(.api) | join(",")' "$lock_file_path")"
    echo "Lock file generated: ${device_count} devices with APIs ${api_list}"
    ;;

  # --------------------------------------------------------------------------
  # Sync: Generate android.lock and devices.lock, ensure AVDs match
  # --------------------------------------------------------------------------
  sync)
    echo "Syncing Android configuration..."
    echo "================================================"

    # Step 1: Generate android.lock from env vars
    android_generate_android_lock

    # Step 2: Regenerate devices.lock
    android_regenerate_devices_lock || exit 1

    # Step 3: Sync AVDs with device definitions
    android_sync_avds || exit 1
    ;;

  # --------------------------------------------------------------------------
  # hash - Manage Nix hash overrides in android.lock
  # --------------------------------------------------------------------------
  hash)
    subcommand="${1-}"
    [ -n "$subcommand" ] || usage
    shift || true

    android_lock_file="${config_dir}/android.lock"

    case "$subcommand" in
      show)
        # Display current hash overrides
        if [ ! -f "$android_lock_file" ]; then
          echo "No android.lock file found"
          exit 0
        fi

        if ! jq -e '.hash_overrides' "$android_lock_file" >/dev/null 2>&1; then
          echo "No hash overrides set"
          exit 0
        fi

        override_count=$(jq '.hash_overrides | length' "$android_lock_file")
        if [ "$override_count" -eq 0 ]; then
          echo "No hash overrides set"
          exit 0
        fi

        echo "Hash overrides in android.lock:"
        jq -r '.hash_overrides | to_entries[] | "  \(.key): \(.value)"' "$android_lock_file"
        ;;

      update)
        # Add or update a hash override
        url="${1-}"
        new_hash="${2-}"

        if [ -z "$url" ] || [ -z "$new_hash" ]; then
          echo "ERROR: Both URL and hash are required" >&2
          echo "Usage: devices.sh hash update <url> <hash>" >&2
          exit 1
        fi

        # Ensure android.lock exists
        if [ ! -f "$android_lock_file" ]; then
          echo "ERROR: android.lock not found. Run 'devices.sh sync' first." >&2
          exit 1
        fi

        # Update hash override
        temp_lock="${android_lock_file}.tmp"
        jq --arg url "$url" --arg hash "$new_hash" \
          '.hash_overrides = (.hash_overrides // {}) | .hash_overrides[$url] = $hash' \
          "$android_lock_file" > "$temp_lock"

        mv "$temp_lock" "$android_lock_file"
        echo "✓ Added hash override for: $url"
        echo "  Hash: $new_hash"
        echo ""
        echo "IMPORTANT: Commit android.lock to preserve this fix:"
        echo "  git add devbox.d/*/android.lock"
        echo "  git commit -m 'fix(android): add hash override for $(basename "$url")'"
        ;;

      clear)
        # Remove all hash overrides
        if [ ! -f "$android_lock_file" ]; then
          echo "No android.lock file found"
          exit 0
        fi

        if ! jq -e '.hash_overrides' "$android_lock_file" >/dev/null 2>&1; then
          echo "No hash overrides to clear"
          exit 0
        fi

        override_count=$(jq '.hash_overrides | length' "$android_lock_file")
        if [ "$override_count" -eq 0 ]; then
          echo "No hash overrides to clear"
          exit 0
        fi

        # Remove hash_overrides field
        temp_lock="${android_lock_file}.tmp"
        jq 'del(.hash_overrides)' "$android_lock_file" > "$temp_lock"
        mv "$temp_lock" "$android_lock_file"

        echo "✓ Cleared $override_count hash override(s) from android.lock"
        ;;

      *)
        echo "ERROR: Unknown hash subcommand: $subcommand" >&2
        usage
        ;;
    esac
    ;;

  # --------------------------------------------------------------------------
  # Unknown command
  # --------------------------------------------------------------------------
  *)
    echo "ERROR: Unknown command: $command_name" >&2
    usage
    ;;
esac
