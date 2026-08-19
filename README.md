# ❄️ nix-server

[![Nixpkgs](https://img.shields.io/badge/Nixpkgs-26.05%20Stable-5277C3?logo=nixos&logoColor=white)](https://github.com/NixOS/nixpkgs/tree/nixpkgs-26.05-darwin)
[![nix-darwin](https://img.shields.io/badge/nix--darwin-26.05-black?logo=apple&logoColor=white)](https://github.com/nix-darwin/nix-darwin)
[![GitOps](https://img.shields.io/badge/GitOps-Comin-blueviolet)](https://github.com/nlewo/comin)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A unified, modular Nix Flake repository managing both personal **macOS workstations** and **NixOS home servers**, pinned to the unified **Nixpkgs 26.05 Stable** channel.

---

## 🖥️ Managed Hosts

| Host | OS & Platform | Architecture | Role | Key Modules & Services |
| :--- | :--- | :--- | :--- | :--- |
| **`hrist`** | macOS (Darwin 26.05) | `aarch64-darwin` | Personal Workstation | `nix-darwin`, `nix-homebrew` (Ghostty, Zed, OrbStack, Chrome, Tailscale, etc.), Zsh direnv hook |
| **`silmeria`** | NixOS 26.05 | `x86_64-linux` | Home Server | Comin GitOps (Private Repo Auth), OpenSSH, Tailscale VPN, Antigravity CLI (`agy`), Minecraft Server, Podman Containers |

---

## 🏗️ Architecture & Modular Layout

The repository is organized into a clean **3-Tier Structure**:
1. **`hosts/`**: Minimal, machine-specific entrypoints (hardware config, hostnames, module activations).
2. **`modules/`**: Reusable configuration layers divided into `common/` (cross-platform), `darwin/` (macOS-only), and `nixos/` (Linux-only).
3. **`flake.nix`**: Lightweight root orchestrator declaring inputs (`nixpkgs-26.05` & `nixpkgs-unstable`), mapping hosts, and passing `pkgs-unstable` via `specialArgs`.

```text
nix-server/
├── flake.nix                         # Minimal root entrypoint (inputs, specialArgs & host mappings)
├── flake.lock                        # Pinned dependencies (26.05 stable & unstable overlay)
├── README.md                         # Repository documentation
├── hosts/
│   ├── hrist/                        # macOS Workstation
│   │   └── default.nix               # Imports modules/common & modules/darwin
│   └── silmeria/                     # NixOS Server
│       ├── default.nix               # Imports modules/common & modules/nixos
│       └── hardware-configuration.nix# Server hardware and partition definitions
└── modules/
    ├── common/                       # Shared cross-platform layer (Linux & macOS)
    │   ├── default.nix               # Aggregates common modules
    │   ├── nix.nix                   # Flakes, experimental-features, and allowUnfree
    │   ├── packages.nix              # Shared CLI tools (git, neovim, nil, nixd, direnv, uv)
    │   └── shell.nix                 # Zsh configuration and direnv interactive hook
    ├── darwin/                       # macOS-specific layer
    │   ├── default.nix               # Aggregates darwin modules
    │   ├── homebrew.nix              # Homebrew taps, brews, and GUI casks
    │   ├── system.nix                # macOS daemon settings (nix.enable = false)
    │   └── users.nix                 # macOS primaryUser definition
    └── nixos/                        # NixOS-specific layer
        ├── default.nix               # Aggregates core and services
        ├── core/
        │   ├── system.nix            # System locales, timezones, and core tools (antigravity-cli)
        │   └── users.nix             # Linux user accounts and groups
        └── services/
            ├── comin.nix             # GitOps continuous deployment service (private repo token support)
            ├── minecraft.nix         # Declarative PaperMC Minecraft server
            ├── openssh.nix           # SSH daemon configuration & firewall rules
            ├── tailscale.nix         # Mesh VPN configuration
            └── virtualization.nix    # Podman container runtime & Distrobox
```

---

## 🔄 Module Separation Strategy

```mermaid
graph TD
    subgraph Hosts
        H1[hosts/hrist]
        H2[hosts/silmeria]
    end

    subgraph Modules
        MC[modules/common<br/>• Git & Neovim<br/>• Direnv & Zsh Hook<br/>• Nix Flakes Settings]
        MD[modules/darwin<br/>• Homebrew & Casks<br/>• nix-homebrew<br/>• primaryUser]
        MN[modules/nixos<br/>• Systemd Services<br/>• Linux Users & Groups<br/>• Bootloader & Kernel]
    end

    H1 --> MC
    H1 --> MD
    H2 --> MC
    H2 --> MN
```

* **Shared (`modules/common/`)**: Developer tools (`neovim`, `git`, `nil`, `nixd`, `direnv`, `uv`), Nix flakes enablement (`nix-command`, `flakes`), and `allowUnfree = true`.
* **macOS (`modules/darwin/`)**: GUI applications managed via Homebrew (Ghostty, Zed, Chrome, Obsidian, OrbStack, Discord, Tailscale, etc.), `nix-homebrew` integration (`enableRosetta = true`), and Determinate daemon compatibility (`nix.enable = false`).
* **NixOS (`modules/nixos/`)**: Systemd services (`comin` with optional private repo access token, `openssh`, `minecraft`, `tailscale`, `virtualization`), Linux accounts (`mikaels` in `wheel`, `networkmanager`, `podman`), `antigravity-cli` (sourced explicitly via `pkgs-unstable` `specialArgs`), and Realtek `r8168` hardware overrides.

---

## 🚀 Bootstrap: Fresh macOS Install (hrist)

Set up a new Mac (`hrist`) from scratch:

### 1. Install Nix (Determinate Installer)

This repo expects the **Determinate Nix installer** daemon — the darwin config disables nix-darwin's own Nix service (`nix.enable = false`) to avoid clashing with it:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Then restart your shell so `nix` is on `PATH`.

### 2. Clone the Repository

```bash
git clone git@github.com:mikaelsouza/nix-server.git
cd nix-server
```

### 3. Build & Activate the Configuration

`darwin-rebuild` isn't on `PATH` yet, so build the system and invoke `darwin-rebuild` from the result:

```bash
nix build .#darwinConfigurations.hrist.system
./result/sw/bin/darwin-rebuild switch --flake .#hrist
```

This evaluates the flake, builds the system closure, and switches. Homebrew (taps, brews, casks) and all managed apps are installed automatically during activation.

### 4. Verify

```bash
darwin-rebuild --version          # should now resolve on PATH
which zsh && direnv --version     # common modules applied
ls /Applications | grep -i tailscale # casks installed
```

Once bootstrapped, subsequent updates only need the normal switch command below.

---

## 🛠️ Usage & Operations

### 1. Dry-Run Validation (Build without switching)
Test evaluation and derivation builds locally without modifying the system state:

```bash
# Validate macOS workstation (hrist)
nix build .#darwinConfigurations.hrist.system --dry-run

# Validate NixOS server (silmeria)
nix build .#nixosConfigurations.silmeria.config.system.build.toplevel --dry-run
```

### 2. Applying Configuration Live (`switch`)

* **On macOS (`hrist`):**
  ```bash
  darwin-rebuild switch --flake .#hrist
  ```

* **On NixOS Server (`silmeria`):**
  ```bash
  sudo nixos-rebuild switch --flake .#silmeria
  ```

### 3. Formatting & Code Style
Format all Nix files across the repository using the pinned RFC-compliant formatter:

```bash
nix fmt
```

### 4. Updating Flake Dependencies
To update flake inputs (Nixpkgs, nix-darwin, Comin) to their latest channel revisions:

```bash
nix flake update
```

---

## 🚀 GitOps Automation (Comin)

The `silmeria` NixOS server runs **[Comin](https://github.com/nlewo/comin)** in the background:
1. When changes are committed and pushed to the `main` branch on GitHub, Comin automatically polls the repository.
2. Supports private GitHub repositories via `/etc/comin/access_token` (`my.services.comin.accessTokenPath`).
3. Comin evaluates the new flake revision, builds the system closure, and switches the running system automatically.
4. If an evaluation or build error occurs, Comin fails safely and keeps the previous generation running.

---

## ➕ Adding a New Host

To add a new machine to this repository:
1. Create a directory under `hosts/<hostname>/`.
2. Add a `default.nix` importing `../../modules/common` and either `../../modules/darwin` or `../../modules/nixos`.
3. Add the host entry to `flake.nix` under `darwinConfigurations` or `nixosConfigurations`.
4. Run dry-run validation:
   ```bash
   nix build .#<configurations>.<hostname>... --dry-run
   ```
