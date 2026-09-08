# nix-server — agent notes

One host: `silmeria`, a NixOS home server (`x86_64-linux`). `configuration.nix` is
the host; `modules/` holds the three pieces big enough to live on their own. There
are no `enable` toggles — everything imported is active. See `README.md` for the
layout and `docs/security.md` for recorded security decisions.

- **`main` is live production.** Comin polls this repository and switches the
  server on every push to `main`. Validate before pushing; prefer a branch and a PR.
- **Validate with both**, from a Mac or the host:
  `nix flake check` and
  `nix build --dry-run .#nixosConfigurations.silmeria.config.system.build.toplevel`
- **Format with `nix run nixpkgs#nixfmt -- .`** — nixfmt (RFC 166), never
  `nixpkgs-fmt`. This flake is Linux-only and has no `formatter.aarch64-darwin`
  output, so plain `nix fmt` only works on the host.
- **Never commit secrets.** They live at `/etc/comin/access_token` and
  `/etc/nix-server/deploy-key` on the host. The Tailscale `authKeyFile` stays unset.
- **Keep `flake.lock` committed and in sync** with `flake.nix` — Comin deploys the
  committed lock.
- **Do not edit `hardware-configuration.nix`** (generated) or change
  `system.stateVersion`.
- **Minecraft `online-mode = false` with no whitelist is a locked decision.**
  Tailnet membership is the access control. Do not "harden" it and do not raise it
  as a finding — see README, "Locked decision".
- Before touching SSH, the firewall, or the deploy key, read `docs/security.md`:
  several findings there are marked **accepted** and must not be re-raised.
