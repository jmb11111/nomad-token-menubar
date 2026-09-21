#!/usr/bin/env bash
#
# Installer for nomad-token-menubar.
# Copies the plugin + assets into place, installs deps if missing, and points
# SwiftBar at the plugin. Idempotent — safe to re-run to update.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$HOME/.nomad-token-menubar"

say()  { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  %s\033[0m\n' "$*"; }

[[ "$(uname)" == "Darwin" ]] || { echo "This tool is macOS-only (SwiftBar)."; exit 1; }

say "nomad-token-menubar installer"

# --- dependencies -------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

if ! have brew; then
  warn "Homebrew not found. Install it from https://brew.sh, then re-run."
  warn "You need: SwiftBar, jq (and the Nomad CLI if you use EXPIRY=self)."
  exit 1
fi

if ! [[ -d "/Applications/SwiftBar.app" ]]; then
  info "Installing SwiftBar…"; brew install --cask swiftbar
else
  info "SwiftBar already installed."
fi
if ! have jq; then info "Installing jq…"; brew install jq; else info "jq present."; fi
have nomad || warn "Nomad CLI not found — only needed if you set EXPIRY=self."

# --- files --------------------------------------------------------------------
info "Installing to $DATA_DIR"
mkdir -p "$DATA_DIR/lib" "$DATA_DIR/assets"
cp "$SRC/lib/refresh.sh"        "$DATA_DIR/lib/refresh.sh"
cp "$SRC/setup.sh"              "$DATA_DIR/setup.sh"
cp "$SRC/assets/nomad-green.png" "$DATA_DIR/assets/"
cp "$SRC/assets/nomad-red.png"   "$DATA_DIR/assets/"
cp "$SRC/assets/nomad.svg"       "$DATA_DIR/assets/" 2>/dev/null || true
chmod +x "$DATA_DIR/lib/refresh.sh" "$DATA_DIR/setup.sh"

# A reference copy of the example is always available in the data dir.
cp "$SRC/config.example.sh" "$DATA_DIR/config.example.sh"

# --- SwiftBar plugin dir ------------------------------------------------------
PLUGIN_DIR="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)"
if [[ -z "$PLUGIN_DIR" ]]; then
  PLUGIN_DIR="$HOME/.swiftbar-plugins"
  mkdir -p "$PLUGIN_DIR"
  defaults write com.ameba.SwiftBar PluginDirectory "$PLUGIN_DIR"
  info "Set SwiftBar plugin dir to $PLUGIN_DIR"
else
  info "Using existing SwiftBar plugin dir: $PLUGIN_DIR"
fi
cp "$SRC/plugin/nomad-token.30s.sh" "$PLUGIN_DIR/nomad-token.30s.sh"
chmod +x "$PLUGIN_DIR/nomad-token.30s.sh"

# --- launch / refresh ---------------------------------------------------------
open -a SwiftBar >/dev/null 2>&1 || true
sleep 1
open -g "swiftbar://refreshallplugins" >/dev/null 2>&1 || true

# --- configure ----------------------------------------------------------------
configured() {
  [[ -f "$DATA_DIR/config.sh" ]] && grep -Eq "^[[:space:]]*REFRESH_CMD=[\"']?[^\"'[:space:]]" "$DATA_DIR/config.sh"
}

echo
if configured; then
  say "Done — already configured."
  info "Re-run setup anytime:  $DATA_DIR/setup.sh"
elif [[ -t 0 && -t 1 ]]; then
  say "Files installed — let's configure it."
  echo
  "$DATA_DIR/setup.sh"
else
  say "Files installed."
  warn "Run the setup wizard to configure:  $DATA_DIR/setup.sh"
fi
echo
info "Optional shell integration: shell/nomad-token-menubar.sh (see README)."
