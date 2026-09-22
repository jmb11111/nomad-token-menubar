# nomad-token-menubar

A tiny macOS menu bar indicator for your **Nomad ACL token**: shows at a glance
whether you have a valid token and how long it has left, with one click to
refresh and one to copy it to your clipboard.

<!-- Replace with a real screenshot once you have one -->
> 🟢 `42m` when valid · 🔴 `exp` when expired · dropdown: exact time left, **Copy token**, **Refresh token**

Built on [SwiftBar](https://github.com/swiftbar/SwiftBar). It does **not** care how
you mint tokens — you tell it the command you already use (Vault, an ACL auth
method / OIDC login, or any script that prints a token), and it handles the
countdown, copy, and refresh.

## Who this is for

You run Nomad with ACLs enabled and use **short-lived / expiring** human tokens —
e.g. tokens from the Vault Nomad secrets engine, or from a `nomad login` ACL auth
method. If your token never expires, you don't need this.

This README assumes you already know how you get a token; you just need to drop
that command into the config.

## Requirements

- macOS
- [Homebrew](https://brew.sh) (the installer uses it to install SwiftBar + jq)
- The Nomad CLI — only if you use `EXPIRY=self` (see below)

## Install

```sh
git clone https://github.com/jmb11111/nomad-token-menubar.git
cd nomad-token-menubar
./install.sh
```

The installer will:

- install **SwiftBar** and **jq** via Homebrew if missing,
- copy the plugin + assets into `~/.nomad-token-menubar/`,
- point SwiftBar at the plugin (respecting an existing plugin folder if you
  already use SwiftBar),
- launch an **interactive setup wizard** to configure it (see below).

Re-run `./install.sh` any time to update; your `config.sh` is left untouched.

## macOS permissions & first launch

SwiftBar is a menu bar app, so macOS applies its usual guardrails. The installer
smooths the main one for you (it removes the Gatekeeper quarantine flag), but on
a fresh machine you may still see:

- **"SwiftBar can't be opened / is from an unidentified developer."** Open
  **System Settings → Privacy & Security** and click **Open Anyway**, then launch
  SwiftBar again.
- **A Plugin Folder prompt** on first launch. If asked, choose
  `~/.swiftbar-plugins` (the installer already points SwiftBar there).
- **"SwiftBar wants to control Terminal."** This appears the first time you use
  **Run setup…** (it opens a terminal for the wizard). Click **Allow** — it's
  needed only for that button, not for the indicator itself.
- **No icon in the menu bar?** The bar may be full — widen it or quit another
  menu bar app and SwiftBar's icon will show.

To keep it running after a reboot: SwiftBar menu → **Preferences → Launch at
Login**.

## Configure (interactive)

The installer runs the wizard automatically. You can also run it any time from
the menu bar (**Run setup…**) or directly:

```sh
~/.nomad-token-menubar/nomad-token-menubar.sh setup
```

It asks how you fetch a token — **Vault secrets engine**, **Nomad ACL auth
method / OIDC**, or a **custom command** — prompts only for the values that
choice needs, **tests the command**, writes `config.sh` for you, and offers to
fetch the first token. No hand-editing required.

### Configure manually (optional)

If you'd rather edit by hand, set **`REFRESH_CMD`** in
`~/.nomad-token-menubar/config.sh` — a command that prints a fresh token to
stdout on line 1 (and, optionally, its lifetime in seconds on line 2). See
`config.example.sh` for annotated examples (Vault / auth method / custom).

### How the lifetime is determined

1. If `REFRESH_CMD` prints a number on line 2, that's the TTL (seconds). Simplest and exact.
2. Otherwise `EXPIRY` decides:
   - a plain integer → fixed TTL in seconds (e.g. `3600`),
   - `self` → query `nomad acl token self` for the token's `ExpirationTime`
     (works for tokens that carry a Nomad-side expiry, such as ACL
     auth-method / OIDC logins; Vault-minted tokens often don't, so prefer
     option 1 or a fixed integer for those).

## Use

Click the menu bar icon:

- **Refresh token** — runs your `REFRESH_CMD`, updates the indicator (headless, no window).
- **Copy token to clipboard** — copies the current token so you can paste it into a login/auth prompt.
- **Edit config…** — opens `config.sh`.
- **Run setup…** — re-runs the interactive wizard.

The indicator refreshes every 30s; the menu bar shows whole minutes (`42m`,
`<1m`, `exp`) and the dropdown shows the exact time and timestamps.

## Optional: export into your shell

The menu bar and Copy button cover most needs. If you also want a shell helper
that refreshes **and** sets `NOMAD_TOKEN` in your current shell, source the
snippet:

```sh
echo 'source /path/to/nomad-token-menubar/shell/nomad-token-menubar.sh' >> ~/.zshrc
```

Then `nt` refreshes + exports, or `nt-export` loads the cached token.

## Where things live

```
~/.nomad-token-menubar/
├── config.sh                  # your settings (git-ignored; never commit)
├── nomad-token-menubar.sh     # installed copy of the installer; `… setup` re-runs the wizard
├── state                      # "<fetched_epoch> <ttl_seconds>"  (no secret)
├── token                # the raw token, chmod 600
├── lib/refresh.sh       # fetch + record + redraw
└── assets/              # logo PNGs
<SwiftBar plugin dir>/nomad-token.30s.sh
```

## Security notes

- The token is cached at `~/.nomad-token-menubar/token`, written owner-only
  (`chmod 600`), so the Copy button and shell helper can read it. This is
  comparable to `~/.vault-token`. If you'd rather not cache it on disk, don't
  use the Copy button / shell helper — remove the token file and the indicator
  still works from `state` alone.
- `config.sh`, `state`, and `token` are git-ignored. Never commit them.

## Uninstall

```sh
./uninstall.sh
```

Removes the plugin and (on confirmation) `~/.nomad-token-menubar/`. Leaves
SwiftBar and jq installed.

## Notes / credits

- "Nomad" and the Nomad logo are trademarks of their respective owner and are
  used here only to identify the Nomad product this tool integrates with. This
  project is independent and not affiliated with or endorsed by HashiCorp/IBM.
- Nomad logo mark sourced from [Simple Icons](https://simpleicons.org).

## License

MIT — see [LICENSE](LICENSE).
