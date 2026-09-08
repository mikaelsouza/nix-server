# Security posture — `silmeria`

This file was README §14 before the repository was flattened; the findings and their
statuses are carried over unchanged.

Reviewed 2026-09-07 against the live `silmeria` host (not just the config). Every item
below carries a **status**, and that status is a recorded decision:

- **fixed** — done in this repo. The Fix column says what was actually changed.
- **accepted** — considered and deliberately left alone. **Do not re-raise it as a finding.**
- **deferred** — real, acknowledged, not scheduled. Leave it alone unless asked.
- **_undecided_** — not yet triaged by the owner. Raise it, do not silently "fix" it.

Severity is impact on this host, not a generic CVSS score.

| # | Finding | Sev | Status | Fix |
| :-- | :--- | :-- | :--- | :--- |
| 1 | SSH accepts passwords (`PasswordAuthentication` + `KbdInteractiveAuthentication`) on the LAN and from every tailnet peer | High | **accepted** | **Deliberate — do not "fix" this.** The owner moves between machines constantly and distributing an SSH key to each one is more friction than the risk warrants. Password login stays. Compensating controls: `PermitRootLogin = "no"`, port 22 is not forwarded from the internet, and the tailnet is invite-only. The residual risk is a compromised LAN device or guest machine brute-forcing `mikaels`, so **keep that password strong**. |
| 2 | `firewall.trustedInterfaces = [ "tailscale0" ]` bypassed the firewall for **every** port, not just 25565 | High | **fixed** | `trustedInterfaces` no longer lists `tailscale0` (`configuration.nix`), so the tailnet is firewalled like any other network and only `lo` stays trusted. Each service opens its own port: `modules/minecraft.nix` sets `firewall.interfaces."tailscale0".allowedTCPPorts = [ 25565 ]`, and SSH stays reachable through the existing global `allowedTCPPorts = [ 22 ]` in `configuration.nix`. Tailnet peers can therefore reach only 22/tcp and 25565/tcp — comin's `*:4243` exporter and everything else are now blocked. **A restrictive Tailscale ACL was considered and rejected:** every tailnet peer is *meant* to have both SSH and Minecraft, so no per-user ACL is wanted. What this change still buys is least-exposure for everything else — comin's `:4243` exporter, and any future service that binds a port without expecting tailnet traffic, are closed unless a module opens them explicitly. **Known cost, accepted:** tailscaled's peerapi port is dynamic and therefore cannot be allowlisted, so **inbound Taildrop to `silmeria` no longer works** (outbound Taildrop *from* the host is unaffected). Use `scp` instead — password SSH is retained by decision #1. Do not re-add `trustedInterfaces` to restore it. |
| 3 | `autoUpdate.deployKeyFile` **used to point at the personal account key** (`/home/mikaels/.ssh/id_ed25519`), so the credential that pushes to `main` was readable by anything running as `mikaels` | Med | **fixed** | The host override was deleted; `deployKeyFile` now resolves to the module default `/etc/nix-server/deploy-key`, a repo-scoped GitHub deploy key with write access. Gains: the push credential is now `0400 root` inside `drwx------ root` `/etc/nix-server`, unreachable from user-level code; the root automation no longer depends on a file owned by a normal user; and the deploy key is revocable on its own without disturbing personal SSH access. **This does not reduce the exposure of the personal key**, which is still at `/home/mikaels/.ssh/id_ed25519` (`0600 mikaels`) and still grants push to every repo the account can reach — see finding #10. What it does is remove the *system's* dependency on that key, which is what makes removing it from this host possible. **Limit, stated honestly:** a write-capable deploy key can still push to `main`, and `main` still auto-deploys as root, so "push access to `main` = root on this host" is unchanged — that is finding #4 (commit signing), not this one. Severity is **Med** rather than High because the blast radius was high but the likelihood on a homelab with no inbound exposure is not: exploitation requires a supply-chain or agent compromise running as `mikaels` first. |
| 4 | Comin deploys **unsigned commits** (`gpg_public_key_paths: []`), so a stolen token or key is root here | Med | _undecided_ | `services.comin.sshAllowedSignersPath`; auto-update's commits must then be signed too |
| 5 | Comin metrics exporter binds all interfaces (`*:4243`) — no longer *reachable* from the tailnet since #2 was fixed, but the bind address itself is unchanged, so any future trusted interface or port rule re-exposes it | Med | _undecided_ | `services.comin.exporter.listen_address = "127.0.0.1"` |
| 6 | Running kernel can lag the deployed generation indefinitely (deploys never reboot) | Med | _undecided_ | Choose a reboot policy; `system.autoUpgrade` is **not** an option (see the README, GitOps and auto-update) |
| 7 | `minecraft-server` unit runs with `ProtectSystem=no`, `NoNewPrivileges=no` | Low | _undecided_ | Add `systemd.services.minecraft-server.serviceConfig` hardening (host-side only) |
| 8 | `modules/auto-update.nix` uses `StrictHostKeyChecking=accept-new` (TOFU on github.com) | Low | _undecided_ | Pin `programs.ssh.knownHosts`, then require `yes` |
| 9 | No disk encryption; root and swap are plaintext | Low | _undecided_ | Physical access yields the comin token, SSH key, and Tailscale state |
| 10 | The **personal account SSH key** lives on this host (`/home/mikaels/.ssh/id_ed25519`, `0600 mikaels`) and grants push to every repo the account can reach. This box deliberately runs AI coding agents (`claude-code`, `antigravity-cli`) and package managers (`uv`, `npm`, `pip`) **as `mikaels`**, any of which can read it. Not fixed by #3 — that only moved the *automation* off it | Med | _undecided_ | If this repo is normally edited from the workstation and deployed via Comin, delete the key from `silmeria` and the path closes. If commits are made from the server itself, the key stays and this is a knowingly accepted risk — record which. |

### Verified correct — do not re-flag

- `PermitRootLogin = "no"` in `configuration.nix`.
- The admin SSH key is declared in `configuration.nix`, so a rebuild onto fresh hardware stays reachable.
- Minecraft `openFirewall = false` — 25565 is never opened globally; it is opened only on `tailscale0` via `firewall.interfaces."tailscale0".allowedTCPPorts`, so it is never reachable on the LAN interface.
- `/etc/comin/access_token` is `0600 root`, and the repo really is private, so the token is not redundant.
- Minecraft offline-mode is a [locked decision](../README.md#locked-decision), not a gap.

### Operational note

Minecraft usernames are unauthenticated by design here ([locked decision](../README.md#locked-decision)), so **any op username is
claimable by any tailnet peer**. Keeping the op list empty is what makes offline-mode
cost nothing. This is a habit, not a config setting.

---
