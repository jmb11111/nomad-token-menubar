#!/usr/bin/env bash
#
# Fetches a fresh Nomad token using your REFRESH_CMD, records how long it is
# valid, and nudges the SwiftBar indicator to redraw. Runs headlessly (no
# terminal window) — it is what the menu bar "Refresh token" button calls.
#
# Contract for REFRESH_CMD (set in config.sh):
#   It must print a fresh Nomad token to stdout on line 1.
#   Optionally, print the token's lifetime in whole seconds on line 2.
#
# If line 2 is absent, the lifetime is resolved from EXPIRY (see config.sh):
#   - a plain integer  -> used as a fixed TTL in seconds
#   - "self"           -> `nomad acl token self` is queried for ExpirationTime
#                         (works for tokens that carry a Nomad-side expiry, e.g.
#                          ACL auth-method / OIDC logins)

set -uo pipefail

DATA_DIR="${NOMAD_MENUBAR_DIR:-$HOME/.nomad-token-menubar}"
CONFIG="$DATA_DIR/config.sh"
STATE="$DATA_DIR/state"
TOKEN_FILE="$DATA_DIR/token"

log() { printf '%s\n' "$*" >&2; }

[[ -f "$CONFIG" ]] || { log "no config at $CONFIG (copy config.example.sh)"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"

: "${REFRESH_CMD:?REFRESH_CMD is not set in config.sh}"
EXPIRY="${EXPIRY:-self}"

# Run the user's command. Line 1 = token, optional line 2 = ttl seconds.
if ! out="$(eval "$REFRESH_CMD")"; then
  log "REFRESH_CMD failed"; exit 1
fi
token="$(printf '%s\n' "$out" | sed -n '1p')"
ttl="$(printf '%s\n' "$out" | sed -n '2p' | tr -d '[:space:]')"

[[ -n "$token" ]] || { log "REFRESH_CMD produced no token"; exit 1; }

# Resolve TTL if the command didn't hand us one.
if ! [[ "$ttl" =~ ^[0-9]+$ ]]; then
  if [[ "$EXPIRY" =~ ^[0-9]+$ ]]; then
    ttl="$EXPIRY"
  elif [[ "$EXPIRY" == "self" ]]; then
    exp="$(NOMAD_TOKEN="$token" nomad acl token self ${NOMAD_ADDR:+-address="$NOMAD_ADDR"} -json 2>/dev/null \
            | jq -r '.ExpirationTime // empty')"
    if [[ -n "$exp" && "$exp" != "null" ]]; then
      # RFC3339 -> epoch: drop fractional seconds and trailing Z, read as UTC
      clean="${exp%.*}"; clean="${clean%Z}"
      exp_epoch="$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$clean" +%s 2>/dev/null || true)"
      [[ -n "$exp_epoch" ]] && ttl="$(( exp_epoch - $(date +%s) ))"
    fi
  fi
fi
[[ "$ttl" =~ ^-?[0-9]+$ ]] || ttl=0   # unknown -> 0 (indicator will show as needing refresh)

mkdir -p "$DATA_DIR"
printf '%s %s\n' "$(date +%s)" "$ttl" > "$STATE"
( umask 077; printf '%s' "$token" > "$TOKEN_FILE" )

# Redraw the menu bar now (-g = don't steal focus). Harmless if SwiftBar isn't running.
open -g "swiftbar://refreshallplugins" 2>/dev/null || true
