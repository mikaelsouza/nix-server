# Security decisions — `silmeria`

Reviewed 2026-09-07 and re-triaged 2026-09-08, both against the live host. Nothing is open. The
evidence behind any entry — severities, command output, what was checked — is in git history:
`git log -p -- SECURITY.md`.

## Decided — do not re-raise

- **Password SSH stays on.** The owner moves between machines constantly; a key per machine is more
  friction than the risk warrants. `PermitRootLogin = "no"`, port 22 is not forwarded from the
  internet, and the tailnet is invite-only. Keep that password strong.
- **Comin deploys unsigned commits.** Verifying them would mean giving the auto-update unit its own
  signing key to manage, because it pushes to `main` unattended. Declined — so push access to `main`
  is root on this host, knowingly.
- **No disk encryption.** Home server behind a physical door; retrofitting is reinstall-shaped.
  Physical access yields the comin token, the deploy key and Tailscale state.
- **Agent forwarding is accepted.** No private key is at rest here any more, but code running as
  `mikaels` — the AI agents and package managers this box exists to run — can authenticate as the
  owner for the length of a session.
- **Minecraft runs offline-mode with no whitelist.** Tailnet membership is the access control; see
  the [locked decision](README.md#locked-decision).

## Fixed — do not undo

- **`tailscale0` is not in `firewall.trustedInterfaces`.** Tailnet peers are firewalled like anyone
  else and each service opens its own port. **Known cost, accepted:** peerapi's port is dynamic and
  cannot be allowlisted, so **inbound Taildrop no longer works** — use `scp`.
- **github.com's host key is pinned** and the auto-update unit requires it (`StrictHostKeyChecking=yes`).
  Pinned before that unit ever ran, so no TOFU ever happened.
- **Comin's metrics exporter binds `127.0.0.1`,** not every interface.
- **`minecraft-server` runs with `ProtectSystem=strict` and `NoNewPrivileges`,** writing only to its
  `dataDir`.
- **The deploy key is `/etc/nix-server/deploy-key`,** root-only and repo-scoped — never the personal
  account key.
- **Daily reboot at 06:00** bounds how far the running kernel can lag the deployed generation.
  `Persistent` stays unset, or a host that was down at 06:00 reboots again on its next boot.
  **Known overlap:** the LAN router also reboots around 06:00 and flaps `enp1s0` for ~60s, so the
  host can come up while upstream is briefly down; the static DNS record is what makes that
  survivable. Shift the timer if it ever bites.
- **No private key material lives under `/home/mikaels`.** Keep it that way, and keep
  `authorized_keys` declared in `configuration.nix` rather than written by hand — an unmanaged copy
  silently survives key rotation.

## Operational

Minecraft usernames are unauthenticated by design here, so **any op username is claimable by any
tailnet peer**. Keeping the op list empty is what makes offline-mode cost nothing. That is a habit,
not a config setting.
