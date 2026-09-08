# Security posture — `silmeria`

Reviewed 2026-09-07 against the live host, not just the config. Every item carries a **status**, and
that status is a recorded decision:

- **fixed** — done in this repo. The Fix column says what changed.
- **accepted** — considered and deliberately left alone. **Do not re-raise it as a finding.**
- **deferred** — real, acknowledged, not scheduled. Leave it alone unless asked.
- **_undecided_** — not yet triaged by the owner. Raise it; do not silently "fix" it.

Severity is impact on this host, not a generic CVSS score.

| # | Finding | Sev | Status | Fix |
| :-- | :--- | :-- | :--- | :--- |
| 1 | SSH accepts passwords (`PasswordAuthentication` + `KbdInteractiveAuthentication`) on the LAN and from every tailnet peer | High | **accepted** | **Deliberate — do not "fix" this.** The owner moves between machines constantly; distributing a key to each is more friction than the risk warrants. Confirmed to be the live path: every `Accepted` line in the sshd journal is `keyboard-interactive/pam`, none are `publickey`. Compensating controls: `PermitRootLogin = "no"`, port 22 is not forwarded from the internet, and the tailnet is invite-only. Residual risk is a compromised LAN or guest machine brute-forcing `mikaels`, so **keep that password strong**. |
| 2 | `firewall.trustedInterfaces = [ "tailscale0" ]` bypassed the firewall for **every** port, not just 25565 | High | **fixed** | `trustedInterfaces` no longer lists `tailscale0`, so only `lo` is trusted and each service opens its own port: `configuration.nix` sets `firewall.interfaces."tailscale0".allowedTCPPorts = [ 25565 ]` for Minecraft, and SSH rides the global `allowedTCPPorts = [ 22 ]`. **A restrictive Tailscale ACL was considered and rejected** — every peer is *meant* to have both SSH and Minecraft. **Known cost, accepted:** tailscaled's peerapi port is dynamic and cannot be allowlisted, so **inbound Taildrop to `silmeria` no longer works** (outbound is fine). Use `scp`. Do not re-add `trustedInterfaces` to restore it. |
| 3 | The auto-update deploy key **used to be the personal account key** (`/home/mikaels/.ssh/id_ed25519`), so the credential that pushes to `main` was readable by anything running as `mikaels` | Med | **fixed** | The `deployKeyFile` binding in `configuration.nix` now points at `/etc/nix-server/deploy-key`, a repo-scoped GitHub deploy key with write access, in a `drwx------ root` directory unreachable from user-level code and revocable without touching personal SSH access. **Limit:** a write-capable deploy key can still push to `main`, and `main` still deploys as root, so "push to `main` = root here" is unchanged — that is #4, not this. |
| 4 | Comin deploys **unsigned commits**, so a stolen token or key is root here | Med | _undecided_ | Confirmed on the evaluated config: `gpgPublicKeyPaths = [ ]` and `sshAllowedSignersPath = null`. Fix is `services.comin.sshAllowedSignersPath`; the auto-update unit's own commits must then be signed too, which is the part that needs a decision. |
| 5 | Comin metrics exporter bound all interfaces (`*:4243`) | Med | **fixed** | `services.comin.exporter.listen_address = "127.0.0.1"` in `configuration.nix`. Verified: `ss -lntp` now shows `127.0.0.1:4243`, and the generated `comin.yaml` carries `listen_address: 127.0.0.1`. It was never reachable off-host — the firewall blocked it — but the wildcard bind meant any future port rule or trusted interface would have silently republished it. |
| 6 | Deploys never reboot, so a running kernel can lag the deployed generation indefinitely | Med | _undecided_ | A policy gap, not a live condition: as of this review `/run/booted-system` and `/run/current-system` are the same store path and both use `linux-6.18.49`. Needs a reboot policy. `system.autoUpgrade` is **not** an option (see README). |
| 7 | `minecraft-server` ran with `ProtectSystem=no`, `NoNewPrivileges=no` | Low | **fixed** | `systemd.services.minecraft-server.serviceConfig` now sets `ProtectSystem = "strict"`, `NoNewPrivileges = true`, and `ReadWritePaths = [ config.services.minecraft-server.dataDir ]` — bound to the option so it tracks. Verified live: unit active, `Result=success`, `NRestarts=0`, world loaded with no permission denials, `systemd-analyze security` 3.0 → 2.7. The nixpkgs module already supplied the rest (`User=minecraft`, `PrivateDevices`, `PrivateUsers`, `ProtectHome`, `ProtectProc=invisible`, `RestrictSUIDSGID`, empty `CapabilityBoundingSet`). |
| 8 | The auto-update unit used `StrictHostKeyChecking=accept-new` (TOFU on github.com) | Low | **fixed** | `programs.ssh.knownHosts."github.com"` pins the ed25519 host key and the unit now requires `StrictHostKeyChecking=yes`. The pin was cross-checked against three sources that agree exactly: `https://api.github.com/meta` over HTTPS, a live `ssh-keyscan`, and the existing workstation `known_hosts`. Landed **before** the unit's first ever run, so no TOFU ever happened. Verified: an ssh to github.com with `StrictHostKeyChecking=yes` and `UserKnownHostsFile=/dev/null` passes host verification (failing only at `publickey`, as expected). |
| 9 | No disk encryption; root and swap are plaintext | Low | _undecided_ | Confirmed: `sda2` ext4 and `sda3` swap, no LUKS anywhere. Physical access yields the comin token, the deploy key, and Tailscale state. |
| 10 | The personal account SSH key is exposed to everything running as `mikaels` — this box deliberately runs AI coding agents (`claude-code`, `antigravity-cli`) and package managers (`uv`, `npm`, `pip`) as that user | Low–Med | _undecided_ | **Premise changed — the key is no longer at rest here.** `/home/mikaels/.ssh/` contains no private key; what remains is **agent forwarding** (`~/.ssh/agent/` holds live sshd-forwarded sockets, `ssh-add -l` returns `mikaelsouza@hrist.local`). So code running as `mikaels` can still *authenticate as you* to anything that key opens, but can no longer *steal* the key — the exposure is bounded to the length of your session. Decide whether that is acceptable, or drop `ForwardAgent` for this host. |
| 11 | `~/.ssh/authorized_keys` was an unmanaged duplicate of the declared key, invisible to the config | Low | **fixed** | Deleted. sshd consults `%h/.ssh/authorized_keys` *and* `/etc/ssh/authorized_keys.d/%u`; the NixOS-managed copy held byte-identical key material (same md5 over the key blob), so nothing changed about what is authorised — but rotating the key in `configuration.nix` now actually revokes access, which it would not have before. |
| 12 | `/home/mikaels/dev_ssh/dev_ed25519_key` is a passphrase-less private key readable by anything running as `mikaels` | Low | _undecided_ | It is an sshd **host** key for a port-2222 dev sshd (`dev_ssh/sshd_config`) that is not running, whose `PidFile` points at a `container_ssh/` directory that does not exist. Not authorised anywhere — it appears in neither `authorized_keys` file. Almost certainly deletable leftover; confirm before removing. |

## Verified correct — do not re-flag

- `PermitRootLogin = "no"`.
- The admin SSH key is declared in `configuration.nix`, so a rebuild onto fresh hardware stays
  reachable. It is insurance, not the daily path — logins use passwords by decision #1.
- Minecraft `openFirewall = false` — 25565 is never opened globally, only on `tailscale0`, so it is
  never reachable on the LAN interface.
- `/etc/comin/access_token` is `0600 root`, and the repo really is private, so the token is not redundant.
- Minecraft offline-mode is a [locked decision](README.md#locked-decision), not a gap.

## Operational note

Minecraft usernames are unauthenticated by design here ([locked decision](README.md#locked-decision)),
so **any op username is claimable by any tailnet peer**. Keeping the op list empty is what makes
offline-mode cost nothing. This is a habit, not a config setting.

**The auto-update timer had never run as of this review** — no journal entries, and
`/var/lib/nix-server-auto-update` did not exist. Its first execution exercises the deploy key and a
`git push origin main` that auto-deploys as root, so watch the first run rather than letting it go
unattended:

```bash
sudo systemctl start nix-server-auto-update
journalctl -u nix-server-auto-update -f
```
