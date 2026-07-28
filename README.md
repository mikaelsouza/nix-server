# nix-server

Unified Nix Flake configuration for managing both **macOS** workstations and **NixOS** servers in a single repository, pinned to the **Nixpkgs 26.05 Stable** channel.

---

## 🖥️ Managed Hosts

| Host | Operating System | Architecture | Purpose | Key Modules & Services |
| :--- | :--- | :--- | :--- | :--- |
| **`hrist`** | macOS (Darwin 26.05) | `aarch64-darwin` | Personal Workstation | `nix-darwin`, `nix-homebrew` (Ghostty, Zed, OrbStack, Chrome, etc.), Zsh direnv hook |
| **`silmeria`** | NixOS 25.11 / 26.05 | `x86_64-linux` | Home Server | Comin GitOps, OpenSSH, Tailscale VPN, Minecraft Server, Podman Virtualization |

---

## 📂 Repository Layout

```text
nix-server/
├── flake.nix                         # Multi-host entrypoint (hrist + silmeria)
├── flake.lock                        # Pinned dependencies
├── hosts/
│   ├── hrist/
│   │   └── default.nix               # macOS host configuration & Homebrew casks
│   └── silmeria/
│       ├── default.nix               # NixOS server host configuration & service toggles
│       └── hardware-configuration.nix# Server hardware & file system definitions
└── modules/
    ├── default.nix                   # Modules entrypoint
    ├── common/
    │   └── packages.nix              # Shared cross-platform system packages (git, neovim)
    ├── core/
    │   ├── system.nix                # System locales, timezones, and core tools
    │   └── users.nix                 # User account definitions
    └── services/
        ├── comin.nix                 # GitOps continuous deployment service
        ├── minecraft.nix             # Declarative Minecraft server unit
        ├── openssh.nix               # SSH daemon configuration & firewall rules
        ├── tailscale.nix             # Mesh VPN configuration
        └── virtualization.nix        # Podman container runtime & tools
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
