# nomad-token-menubar configuration
#
# Copy this file to  ~/.nomad-token-menubar/config.sh  and edit.
# (install.sh does the copy for you if config.sh doesn't exist yet.)
#
# This file is sourced by a shell script, so it is plain shell syntax.

# ---------------------------------------------------------------------------
# REFRESH_CMD (required)
#
# A command that prints a FRESH Nomad token to stdout on line 1.
# Optionally, print the token's lifetime in whole seconds on line 2 — if you
# do, EXPIRY below is ignored.
#
# Whatever you already run to mint a token goes here. A few shapes:

# -- Vault Nomad secrets engine (prints token + its lease as the TTL) --------
# REFRESH_CMD='r=$(vault read -format=json nomad/creds/YOUR_ROLE); \
#   echo "$r" | jq -r .data.secret_id; \
#   echo "$r" | jq -r .lease_duration'

# -- Nomad ACL auth method / OIDC login (token carries its own expiry) -------
# REFRESH_CMD='nomad login -method=YOUR_METHOD -json | jq -r .SecretID'
# EXPIRY=self

# -- Any script of your own that echoes a token ------------------------------
# REFRESH_CMD='/path/to/get-nomad-token.sh'

REFRESH_CMD=''

# ---------------------------------------------------------------------------
# EXPIRY (optional, default: self)
#
# How to determine the token lifetime when REFRESH_CMD does NOT print a TTL:
#   self        -> query `nomad acl token self` for the token's ExpirationTime
#                  (only works for tokens that have a Nomad-side expiry, such as
#                   ACL auth-method / OIDC logins)
#   <integer>   -> a fixed lifetime in seconds, e.g. 3600 for a 1-hour token
EXPIRY=self

# ---------------------------------------------------------------------------
# NOMAD_ADDR (optional)
#
# Only needed if EXPIRY=self, so the plugin can reach your Nomad API.
# NOMAD_ADDR=https://nomad.example.com
