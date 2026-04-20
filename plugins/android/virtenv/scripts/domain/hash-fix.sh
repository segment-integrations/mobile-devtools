#!/usr/bin/env bash
# Android SDK Hash Mismatch Auto-Fix
# Detects and fixes hash mismatches caused by Google updating files on their servers

set -e

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../lib/lib.sh" ]; then
  . "${SCRIPT_DIR}/../lib/lib.sh"
fi

# ============================================================================
# Logging Utilities
# ============================================================================

android_hash_fix_log_verbose() {
  [ "${ANDROID_HASH_FIX_VERBOSE:-0}" = "1" ] && echo "$@" >&2
}

android_hash_fix_log_info() {
  echo "$@" >&2
}

# ============================================================================
# Hash Mismatch Detection
# ============================================================================

android_hash_fix_detect_mismatch() {
  local nix_stderr="$1"

  # Extract hash mismatch info from nix error
  # Example: "specified: sha1-/4+s3hN+V5lBEmcqDQ9BGjynsgE="
  #          "got:      sha1-jEySbQyhkjdrKgSwMYSEckMZ5nw="

  if ! echo "$nix_stderr" | grep -q "hash mismatch in fixed-output derivation"; then
    return 1
  fi

  # Extract URL from error (look for https://dl.google.com/android/repository/...)
  local url
  url=$(echo "$nix_stderr" | grep -oE "https://dl\.google\.com/android/repository/[^'\"[:space:]]+")

  if [ -z "$url" ]; then
    echo "Could not extract URL from hash mismatch error" >&2
    return 1
  fi

  # Extract expected and actual hashes
  local expected_hash actual_hash
  expected_hash=$(echo "$nix_stderr" | grep "specified:" | grep -oE "sha1-[A-Za-z0-9+/=]+")
  actual_hash=$(echo "$nix_stderr" | grep "got:" | grep -oE "sha1-[A-Za-z0-9+/=]+")

  echo "HASH_MISMATCH_URL=$url"
  echo "HASH_MISMATCH_EXPECTED=$expected_hash"
  echo "HASH_MISMATCH_ACTUAL=$actual_hash"

  return 0
}

# ============================================================================
# Hash Computation
# ============================================================================

