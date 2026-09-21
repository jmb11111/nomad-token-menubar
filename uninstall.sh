#!/usr/bin/env bash
#
# Uninstaller for nomad-token-menubar. Removes the plugin and (optionally) the
# data directory. Does not uninstall SwiftBar or jq.

set -euo pipefail
DATA_DIR="$HOME/.nomad-token-menubar"

PLUGIN_DIR="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || echo "$HOME/.swiftbar-plugins")"
rm -f "$PLUGIN_DIR/nomad-token.30s.sh"
echo "Removed plugin from $PLUGIN_DIR"

read -r -p "Also remove $DATA_DIR (config + cached token)? [y/N] " ans
if [[ "$ans" == [yY] ]]; then
  rm -rf "$DATA_DIR"
  echo "Removed $DATA_DIR"
else
  echo "Kept $DATA_DIR"
fi

open -g "swiftbar://refreshallplugins" >/dev/null 2>&1 || true
echo "Done. (SwiftBar and jq were left installed.)"
