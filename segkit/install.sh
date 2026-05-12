#!/bin/sh
# Install segkit — Segment SDK developer toolkit
# Usage: curl -fsSL https://raw.githubusercontent.com/segment-integrations/mobile-devtools/main/segkit/install.sh | sh
set -eu

FLAKE_REF="github:segment-integrations/mobile-devtools?dir=segkit#segkit"
NIX_INSTALL_URL="https://install.determinate.systems/nix"
STATE_DIR="${HOME}/.segkit"

info() { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
err()  { printf '\033[1;31m==> %s\033[0m\n' "$*" >&2; }

mkdir -p "$STATE_DIR"

# --- Install Determinate Nix if needed ---
if ! command -v nix >/dev/null 2>&1; then
  info "Installing Determinate Nix..."
  curl -fsSL "$NIX_INSTALL_URL" | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  if ! command -v nix >/dev/null 2>&1; then
    err "Nix not found after install. Open a new shell and re-run."
    exit 1
  fi
  touch "$STATE_DIR/installed-nix"
fi

# --- Install segkit ---
info "Installing segkit..."
nix --extra-experimental-features 'nix-command flakes' profile install "$FLAKE_REF"
touch "$STATE_DIR/installed-segkit"

info "Done!"
echo ""
echo "  You may need to restart your shell for PATH changes to take effect."
echo ""
echo "  Next steps:"
echo "    segkit doctor --fix   Install project dependencies"
echo "    segkit --help         See all commands"
echo ""
