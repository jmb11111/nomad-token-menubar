#!/usr/bin/env bash
#
# nomad-token-menubar — installer + setup wizard in one.
#
#   ./install.sh          install (or update) everything, then configure
#   ./install.sh setup    just (re-)run the configuration wizard
#
# After install a copy lives at ~/.nomad-token-menubar/nomad-token-menubar.sh,
# and the menu bar's "Run setup…" runs it with `setup`.
#
# Note: no `set -e` — the wizard uses interactive reads and conditional tests
# that legitimately return non-zero; failures in the install steps are handled
# explicitly with `die`.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${NOMAD_MENUBAR_DIR:-$HOME/.nomad-token-menubar}"
CONFIG="$DATA_DIR/config.sh"
REFRESH="$DATA_DIR/lib/refresh.sh"

# ---------- ui helpers -------------------------------------------------------
say()  { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[33m  %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m%s\033[0m\n' "$*"; }
err()  { printf '\033[31m%s\033[0m\n' "$*"; }
die()  { err "$*"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
ask()  { local p="$1" d="${2:-}" a
  if [[ -n "$d" ]]; then read -r -p "$p [$d]: " a; printf '%s' "${a:-$d}"
  else read -r -p "$p: " a; printf '%s' "$a"; fi; }
sq()   { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
configured() { [[ -f "$CONFIG" ]] && grep -Eq "^[[:space:]]*REFRESH_CMD=[\"']?[^\"'[:space:]]" "$CONFIG"; }

# ---------- wizard -----------------------------------------------------------
run_setup() {
  [[ -t 0 ]] || die "setup needs an interactive terminal (run: $DATA_DIR/nomad-token-menubar.sh setup)"
  mkdir -p "$DATA_DIR"
  say "nomad-token-menubar — setup"
  echo "This writes $CONFIG"; echo

  if configured; then
    local a; a="$(ask "A config already exists — overwrite it? (y/N)" "N")"
    [[ "$a" == [yY] ]] || { echo "Keeping existing config. Nothing changed."; return 0; }
    echo
  fi

  echo "How do you fetch a Nomad token?"
  echo "  1) Vault Nomad secrets engine   (vault read <mount>/creds/<role>)"
  echo "  2) Nomad ACL auth method / OIDC (nomad login -method=<method>)"
  echo "  3) A custom command or script that prints a token"
  local choice; choice="$(ask "Choose 1/2/3" "1")"; echo

  local REFRESH_CMD="" EXPIRY="" NOMAD_ADDR=""
  case "$choice" in
    1)
      local mount role
      mount="$(ask "Vault mount path" "nomad")"
      role="$(ask "Nomad creds role" "nomad-admin")"
      REFRESH_CMD="r=\$(vault read -format=json ${mount}/creds/${role}); echo \"\$r\" | jq -r .data.secret_id; echo \"\$r\" | jq -r .lease_duration"
      EXPIRY="self"  # unused (TTL comes from the lease on line 2), harmless default
      ;;
    2)
      local method
      method="$(ask "Nomad ACL auth method name" "")"
      NOMAD_ADDR="$(ask "NOMAD_ADDR" "")"
      REFRESH_CMD="nomad login -method=${method} -json | jq -r .SecretID"
      EXPIRY="self"
      ;;
    3)
      echo "Enter the command that prints a fresh token on stdout (line 1)."
      REFRESH_CMD="$(ask "REFRESH_CMD" "")"
      local has_ttl; has_ttl="$(ask "Does it also print the TTL in seconds on line 2? (y/N)" "N")"
      if [[ "$has_ttl" == [yY] ]]; then
        EXPIRY="self"
      else
        local exp; exp="$(ask "Token lifetime — seconds (e.g. 3600), or 'self' to ask Nomad" "3600")"
        EXPIRY="$exp"
        [[ "$exp" == "self" ]] && NOMAD_ADDR="$(ask "NOMAD_ADDR" "")"
      fi
      ;;
    *) die "Invalid choice." ;;
  esac
  [[ -n "$REFRESH_CMD" ]] || die "No REFRESH_CMD given."

  # Test it, capturing stdout (the token) and stderr (diagnostics) separately.
  echo; say "Testing your command…"
  local errf out tok ttl; errf="$(mktemp)"
  out="$(eval "$REFRESH_CMD" 2>"$errf")" || true
  tok="$(printf '%s\n' "$out" | sed -n '1p')"
  ttl="$(printf '%s\n' "$out" | sed -n '2p' | tr -d '[:space:]')"
  if [[ -n "$tok" ]]; then
    ok "✓ got a token (${#tok} chars)$([[ "$ttl" =~ ^[0-9]+$ ]] && echo ", TTL ${ttl}s")"
  else
    err "✗ no token produced."
    [[ -s "$errf" ]] && { echo "  stderr:"; sed 's/^/    /' "$errf"; }
    local a; a="$(ask "Save this config anyway? (y/N)" "N")"
    [[ "$a" == [yY] ]] || { rm -f "$errf"; die "Aborted; nothing written."; }
  fi
  rm -f "$errf"

  {
    echo "# nomad-token-menubar configuration (generated $(date +%F))"
    echo "REFRESH_CMD=$(sq "$REFRESH_CMD")"
    [[ -n "$EXPIRY"     ]] && echo "EXPIRY=$(sq "$EXPIRY")"
    [[ -n "$NOMAD_ADDR" ]] && echo "NOMAD_ADDR=$(sq "$NOMAD_ADDR")"
  } > "$CONFIG"
  chmod 600 "$CONFIG"
  echo; ok "Wrote $CONFIG"

  if [[ -x "$REFRESH" ]]; then
    local a; a="$(ask "Fetch a token now and light up the menu bar? (Y/n)" "Y")"
    if [[ "$a" != [nN] ]]; then
      if "$REFRESH"; then ok "✓ Done — check your menu bar."; else err "Fetch failed; try the Refresh button later."; fi
    fi
  fi
}

# ---------- install ----------------------------------------------------------
do_install() {
  [[ "$(uname)" == "Darwin" ]] || die "This tool is macOS-only (SwiftBar)."
  say "nomad-token-menubar installer"

  have brew || die "Homebrew not found. Install from https://brew.sh, then re-run. (Needs: SwiftBar, jq.)"
  if [[ -d /Applications/SwiftBar.app ]]; then info "SwiftBar already installed."
  else info "Installing SwiftBar…"; brew install --cask swiftbar || die "brew install swiftbar failed"; fi
  if have jq; then info "jq present."; else info "Installing jq…"; brew install jq || die "brew install jq failed"; fi
  have nomad || warn "Nomad CLI not found — only needed if you set EXPIRY=self."

  info "Installing to $DATA_DIR"
  mkdir -p "$DATA_DIR/lib" "$DATA_DIR/assets" || die "mkdir failed"
  cp "$SRC/lib/refresh.sh"          "$DATA_DIR/lib/refresh.sh"            || die "copy refresh.sh failed"
  cp "$SRC/install.sh"              "$DATA_DIR/nomad-token-menubar.sh"    || die "copy self failed"
  cp "$SRC/assets/nomad-green.png" "$SRC/assets/nomad-red.png" "$DATA_DIR/assets/" || die "copy assets failed"
  cp "$SRC/assets/nomad.svg"        "$DATA_DIR/assets/" 2>/dev/null || true
  cp "$SRC/config.example.sh"       "$DATA_DIR/config.example.sh" 2>/dev/null || true
  chmod +x "$DATA_DIR/lib/refresh.sh" "$DATA_DIR/nomad-token-menubar.sh"

  local PLUGIN_DIR
  PLUGIN_DIR="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)"
  if [[ -z "$PLUGIN_DIR" ]]; then
    PLUGIN_DIR="$HOME/.swiftbar-plugins"; mkdir -p "$PLUGIN_DIR"
    defaults write com.ameba.SwiftBar PluginDirectory "$PLUGIN_DIR"
    info "Set SwiftBar plugin dir to $PLUGIN_DIR"
  else
    info "Using existing SwiftBar plugin dir: $PLUGIN_DIR"
  fi
  cp "$SRC/plugin/nomad-token.30s.sh" "$PLUGIN_DIR/nomad-token.30s.sh" || die "copy plugin failed"
  chmod +x "$PLUGIN_DIR/nomad-token.30s.sh"

  open -a SwiftBar >/dev/null 2>&1 || true
  sleep 1
  open -g "swiftbar://refreshallplugins" >/dev/null 2>&1 || true
}

# ---------- main -------------------------------------------------------------
case "${1:-install}" in
  setup|--setup|reconfigure)
    run_setup
    ;;
  install|"")
    do_install
    echo
    if configured; then
      say "Done — already configured."
      info "Reconfigure anytime:  $DATA_DIR/nomad-token-menubar.sh setup"
    elif [[ -t 0 && -t 1 ]]; then
      say "Files installed — let's configure it."; echo
      run_setup
    else
      say "Files installed."
      warn "Configure with:  $DATA_DIR/nomad-token-menubar.sh setup"
    fi
    echo
    info "Optional shell integration: shell/nomad-token-menubar.sh (see README)."
    ;;
  *)
    die "Usage: install.sh [setup]"
    ;;
esac
