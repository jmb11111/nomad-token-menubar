# nomad-token-menubar — optional shell integration (bash/zsh)
#
# The menu bar works WITHOUT this. Source it only if you also want a one-liner
# that refreshes the token and exports NOMAD_TOKEN into your current shell.
#
# Add to your ~/.zshrc or ~/.bashrc:
#     source /path/to/nomad-token-menubar/shell/nomad-token-menubar.sh
#
# Then run `nt` to refresh + export, or `nt-export` to just load the cached one.

_NOMAD_MENUBAR_DIR="${NOMAD_MENUBAR_DIR:-$HOME/.nomad-token-menubar}"

# Refresh the token (same as the menu bar button) and export it here.
nt() {
  "$_NOMAD_MENUBAR_DIR/lib/refresh.sh" || return 1
  export NOMAD_TOKEN="$(cat "$_NOMAD_MENUBAR_DIR/token")"
  echo "NOMAD_TOKEN set (menu bar updated)"
}

# Export the already-cached token without refreshing.
nt-export() {
  if [[ -f "$_NOMAD_MENUBAR_DIR/token" ]]; then
    export NOMAD_TOKEN="$(cat "$_NOMAD_MENUBAR_DIR/token")"
    echo "NOMAD_TOKEN set from cache"
  else
    echo "no cached token; run nt" >&2; return 1
  fi
}
