# nix-server — agent notes

One host: `silmeria`, a NixOS home server (`x86_64-linux`). `configuration.nix` holds everything;
there are no modules and no `enable` toggles. See `README.md` for the layout, `SECURITY.md` for
recorded security decisions, `HARDWARE.md` for BIOS/ASPM.

- **`main` is live production.** Comin switches the server on every push to `main`. Validate before
  pushing; prefer a branch and a PR.
- **Validate with both:** `nix flake check` and
  `nix build --dry-run .#nixosConfigurations.silmeria.config.system.build.toplevel`
- **Format with `nix fmt`** — nixfmt (RFC 166), never `nixpkgs-fmt`. This flake is Linux-only, so
  from a non-Linux machine use `nix run nixpkgs#nixfmt -- .` instead.
- **Never commit secrets.** They live at `/etc/comin/access_token` and `/etc/nix-server/deploy-key`
  on the host. The Tailscale `authKeyFile` stays unset.
- **Keep `flake.lock` committed and in sync** with `flake.nix` — Comin deploys the committed lock.
- **Do not edit `hardware-configuration.nix`** (generated) or change `system.stateVersion`.
- **Minecraft `online-mode = false` with no whitelist is a locked decision.** Tailnet membership is
  the access control. Do not "harden" it and do not raise it as a finding — see README.
- Before touching SSH, the firewall, or the deploy key, read `SECURITY.md`. Entries under
  "do not re-raise" and "do not undo" are settled decisions, not oversights.
