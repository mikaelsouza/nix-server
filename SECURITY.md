# Security posture — `silmeria`

Reviewed 2026-09-07 and re-triaged 2026-09-08, both against the live host rather than the config. Every item carries a **status**, and
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
| 4 | Comin deploys **unsigned commits**, so a stolen token or key is root here | Med | **accepted** | Considered and declined by the owner (2026-09-08). State of the world if it is ever revisited: `gpgPublicKeyPaths = [ ]` and `sshAllowedSignersPath = null`, so nothing is verified, and "push access to `main` = root on this host" holds. The cost that made it not worth it is that the auto-update unit pushes its own commits, so enabling verification means giving that unit a signing key and managing it. **Do not re-raise as a finding.** |
| 5 | Comin metrics exporter bound all interfaces (`*:4243`) | Med | **fixed** | `services.comin.exporter.listen_address = "127.0.0.1"` in `configuration.nix`. Verified: `ss -lntp` now shows `127.0.0.1:4243`, and the generated `comin.yaml` carries `listen_address: 127.0.0.1`. It was never reachable off-host — the firewall blocked it — but the wildcard bind meant any future port rule or trusted interface would have silently republished it. |
| 6 | Deploys never reboot, so a running kernel can lag the deployed generation indefinitely | Med | **fixed** | `systemd.timers.scheduled-reboot` reboots daily at `*-*-* 06:00:00`, which `systemd-analyze calendar` confirms resolves to 06:00 `-03` under `time.timeZone = "America/Sao_Paulo"`. `Persistent` is deliberately left unset: with it on, a machine that was down at 06:00 would reboot again immediately on its next boot. **Known overlap:** the LAN router also reboots around 06:00 and flaps `enp1s0` for ~60s (see the DNS comment in `configuration.nix`), so the host may come up while upstream is briefly down. Static DNS is what makes that survivable; shift the timer if it ever bites. |
| 7 | `minecraft-server` ran with `ProtectSystem=no`, `NoNewPrivileges=no` | Low | **fixed** | `systemd.services.minecraft-server.serviceConfig` now sets `ProtectSystem = "strict"`, `NoNewPrivileges = true`, and `ReadWritePaths = [ config.services.minecraft-server.dataDir ]` — bound to the option so it tracks. Verified live: unit active, `Result=success`, `NRestarts=0`, world loaded with no permission denials, `systemd-analyze security` 3.0 → 2.7. The nixpkgs module already supplied the rest (`User=minecraft`, `PrivateDevices`, `PrivateUsers`, `ProtectHome`, `ProtectProc=invisible`, `RestrictSUIDSGID`, empty `CapabilityBoundingSet`). |
| 8 | The auto-update unit used `StrictHostKeyChecking=accept-new` (TOFU on github.com) | Low | **fixed** | `programs.ssh.knownHosts."github.com"` pins the ed25519 host key and the unit now requires `StrictHostKeyChecking=yes`. The pin was cross-checked against three sources that agree exactly: `https://api.github.com/meta` over HTTPS, a live `ssh-keyscan`, and the existing workstation `known_hosts`. Landed **before** the unit's first ever run, so no TOFU ever happened. Verified: an ssh to github.com with `StrictHostKeyChecking=yes` and `UserKnownHostsFile=/dev/null` passes host verification (failing only at `publickey`, as expected). |
| 9 | No disk encryption; root and swap are plaintext | Low | **accepted** | Confirmed: `sda2` ext4 and `sda3` swap, no LUKS anywhere. Physical access yields the comin token, the deploy key, and Tailscale state. Declined by the owner (2026-09-08) — this is a home server behind a physical door, and retrofitting encryption is reinstall-shaped. **Do not re-raise as a finding.** |
| 10 | The personal account SSH key is exposed to everything running as `mikaels` — this box deliberately runs AI coding agents (`claude-code`, `antigravity-cli`) and package managers (`uv`, `npm`, `pip`) as that user | Low–Med | **accepted** | **Premise changed — the key is no longer at rest here.** `/home/mikaels/.ssh/` contains no private key; what remains is **agent forwarding** (`~/.ssh/agent/` holds live sshd-forwarded sockets, `ssh-add -l` returns `mikaelsouza@hrist.local`). So code running as `mikaels` can still *authenticate as you* to anything that key opens, but can no longer *steal* the key — the exposure is bounded to the length of your session. **Accepted by the owner (2026-09-08)** — that bound is worth the convenience of agent forwarding. **Do not re-raise as a finding.** |
| 11 | `~/.ssh/authorized_keys` was an unmanaged duplicate of the declared key, invisible to the config | Low | **fixed** | Deleted. sshd consults `%h/.ssh/authorized_keys` *and* `/etc/ssh/authorized_keys.d/%u`; the NixOS-managed copy held byte-identical key material (same md5 over the key blob), so nothing changed about what is authorised — but rotating the key in `configuration.nix` now actually revokes access, which it would not have before. |
| 12 | `/home/mikaels/dev_ssh/dev_ed25519_key` is a passphrase-less private key readable by anything running as `mikaels` | Low | **fixed** | Deleted on 2026-09-08, directory and all. It was an sshd **host** key for a port-2222 dev sshd (`dev_ssh/sshd_config`) that is not running, whose `PidFile` points at a `container_ssh/` directory that does not exist. It was authorised nowhere, nothing referenced it, and nothing listened on 2222. `/home/mikaels/` now contains no private key material at all. |

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

**The auto-update loop is verified end to end.** Its first run on 2026-09-07 22:11 used the deploy
key, passed the newly pinned github.com host key, built, and pushed `07d26b3 flake.lock: Update`
(bumping `nixpkgs-unstable`), which comin then deployed. Subsequent runs correctly report
"already current; nothing to push". Note what that proves about #4: this host pushes to `main` on
its own, and `main` deploys as root.

```bash
systemctl status nix-server-auto-update    # or: journalctl -u nix-server-auto-update
```
