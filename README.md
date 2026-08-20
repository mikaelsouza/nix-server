# nix-server

[![Nixpkgs](https://img.shields.io/badge/Nixpkgs-26.05%20Stable-5277C3?logo=nixos&logoColor=white)](https://github.com/NixOS/nixpkgs/tree/nixpkgs-26.05-darwin)
[![nix-darwin](https://img.shields.io/badge/nix--darwin-26.05-black?logo=apple&logoColor=white)](https://github.com/nix-darwin/nix-darwin/tree/nix-darwin-26.05)
[![GitOps](https://img.shields.io/badge/GitOps-Comin-blueviolet)](https://github.com/nlewo/comin)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

This README is the **single source of truth** for building, operating, modifying, and validating this flake, for humans and AI agents alike. It replaces the former `guidelines.md` (merged and deleted; the section mapping is in the commit that did the merge). The only exempt manuals are the hardware references under `docs/`.

---

## 0 Read First

- **`main` is live production.** `silmeria` runs [Comin](https://github.com/nlewo/comin), which polls this repository and automatically builds + switches its system on every push to `main`. A broken evaluation on `main` can take down a working server (Comin fails safe and keeps the previous generation, but still). **Validate before you push, never push unverified work.**
- **Two platforms are managed from one flake:** `hrist` (`aarch64-darwin`, macOS) and `silmeria` (`x86_64-linux`, NixOS). A change that compiles for one host may break the other. Always validate **both** hosts.
- **Channel policy: exactly 5 direct inputs** — `nixpkgs`, `nixpkgs-unstable`, `nix-darwin`, `nix-homebrew`, `comin`. Everything is pinned to `nixpkgs-26.05` (stable). `nixpkgs-unstable` is a separate input consumed only via `specialArgs` as `pkgs-unstable` — it is **not** applied as an overlay and must not leak into the stable package set.
- **No secrets are stored in this repository.** Secrets live in host-local paths (e.g. `/etc/comin/access_token`, `/var/lib/tailscale/authkey`). Never commit tokens, keys, or credentials.
- **`scripts/verify-docs.sh`** machine-checks this file against the repo (see §7). Keep the tree in §2 and the host table in §1 in sync when layout or hosts change.

> Agents: this file's headings are stable anchors. Read §0 and the §13 Agent Checklist before every change, then only the sections your task needs (matrix below).

### Task-to-section matrix

| Task | Read |
| :--- | :--- |
| Adding a cask / brew (hrist) | §1 + §6 |
| Adding a NixOS service | §3 + §7 |
| Adding a host | §3 (Adding a Host) + §7 |
| Adding a hardware/BIOS guide | §4 + §7 |
| Docs-only change | §11 |
| Updating flake inputs | §6 + §7 |
| Touching modules/common | §0 + §7 |

## Table of Contents

- [0 Read First](#0-read-first)
- [1 Managed Hosts](#1-managed-hosts)
- [2 Architecture and Modular Layout](#2-architecture-and-modular-layout)
- [3 Module Authoring Conventions](#3-module-authoring-conventions)
- [4 Hardware and BIOS Guides](#4-hardware-and-bios-guides)
- [5 Bootstrap](#5-bootstrap)
- [6 Usage and Operations](#6-usage-and-operations)
- [7 Validation Workflow](#7-validation-workflow)
- [8 GitOps and Comin](#8-gitops-and-comin)
- [9 Code Style and Formatting](#9-code-style-and-formatting)
- [10 Hygiene Secrets and Footguns](#10-hygiene-secrets-and-footguns)
- [11 Commit Convention](#11-commit-convention)
- [12 Branching and PR Workflow](#12-branching-and-pr-workflow)
- [13 Agent Checklist](#13-agent-checklist)
- [14 References](#14-references)

---

## 1 Managed Hosts

| Host | OS & Platform | Architecture | Role | Key Modules & Services |
| :--- | :--- | :--- | :--- | :--- |
| **`hrist`** | macOS (nix-darwin 26.05, stateVersion 5) | `aarch64-darwin` | Personal Workstation | `nix-darwin`, `nix-homebrew` (OrbStack, Chrome, Tailscale, etc.), Zsh direnv hook |
| **`silmeria`** | NixOS 26.05 (stateVersion 25.11) | `x86_64-linux` | Home Server | Comin GitOps (Private Repo Auth), OpenSSH, Tailscale VPN, Antigravity CLI (`agy`), Minecraft Server, Omada Controller, Podman Containers |

---

## 2 Architecture and Modular Layout

The repository is organized into a clean **3-Tier Structure**:
1. **`hosts/`**: Minimal, machine-specific entrypoints (hardware config, hostnames, module activations).
2. **`modules/`**: Reusable configuration layers divided into `common/` (cross-platform), `darwin/` (macOS-only), and `nixos/` (Linux-only).
3. **`flake.nix`**: Lightweight root orchestrator declaring the **5 direct inputs** (`nixpkgs`, `nixpkgs-unstable`, `nix-darwin`, `nix-homebrew`, `comin`), mapping hosts, and passing `pkgs-unstable` via `specialArgs`. `flake.nix` is authoritative — update this list here if inputs change.

```text
nix-server/
├── .gitignore                         # ignored local artifacts (build outputs, agent tooling, macOS cruft)
├── LICENSE                            # MIT license
├── README.md                          # SINGLE SOURCE OF TRUTH (this file)
├── AGENTS.md                          # loader for AI agents -> README
├── flake.nix                          # Minimal root entrypoint (inputs, specialArgs & host mappings)
├── flake.lock                         # Pinned dependencies - keep committed, keep in sync
├── docs/                              # Hardware & BIOS guides (only exempt manuals)
│   ├── bios-setup-guide.md            # Dell OptiPlex 3000 BIOS settings (C-States, ASPM)
│   └── realtek-power-management.md    # r8169 / PCIe ASPM root-cause & tuning
├── scripts/
│   └── verify-docs.sh                 # Drift guards: tree vs find, 5 inputs, TOC anchors
├── hosts/
│   ├── hrist/                         # macOS Workstation (aarch64-darwin)
│   │   └── default.nix                # Imports modules/common & modules/darwin, sets hostname/stateVersion
│   └── silmeria/                      # NixOS Server (x86_64-linux)
│       ├── default.nix                # Imports modules/common & modules/nixos (+ hardware-configuration.nix), sets hostname/stateVersion, enables my.* toggles
│       └── hardware-configuration.nix # GENERATED by nixos-generate-config - DO NOT EDIT
└── modules/
    ├── common/                        # Shared cross-platform layer (Linux & macOS)
    │   ├── default.nix                # Aggregates common modules
    │   ├── nix.nix                    # allowUnfree (flakes live in modules/nixos/core/system.nix)
    │   ├── packages.nix               # Shared CLI tools (git, neovim, nil, nixd, direnv, uv)
    │   └── shell.nix                  # Zsh configuration and direnv interactive hook
    ├── darwin/                        # macOS-specific layer
    │   ├── default.nix                # Aggregates darwin modules
    │   ├── homebrew.nix               # Homebrew taps, brews, and GUI casks
    │   ├── system.nix                 # macOS daemon settings (nix.enable = false)
    │   └── users.nix                  # macOS primaryUser definition
    └── nixos/                         # NixOS-specific layer
        ├── default.nix                # Aggregates core and services
        ├── core/
        │   ├── system.nix             # System locales, timezones, flakes, and core tools (antigravity-cli)
        │   └── users.nix              # Linux user account (mikaels) and extra groups
        └── services/
            ├── comin.nix              # GitOps deployment service (private repo token support; wired via comin.nixosModules.comin)
            ├── minecraft.nix          # Declarative PaperMC Minecraft server
            ├── omada.nix              # TP-Link Omada Controller (Podman container)
            ├── openssh.nix            # SSH daemon configuration & firewall rules
            ├── tailscale.nix          # Mesh VPN configuration
            └── virtualization.nix     # Podman container runtime & Distrobox
```

Module separation strategy:

```mermaid
graph TD
    subgraph Hosts
        H1[hosts/hrist]
        H2[hosts/silmeria]
    end

    subgraph Modules
        MC[modules/common<br/>Git & Neovim<br/>Direnv & Zsh Hook<br/>allowUnfree = true]
        MD[modules/darwin<br/>Homebrew & Casks<br/>nix-homebrew<br/>primaryUser]
        MN[modules/nixos<br/>Systemd Services<br/>Linux Users & Groups<br/>Core System Settings]
    end

    H1 --> MC
    H1 --> MD
    H2 --> MC
    H2 --> MN
```

* **Shared (`modules/common/`)**: Developer tools (`neovim`, `git`, `nil`, `nixd`, `direnv`, `uv`) and `allowUnfree = true`. Flakes (`nix-command`, `flakes`) are enabled only on NixOS via `modules/nixos/core/system.nix`; macOS inherits them from the Determinate installer.
* **macOS (`modules/darwin/`)**: GUI applications managed via Homebrew (Chrome, Obsidian, OrbStack, Discord, Tailscale, etc.), `nix-homebrew` integration (`enableRosetta = true`), and Determinate daemon compatibility (`nix.enable = false`).
* **NixOS (`modules/nixos/`)**: Systemd services (`comin` with optional private repo access token, `openssh`, `minecraft`, `omada`, `tailscale`, `virtualization`), Linux account `mikaels` in `wheel`, `networkmanager`, `podman`, `antigravity-cli` (sourced explicitly via `pkgs-unstable` `specialArgs`), and in-tree `r8169` / PCIe ASPM power management overrides.

### Rules of Placement

| Concern | Goes in |
| :--- | :--- |
| Machine-specific (hostname, hardware, host-only tweaks) | `hosts/<host>/` |
| Works on macOS **and** Linux | `modules/common/` |
| macOS-only | `modules/darwin/` |
| Linux-only | `modules/nixos/` |
| A new NixOS service | `modules/nixos/services/<name>.nix` |

- Every layer directory has a `default.nix` that lists its children via `imports = [ ... ];`. When you add a module, **register it in the parent `default.nix`**.
- Keep hosts thin: hosts enable features, they do not re-implement them. `hosts/silmeria/default.nix` is the model — it only imports `hardware-configuration.nix`, the two module layers, sets hostname/boot/hardware specifics, and flips `my.*.enable = true;` toggles.
- `hardware-configuration.nix` is machine-generated. Make changes in the host `default.nix`, not there.

---

## 3 Module Authoring Conventions

NixOS service modules follow the **`my.*` options pattern** used throughout `modules/nixos/`:

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.my.services.<name>;
in
{
  options.my.services.<name> = {
    enable = lib.mkEnableOption "human-readable description";
  };

  config = lib.mkIf cfg.enable {
    # implementation here
  };
}
```

- Expose an `enable` option via `lib.mkEnableOption` and guard all `config` with `lib.mkIf cfg.enable`.
- Use `options.my.core.*` for core/system concerns and `options.my.services.*` for deployable services (see `core/system.nix`, `services/comin.nix`).
- Enable the feature from the host with `my.services.<name>.enable = true;` — never import it and assume it activates.
- When a module needs a package that only exists in unstable, take `pkgs-unstable` as a function argument (it is passed via `specialArgs` for every host; see `flake.nix`) and reference `pkgs-unstable.<pkg>`. See `core/system.nix`.
- Use `lib.mkDefault` for sane defaults so hosts can override; use plain assignment when the value is the deliberate default.

### Adding a NixOS Service

1. Create `modules/nixos/services/<name>.nix` following the pattern above.
2. Register it in `modules/nixos/default.nix` (imports).
3. Flip `my.services.<name>.enable = true;` in `hosts/silmeria/default.nix`.
4. Dry-run both hosts (§7) and run `nix fmt`.

### Adding a Host

To add a new machine to this repository:

1. Create a directory under `hosts/<hostname>/` with a `default.nix` importing `../../modules/common` and either `../../modules/darwin` or `../../modules/nixos`.
2. Add the host entry to `flake.nix` under `darwinConfigurations` or `nixosConfigurations`, passing `pkgs-unstable` via `specialArgs`. A new darwin host must also be wired to the `nix-homebrew.darwinModules.nix-homebrew` module; a new NixOS host needs its own `hardware-configuration.nix` imported.
3. Set `networking.hostName` and the correct `system.stateVersion`.
4. Validate both hosts (§7) and update this file (§1 host table + §2 tree).

---

## 4 Hardware and BIOS Guides

* **[Dell OptiPlex 3000 BIOS Setup Guide](docs/bios-setup-guide.md)**: Step-by-step instructions for configuring C-States, ASPM, and power options.
* **[Realtek RTL8168/8111 Network Stability & C-State Power Management](docs/realtek-power-management.md)**: In-depth root-cause analysis of PCIe AER error loops and ASPM tuning on `silmeria`.

These are the only exempt manuals; all other documentation lives in this file.

---

## 5 Bootstrap

Set up a fresh Mac (`hrist`) from scratch:

### Install Nix (Determinate Installer)

This repo expects the **Determinate Nix installer** daemon — the darwin config disables nix-darwin's own Nix service (`nix.enable = false`, see §2) to avoid clashing with it:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Then restart your shell so `nix` is on `PATH`.

### Clone the Repository

```bash
git clone git@github.com:mikaelsouza/nix-server.git
cd nix-server
```

### Build and Activate the Configuration

`darwin-rebuild` isn't on `PATH` yet, so build the system and invoke `darwin-rebuild` from the result:

```bash
nix build .#darwinConfigurations.hrist.system
./result/sw/bin/darwin-rebuild switch --flake .#hrist
```

This evaluates the flake, builds the system closure, and switches. Homebrew and all declared casks are installed automatically during activation.

### Verify

```bash
darwin-rebuild --version          # should now resolve on PATH
which zsh && direnv --version     # common modules applied
[ -d "/Applications/Tailscale.app" ] && echo "Casks installed" # tailscale-app cask bundle present
```

Once bootstrapped, subsequent updates only need the normal switch command below.

---

## 6 Usage and Operations

### Applying Configuration Live (switch)

* **On macOS (`hrist`):**
  ```bash
  darwin-rebuild switch --flake .#hrist
  ```

* **On NixOS Server (`silmeria`):**
  ```bash
  sudo nixos-rebuild switch --flake .#silmeria
  ```

### Updating Flake Dependencies

There are **5 direct inputs**: `nixpkgs` (pinned to the `nixpkgs-26.05-darwin` track — note this stable-darwin channel also builds the x86_64-linux `silmeria`, intentionally), `nixpkgs-unstable`, `nix-darwin`, `nix-homebrew`, `comin`. To update them:

```bash
nix flake update
```

Then re-run the §7 validation (updates can change behavior). Note `flake.lock` contains more nodes than these 5 — the rest are transitive/aliased inputs (e.g. `brew-src`, `flake-compat`, `treefmt-nix`, `nixpkgs_2`); the "5 direct inputs" count refers to what `flake.nix` declares.

---

## 7 Validation Workflow

Run these locally and confirm **both** hosts evaluate before committing/pushing:

```bash
# Drift guards: README tree vs find, 5 direct inputs, TOC anchors
scripts/verify-docs.sh

# Format check (nixfmt, RFC 166)
nix fmt -- --check .

# macOS workstation (hrist)
nix build .#darwinConfigurations.hrist.system --dry-run

# NixOS server (silmeria)
nix build .#nixosConfigurations.silmeria.config.system.build.toplevel --dry-run

# Structural checks
nix flake check
```

> `nix flake check` run on macOS only validates the `aarch64-darwin` outputs (i.e. `hrist`), so `silmeria` (`x86_64-linux`) must still be validated with the explicit dry-run build: `nix build .#nixosConfigurations.silmeria.config.system.build.toplevel --dry-run`.

If you changed flake inputs, run `nix flake update` (see §6) and re-run the dry-runs. If a change only affects one host, you still must confirm the other host still evaluates (single-flake, shared `modules/common`).

> Because Comin auto-deploys `main`, prefer **validation before push** over "commit, push, and see". When possible, develop on a feature branch and merge via PR (see §12).

> The §2 layout tree is machine-checked by `scripts/verify-docs.sh`: any `.nix` added, removed, or renamed under `hosts/` or `modules/` must be reflected in the tree or the validation gate fails. The tree must remain the first `text`-fenced block in the README.

---

## 8 GitOps and Comin

The `silmeria` NixOS server runs **[Comin](https://github.com/nlewo/comin)** in the background:
1. When changes are committed and pushed to the `main` branch on GitHub, Comin automatically polls the repository.
2. Supports private GitHub repositories via `/etc/comin/access_token` (`my.services.comin.accessTokenPath`).
3. Comin evaluates the new flake revision, builds the system closure, and switches the running system automatically.
4. If an evaluation or build error occurs, Comin fails safely and keeps the previous generation running.

Comin self-restarts after deploying a change that alters its own unit (its module sets `restartIfChanged = false`, so comin restarts itself; it is *not* restarted by `nixos-rebuild switch`). After a manual `nixos-rebuild switch` that changes `comin.nix`, run `systemctl restart comin` to pick up the new config.

---

## 9 Code Style and Formatting

- **Formatter:** `nixfmt` (RFC 166), invoked with `nix fmt`. Run it on every change. The pinned formatter lives in `flake.nix` (`formatter.*`). Do **not** introduce `nixpkgs-fmt` formatting — the repo moved to `nixfmt`.
- Match the surrounding style: 2-space indent, `lib.` prefix for module-system helpers, trailing-comma in multi-line attribute lists.
- Keep files focused and small. Split one concern per file (see `modules/common/`).
- Comments are used to explain *why* (e.g. Determinate daemon clash, Homebrew workarounds) — keep them accurate and current.
- `nix fmt` covers `.nix` files only; markdown has no formatter, so README formatting is enforced by review and the §13 Agent Checklist.

---

## 10 Hygiene Secrets and Footguns

- **Never commit secrets.** Tokens/keys are read from host paths (`comin.nix` `accessTokenPath`, `tailscale.nix` `authKeyFile`). If you see a real token, key, or credential being added — stop and route it to a host-local path instead.
- **`flake.lock` must be committed.** Pushing a `flake.nix` change without the lock update (or vice versa) breaks reproducibility and Comin.
- **`stateVersion` is a one-way switch.** Only touch it when intentionally migrating; changing it backwards risks data loss and is a `feat`/breaking change.
- **nix-homebrew is finicky.** Cask history in this repo (vlc; musescore was removed) shows Homebrew's API `command_wrapper` errors and the `HOMEBREW_NO_INSTALL_FROM_API=1` workaround. When touching casks, validate with a dry-run and prefer pinned/stable workarounds over deleting entries.
- **Local agent tooling** (`.opencode/`, `.agents/`) is untracked — do not commit it or reference it as repo content.
- Do not commit `result`, `result-*`, `.direnv`, or other build artifacts.

---

## 11 Commit Convention

This repository follows **Conventional Commits**. Every commit subject MUST be:

```text
<type>(<scope>): <description>
```

All lowercase. The description is written in the **imperative mood**, present tense, no trailing period, and ideally ≤ 72 characters.

### Allowed types

| Type | When to use |
| :--- | :--- |
| `feat` | new feature, new package/cask/service/module, new host |
| `fix` | bug fix, workaround, revert of a broken change |
| `docs` | documentation only (README, comments) |
| `chore` | maintenance with no functional change (flake input bumps, tooling) |
| `refactor` | restructuring that does not change behavior (layout moves, renames) |
| `style` | formatting/lint only |
| `config` | configuration tweak (used historically) |

### Scope

The scope identifies **what area** the change touches. Use the host name for host-specific work, or the subsystem otherwise:

- `hrist` — macOS host (casks, nix-homebrew, darwin modules)
- `silmeria` — NixOS host (services, hardware)
- `comin`, `minecraft`, `omada`, `openssh`, `tailscale`, `virtualization` — individual services
- `nixos`, `darwin`, `common` — the module layer touched
- `layout` — repository structure
- `flake` — inputs/outputs in `flake.nix`

Use **no scope** for repo-wide changes (`docs`, `chore: update all flake inputs`, etc.).

### Examples (from this repo's history)

```text
feat(hrist): add opencode-desktop cask to homebrew modules
feat(comin): add access token support for private repository access
fix(hrist): update nix-homebrew to 6.0.13 for command_wrapper support and remove workaround
chore: update all flake inputs for hrist and silmeria
docs: update README with comin private repo auth and pkgs-unstable antigravity-cli
refactor(layout): Phase 5 — Modularize repository by machine and platform layer
```

### Body and footers

- A blank line after the subject starts the body. Use the body to explain **why**, not just what; describe behavior changes or operational impact (e.g. "triggers Comin self-restart").
- Breaking changes: append `!` after type/scope (`feat!(silmeria): ...`) and/or a `BREAKING CHANGE:` footer.
- Reference issues/PRs in the footer (`Refs: #12`, `Closes: #12`) and credit co-authors with a `Co-authored-by:` trailer.

### Rules

- One logical change per commit. If a change has multiple concerns, split it.
- Never silently rewrite or force-push `main` (Comin is watching); prefer a corrective forward commit. If force-push is truly required, use `--force-with-lease` and only with explicit approval.
- Do not copy the GitHub default merge message as a subject; keep the Conventional Commits format.

---

## 12 Branching and PR Workflow

- Work on a feature branch: `feat/<area>-<summary>`, `fix/<area>-<summary>`, `docs/...`.
- Open a PR to `main`. Historical PR titles mirror the squash-commit message (`feat(comin): add access token support for private repository access (#9)`).
- Before opening/merging: run the §7 validation, run `nix fmt`, and keep the PR diff small and reviewable.
- Merging to `main` deploys to `silmeria` automatically. State clearly in the PR/commit when a deploy/restart is expected (see §8 for comin restart semantics).

---

## 13 Agent Checklist

Before you start:

- [ ] Read this file (§0 and this checklist); identify which host(s) and module layer(s) the change touches.
- [ ] Grep the target area (e.g. `modules/darwin/`, `modules/nixos/services/`) and mimic existing patterns.

While working:

- [ ] Place files correctly per §2; register new modules in the parent `default.nix`.
- [ ] Use the `my.*` options pattern for services; pass `pkgs-unstable` via args, never an overlay.
- [ ] Run `nix fmt` (nixfmt, RFC 166) — never `nixpkgs-fmt`.
- [ ] Never introduce secrets; keep `flake.lock` in sync; don't edit `hardware-configuration.nix`.
- [ ] Keep commits atomic and Conventional (`type(scope): imperative description`).

Before you finish:

- [ ] Dry-run **both** hosts (§7) and `nix flake check`.
- [ ] Run `scripts/verify-docs.sh` (tree vs find, 5 direct inputs, TOC anchors) and confirm every TOC anchor resolves.
- [ ] If this file describes the layout/options, update it to avoid doc drift.
- [ ] Push only after validation (main auto-deploys via Comin).

---

## 14 References

- Conventional Commits: <https://www.conventionalcommits.org/en/v1.0.0/>
- NixOS & Flakes Book — Modularizing configs: <https://nixos-and-flakes.thiscute.world/nixos-with-flakes/modularize-the-configuration>
- numtide/blueprint — standard Nix folder layout: <https://github.com/numtide/blueprint>
- Misterio77 nix-starter-configs — flake + module organization: <https://github.com/Misterio77/nix-starter-configs>
- Comin (GitOps): <https://github.com/nlewo/comin>
- Determinate Nix installer: <https://install.determinate.systems/nix>
- mbentley/omada-controller image: <https://github.com/mbentley/docker-omada-controller>
