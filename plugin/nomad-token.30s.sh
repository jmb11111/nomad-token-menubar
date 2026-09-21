#!/usr/bin/env bash
#
# SwiftBar plugin: Nomad ACL token validity indicator.
#
# Reads state written by <data-dir>/lib/refresh.sh:
#   <data-dir>/state  = "<fetched_epoch> <ttl_seconds>"   (no secret)
#   <data-dir>/token  = the raw token, chmod 600           (for the Copy action)
#
# Menu bar shows the Nomad logo (green = valid, red = expired/none) + minutes left.
#
# <bitbar.title>Nomad Token</bitbar.title>
# <bitbar.desc>Shows whether a Nomad ACL token is set and how long it is valid.</bitbar.desc>
# <bitbar.author>nomad-token-menubar</bitbar.author>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>

DATA_DIR="${NOMAD_MENUBAR_DIR:-$HOME/.nomad-token-menubar}"
STATE="$DATA_DIR/state"
TOKEN_FILE="$DATA_DIR/token"
CONFIG="$DATA_DIR/config.sh"
REFRESH="$DATA_DIR/lib/refresh.sh"

b64() { [[ -f "$1" ]] && base64 -i "$1" | tr -d '\n'; }
IMG_GREEN=$(b64 "$DATA_DIR/assets/nomad-green.png")
IMG_RED=$(b64 "$DATA_DIR/assets/nomad-red.png")

human() { printf '%d:%02d' "$(( $1 / 60 ))" "$(( $1 % 60 ))"; }        # "M:SS" (dropdown)
mins()  { if (( $1 >= 60 )); then echo "$(( $1 / 60 ))m"; else echo "<1m"; fi; }  # "Nm" (menu bar)

# title <text> <green|red>
title() {
  local text="$1" img fallback
  case "$2" in
    green) img="$IMG_GREEN"; fallback="🟢" ;;
    red)   img="$IMG_RED";   fallback="🔴" ;;
  esac
  if [[ -n "$img" ]]; then
    echo "$text | image=$img font=Menlo size=13"
  else
    echo "$fallback $text | font=Menlo size=13"
  fi
}

refresh_line() {
  echo "Refresh token | bash=$REFRESH terminal=false refresh=true"
}
copy_line() {
  [[ -f "$TOKEN_FILE" ]] && echo "Copy token to clipboard | bash=/bin/bash param1=-c param2=\"pbcopy < $TOKEN_FILE\" terminal=false"
}
config_line() {
  echo "Edit config… | bash=/usr/bin/open param1=-t param2=$CONFIG terminal=false"
}

# --- Not configured yet -------------------------------------------------------
if [[ ! -f "$CONFIG" ]]; then
  title "setup" red
  echo "---"
  echo "Not configured | color=#888888"
  echo "Create $CONFIG (see config.example.sh)"
  refresh_line
  exit 0
fi

# --- No token fetched yet -----------------------------------------------------
if [[ ! -f "$STATE" ]]; then
  title "—" red
  echo "---"
  echo "No token fetched yet | color=#888888"
  refresh_line
  config_line
  exit 0
fi

read -r fetched ttl < "$STATE"
now=$(date +%s)

if [[ -z "$fetched" || -z "$ttl" ]]; then
  title "?" red
  echo "---"
  echo "State file unreadable | color=#888888"
  refresh_line
  config_line
  exit 0
fi

expires=$(( fetched + ttl ))
remaining=$(( expires - now ))
fetched_h=$(date -r "$fetched" '+%H:%M:%S')
expires_h=$(date -r "$expires" '+%H:%M:%S')

if (( remaining <= 0 )); then
  title "exp" red
  echo "---"
  echo "Token EXPIRED | color=#e74c3c"
  echo "Expired at $expires_h ($(human $(( -remaining ))) ago)"
else
  title "$(mins "$remaining")" green
  echo "---"
  echo "Token valid | color=#2ecc71"
  echo "$(human "$remaining") remaining"
  copy_line
fi

echo "Fetched:  $fetched_h"
echo "Expires:  $expires_h"
echo "---"
refresh_line
config_line
