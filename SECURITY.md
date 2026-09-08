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
| 1 | SSH accepts passwords (`PasswordAuthentication` + `KbdInteractiveAuthentication`) on the LAN and from every tailnet peer | High | **accepted** | **Deliberate — do not "fix" this.** The owner moves between machines constantly; distributing a key to each is more friction than the risk warrants. Compensating controls: `PermitRootLogin = "no"`, port 22 is not forwarded from the internet, and the tailnet is invite-only. Residual risk is a compromised LAN or guest machine brute-forcing `mikaels`, so **keep that password strong**. |
| 2 | `firewall.trustedInterfaces = [ "tailscale0" ]` bypassed the firewall for **every** port, not just 25565 | High | **fixed** | `trustedInterfaces` no longer lists `tailscale0`, so only `lo` is trusted and each service opens its own port: `configuration.nix` sets `firewall.interfaces."tailscale0".allowedTCPPorts = [ 25565 ]` for Minecraft, and SSH rides the global `allowedTCPPorts = [ 22 ]`. Tailnet peers now reach 22/tcp and 25565/tcp only; comin's `*:4243` exporter and anything future that binds a port unexpectedly are closed unless opened explicitly. **A restrictive Tailscale ACL was considered and rejected** — every peer is *meant* to have both SSH and Minecraft. **Known cost, accepted:** tailscaled's peerapi port is dynamic and cannot be allowlisted, so **inbound Taildrop to `silmeria` no longer works** (outbound is fine). Use `scp`. Do not re-add `trustedInterfaces` to restore it. |
| 3 | The auto-update deploy key **used to be the personal account key** (`/home/mikaels/.ssh/id_ed25519`), so the credential that pushes to `main` was readable by anything running as `mikaels` | Med | **fixed** | The `deployKeyFile` binding in `configuration.nix` now points at `/etc/nix-server/deploy-key`, a repo-scoped GitHub deploy key with write access: `0400 root` inside `drwx------ root`, unreachable from user-level code and revocable without touching personal SSH access. **This does not reduce exposure of the personal key**, which is still on the host — see #10; it only removes the *system's* dependency on it. **Limit:** a write-capable deploy key can still push to `main`, and `main` still deploys as root, so "push to `main` = root here" is unchanged — that is #4, not this. Med rather than High because exploitation first requires a supply-chain or agent compromise running as `mikaels`. |
| 4 | Comin deploys **unsigned commits** (`gpg_public_key_paths: []`), so a stolen token or key is root here | Med | _undecided_ | `services.comin.sshAllowedSignersPath`; auto-update's commits must then be signed too |
| 5 | Comin metrics exporter binds all interfaces (`*:4243`) — no longer *reachable* from the tailnet since #2, but the bind address is unchanged, so any future trusted interface or port rule re-exposes it | Med | _undecided_ | `services.comin.exporter.listen_address = "127.0.0.1"` |
| 6 | Running kernel can lag the deployed generation indefinitely (deploys never reboot) | Med | _undecided_ | Choose a reboot policy; `system.autoUpgrade` is **not** an option (see README) |
| 7 | `minecraft-server` unit runs with `ProtectSystem=no`, `NoNewPrivileges=no` | Low | _undecided_ | Add `systemd.services.minecraft-server.serviceConfig` hardening (host-side only) |
| 8 | The auto-update unit in `configuration.nix` uses `StrictHostKeyChecking=accept-new` (TOFU on github.com) | Low | _undecided_ | Pin `programs.ssh.knownHosts`, then require `yes` |
| 9 | No disk encryption; root and swap are plaintext | Low | _undecided_ | Physical access yields the comin token, SSH key, and Tailscale state |
| 10 | The **personal account SSH key** lives on this host (`/home/mikaels/.ssh/id_ed25519`, `0600 mikaels`) and grants push to every repo the account can reach. This box deliberately runs AI coding agents (`claude-code`, `antigravity-cli`) and package managers (`uv`, `npm`, `pip`) **as `mikaels`**, any of which can read it. Not fixed by #3, which only moved the *automation* off it | Med | _undecided_ | If this repo is normally edited from the workstation and deployed via comin, delete the key from `silmeria` and the path closes. If commits are made from the server itself, the key stays and this is a knowingly accepted risk — record which. |

## Verified correct — do not re-flag

- `PermitRootLogin = "no"`.
- The admin SSH key is declared in `configuration.nix`, so a rebuild onto fresh hardware stays reachable.
- Minecraft `openFirewall = false` — 25565 is never opened globally, only on `tailscale0`, so it is
  never reachable on the LAN interface.
- `/etc/comin/access_token` is `0600 root`, and the repo really is private, so the token is not redundant.
- Minecraft offline-mode is a [locked decision](README.md#locked-decision), not a gap.

## Operational note

Minecraft usernames are unauthenticated by design here ([locked decision](README.md#locked-decision)),
so **any op username is claimable by any tailnet peer**. Keeping the op list empty is what makes
offline-mode cost nothing. This is a habit, not a config setting.