android_hash_fix_download_and_compute() {
  local url="$1"
  local temp_file

  temp_file=$(mktemp "${TMPDIR:-/tmp}/android-hash-fix-XXXXXX")
  trap 'rm -f "$temp_file"' RETURN

  android_hash_fix_log_verbose "Downloading $url to verify hash..."
  if ! curl -fsSL "$url" -o "$temp_file"; then
    android_hash_fix_log_info "Failed to download $url"
    return 1
  fi

  # Compute SHA1
  local computed_hash
  if command -v sha1sum >/dev/null 2>&1; then
    computed_hash=$(sha1sum "$temp_file" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    computed_hash=$(shasum "$temp_file" | awk '{print $1}')
  else
    android_hash_fix_log_info "No sha1sum or shasum command available"
    return 1
  fi

  echo "$computed_hash"
  return 0
}

# ============================================================================
# Hash Override Update
# ============================================================================

android_hash_fix_update_hash_overrides() {
  local url="$1"
  local new_hash="$2"

  # Validate ANDROID_CONFIG_DIR
  if [ -z "${ANDROID_CONFIG_DIR:-}" ]; then
    android_hash_fix_log_info "ERROR: ANDROID_CONFIG_DIR not set"
    return 1
  fi

  if [ ! -d "${ANDROID_CONFIG_DIR}" ]; then
    android_hash_fix_log_info "ERROR: ANDROID_CONFIG_DIR directory does not exist: ${ANDROID_CONFIG_DIR}"
    return 1
  fi

  local hash_overrides_file="${ANDROID_CONFIG_DIR}/hash-overrides.json"

  # Create override key from URL (replace / with -)
  local override_key
  override_key=$(echo "$url" | sed 's|https://||; s|/|-|g')

  # Create or update hash-overrides.json
  local temp_json
  temp_json=$(mktemp)
  trap 'rm -f "$temp_json"' RETURN

  if [ -f "$hash_overrides_file" ]; then
    # Update existing file
    if ! jq --arg key "$override_key" --arg hash "$new_hash" \
      '.[$key] = $hash' \
      "$hash_overrides_file" > "$temp_json"; then
      android_hash_fix_log_info "Failed to update $hash_overrides_file"
      return 1
    fi
  else
    # Create new file
    if ! jq -n --arg key "$override_key" --arg hash "$new_hash" \
      '{($key): $hash}' > "$temp_json"; then
      android_hash_fix_log_info "Failed to create $hash_overrides_file"
      return 1
    fi
  fi

  mv "$temp_json" "$hash_overrides_file"
  android_hash_fix_log_verbose "Updated $hash_overrides_file with hash override for $url"
  android_hash_fix_log_verbose "  Override key: $override_key"
  android_hash_fix_log_verbose "  New hash: $new_hash"

  return 0
}

# ============================================================================
# Helper Functions
# ============================================================================

android_hash_fix_find_latest_error_log() {
  local nix_error_log="${1:-}"

  # If log file provided and exists, use it
  if [ -n "$nix_error_log" ] && [ -f "$nix_error_log" ]; then
    echo "$nix_error_log"
    return 0
  fi

  # Find the latest android-nix-build error log
  nix_error_log=$(find "${TMPDIR:-/tmp}" -name "android-nix-build-*.stderr" -type f 2>/dev/null | sort -r | head -n 1)

  if [ -z "$nix_error_log" ] || [ ! -f "$nix_error_log" ]; then
    android_hash_fix_log_info "Error: No android-nix-build error log found"
    android_hash_fix_log_info "  Looked in: ${TMPDIR:-/tmp}/android-nix-build-*.stderr"
    android_hash_fix_log_info ""
    android_hash_fix_log_info "The error log is created when 'devbox shell' fails to build the Android SDK."
    android_hash_fix_log_info "Please try running 'devbox shell' first to trigger the hash mismatch error."
    return 1
  fi

  android_hash_fix_log_verbose "Found error log: $nix_error_log"
  android_hash_fix_log_verbose ""

  echo "$nix_error_log"
  return 0
}

android_hash_fix_detect_and_extract_mismatch() {
  local nix_error_log="$1"

  android_hash_fix_log_verbose "🔍 Analyzing hash mismatch..."
  android_hash_fix_log_verbose ""

  local nix_stderr
  nix_stderr=$(cat "$nix_error_log")

  # Detect mismatch
  local mismatch_info
  if ! mismatch_info=$(android_hash_fix_detect_mismatch "$nix_stderr"); then
    android_hash_fix_log_info "No hash mismatch detected in error log"
    return 1
  fi

  echo "$mismatch_info"
  return 0
}

android_hash_fix_verify_and_fix_hash() {
  local url="$1"
  local filename
  filename=$(basename "$url")

  android_hash_fix_log_verbose "📦 File with mismatch: $url"
  android_hash_fix_log_verbose "   Expected: $HASH_MISMATCH_EXPECTED"
  android_hash_fix_log_verbose "   Got:      $HASH_MISMATCH_ACTUAL"
  android_hash_fix_log_verbose ""
  android_hash_fix_log_verbose "⬇️  Downloading file to verify hash..."

  if [ "${ANDROID_HASH_FIX_VERBOSE:-0}" != "1" ]; then
    android_hash_fix_log_info "🔍 Detected mismatch in: $filename"
    android_hash_fix_log_info "⬇️  Downloading and verifying..."
  fi

  # Download and compute actual hash
  local computed_hash
  if ! computed_hash=$(android_hash_fix_download_and_compute "$url" 2>/dev/null); then
    android_hash_fix_log_info "Failed to download and compute hash"
    return 1
  fi

  android_hash_fix_log_verbose "✓ Computed hash: $computed_hash"
  android_hash_fix_log_verbose ""
  android_hash_fix_log_verbose "📝 Updating hash-overrides.json with hash override..."

  # Update hash-overrides.json
  if ! android_hash_fix_update_hash_overrides "$url" "$computed_hash" 2>/dev/null; then
    android_hash_fix_log_verbose "Failed to update hash-overrides.json"
    return 1
  fi

  return 0
}

android_hash_fix_show_success_message() {
  local filename
  filename=$(basename "$HASH_MISMATCH_URL")

  if [ "${ANDROID_HASH_FIX_VERBOSE:-0}" = "1" ]; then
    android_hash_fix_log_info ""
    android_hash_fix_log_info "✅ Hash override added to hash-overrides.json"
    android_hash_fix_log_info ""
    android_hash_fix_log_info "IMPORTANT: Commit this file to preserve reproducibility!"
    android_hash_fix_log_info ""
    android_hash_fix_log_info "  git add devbox.d/*/hash-overrides.json"
    android_hash_fix_log_info "  git commit -m \"fix(android): add hash override for $filename\""
    android_hash_fix_log_info ""
    android_hash_fix_log_info "This ensures everyone on your team gets the fix automatically."
    android_hash_fix_log_info "The override is temporary and can be removed when nixpkgs is updated."
    android_hash_fix_log_info ""
    android_hash_fix_log_info "Next steps:"
    android_hash_fix_log_info "  1. Run 'devbox shell' again to rebuild with corrected hash"
    android_hash_fix_log_info "  2. Commit hash-overrides.json to your repository"
    android_hash_fix_log_info ""
  else
    android_hash_fix_log_info "✓ Hash override saved to hash-overrides.json"
  fi
}

# ============================================================================
# Main Auto-Fix Function
# ============================================================================

android_hash_fix_auto() {
  local nix_error_log="${1:-}"

  # Find error log
  nix_error_log=$(android_hash_fix_find_latest_error_log "$nix_error_log") || return 1

  # Detect and extract mismatch
  local mismatch_info
  mismatch_info=$(android_hash_fix_detect_and_extract_mismatch "$nix_error_log") || return 1
  eval "$mismatch_info"

  # Validate extraction
  if [ -z "$HASH_MISMATCH_URL" ]; then
    android_hash_fix_log_info "Could not extract mismatch info"
    return 1
  fi

  # Verify and fix
  android_hash_fix_verify_and_fix_hash "$HASH_MISMATCH_URL" || return 1

  # Show success message
  android_hash_fix_show_success_message

  return 0
}

# ============================================================================
# CLI Entry Point
# ============================================================================

# If called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    detect)
      shift
      android_hash_fix_detect_mismatch "$@"
      ;;
    compute)
      shift
      android_hash_fix_download_and_compute "$@"
      ;;
    update)
      shift
      android_hash_fix_update_hash_overrides "$@"
      ;;
    auto)
      shift
      android_hash_fix_auto "$@"
      ;;
    *)
      echo "Usage: $0 {detect|compute|update|auto} [args...]" >&2
      exit 1
      ;;
  esac
fi
