# nix-server

Unified, modular Nix Flake repository for managing both **macOS** workstations and **NixOS** servers, pinned to the **Nixpkgs 26.05 Stable** channel.

---

## 🖥️ Managed Hosts

| Host | Operating System | Architecture | Purpose | Key Modules & Services |
| :--- | :--- | :--- | :--- | :--- |
| **`hrist`** | macOS (Darwin 26.05) | `aarch64-darwin` | Personal Workstation | `nix-darwin`, `nix-homebrew` (Ghostty, Zed, OrbStack, Chrome, etc.), Zsh direnv hook |
| **`silmeria`** | NixOS 26.05 | `x86_64-linux` | Home Server | Comin GitOps, OpenSSH, Tailscale VPN, Minecraft Server, Podman Virtualization |

---

## 📂 Modular Repository Layout

The repository follows a clean 3-tier separation: **Hosts** (machine-specific targets), **Modules** (shared and OS-specific capabilities), and a minimal **Flake** entrypoint.

```text
nix-server/
├── flake.nix                         # Minimal entrypoint (defines inputs and host mappings)
├── flake.lock                        # Pinned flake dependencies
├── hosts/
│   ├── hrist/
│   │   └── default.nix               # macOS host entrypoint (imports common & darwin modules)
│   └── silmeria/
│       ├── default.nix               # NixOS server entrypoint (imports common & nixos modules)
│       └── hardware-configuration.nix# Server hardware and file system definitions
└── modules/
    ├── common/                       # Cross-platform configurations (Linux & macOS)
    │   ├── default.nix               # Aggregates common modules
    │   ├── nix.nix                   # Flakes, experimental-features, and allowUnfree
    │   ├── packages.nix              # Shared CLI tools (git, neovim, nil, nixd, direnv)
    │   └── shell.nix                 # Zsh enable and direnv interactive integration
    ├── darwin/                       # macOS-specific modules
    │   ├── default.nix               # Aggregates darwin modules
    │   ├── homebrew.nix              # Homebrew taps, brews, and GUI casks
    │   ├── system.nix                # macOS daemon settings (nix.enable = false)
    │   └── users.nix                 # macOS primaryUser definition
    └── nixos/                        # NixOS-specific modules
        ├── default.nix               # Aggregates NixOS core and services
        ├── core/
        │   ├── system.nix            # System locales, timezones, and core tools
        │   └── users.nix             # Linux user accounts and groups
        └── services/
            ├── comin.nix             # GitOps continuous deployment service
            ├── minecraft.nix         # Declarative PaperMC Minecraft server
            ├── openssh.nix           # SSH daemon configuration & firewall rules
            ├── tailscale.nix         # Mesh VPN configuration
            └── virtualization.nix    # Podman container runtime & Distrobox
```

---

## ⚙️ Usage & Operations

### 1. Dry-Run / Validation (Build without switching)
Run these commands to verify syntax and derivation builds without altering your live system:

```bash
# Validate macOS workstation (hrist)
nix build .#darwinConfigurations.hrist.system --dry-run

# Validate NixOS server (silmeria)
nix build .#nixosConfigurations.silmeria.config.system.build.toplevel --dry-run
```

### 2. Applying Changes Live (`switch`)

* **On macOS (`hrist`):**
  ```bash
  darwin-rebuild switch --flake .#hrist
  ```

* **On NixOS Server (`silmeria`):**
  ```bash
  nixos-rebuild switch --flake .#silmeria
  ```

### 3. Formatting & Maintenance

* **Format Nix files:**
  ```bash
  nix fmt
  ```

* **Update Flake Dependencies:**
  ```bash
  nix flake update
  ```

---

## 🚀 GitOps Deployment (Comin)

The `silmeria` NixOS server runs **[Comin](https://github.com/nlewo/comin)**, a GitOps deployment agent. When changes are committed and pushed to the `main` branch of `github.com/mikaelsouza/nix-server`, Comin automatically pulls and applies the updated NixOS configuration without manual intervention.
