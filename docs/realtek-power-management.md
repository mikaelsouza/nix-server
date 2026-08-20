# Realtek RTL8168/8111 Network Stability & C-State Power Management

This document details the investigation, root causes, BIOS configurations, and NixOS declarative settings for managing the Realtek RTL8111/8168 Gigabit Ethernet controller (`[10ec:8168] rev 1b`) on the Dell OptiPlex 3000 (`silmeria`, Intel 12th Gen Core i5-12500T Alder Lake).

---

## 1. Problem Description

The server periodically suffered from:
1. **Network Disconnections & Complete Link Drops**: The Ethernet interface would become unresponsive after hours or days of runtime, or flap links repeatedly (`link down` / `link up`).
2. **PCIe AER Infinite Recovery Loops**: Kernel logs flooded with hundreds of thousands of error lines (`pcieport ...: AER: device recovery failed`), pinning kernel resources until a reboot.
3. **C-State Power Trade-off**: The out-of-tree `r8168` driver was previously used in an attempt to reach deep CPU package C-states (C8/C10), but forced ASPM options caused fatal PCIe bus crashes.

---

## 2. Root Cause Analysis

### 2.1 Dell OptiPlex 3000 ACPI FADT Restriction
The Dell OptiPlex 3000 BIOS ACPI FADT table includes the `ACPI_FADT_NO_ASPM` flag:
```text
kernel: ACPI FADT declares the system doesn't support PCIe ASPM, so disable it
kernel: acpi PNP0A08:00: FADT indicates ASPM is unsupported, using BIOS configuration
```
By default, the Linux kernel disables PCIe Active State Power Management across all PCIe links. On Intel Alder Lake SoC platforms, **Package C-states PC8/PC10 (and any state deeper than PC8) require all PCIe root ports and endpoints to enter ASPM L1/L1 substates** and runtime power management.

### 2.2 Why the Out-of-Tree `r8168` Driver Failed
In previous configurations, `hosts/silmeria/default.nix` attempted:
```nix
boot.extraModulePackages = [ config.boot.kernelPackages.r8168 ];
boot.blacklistedKernelModules = [ "r8169" ];
boot.kernelModules = [ "r8168" ];
boot.extraModprobeConfig = "options r8168 aspm=1 eee=1";
```
- The out-of-tree Realtek `r8168` driver attempted ad-hoc ASPM transitions without kernel ACPI coordination (`r8168: can't disable ASPM; OS doesn't have ASPM control`).
- When link power transitions occurred, the PCIe bus threw a fatal uncorrectable error:
  ```text
  kernel: pcieport 0000:00:1c.0: AER: Uncorrectable (Fatal) error message received from 0000:01:00.0
  kernel: r8168 0000:01:00.0: AER: PCIe Bus Error: severity=Uncorrectable (Fatal), type=Inaccessible
  kernel: r8168 0000:01:00.0: AER: can't recover (no error_detected callback)
  kernel: pcieport 0000:00:1c.0: AER: Root Port link has been reset (0)
  kernel: pcieport 0000:00:1c.0: AER: device recovery failed
  ```
- **Crucial flaw:** The out-of-tree `r8168` driver **does not implement Linux `pci_error_handlers` callbacks** (`no error_detected callback`). The PCIe root port could not recover the NIC and entered an infinite reset loop, cutting network connectivity.

### 2.3 The Solution: In-Tree `r8169` + Kernel-Level ASPM Override
In modern Linux kernels (Linux 6.x), the built-in **`r8169`** driver:
- Is actively maintained upstream and uses firmware from `linux-firmware` (`rtl_nic/rtl8168h-2.fw`).
- Correctly implements Linux PCIe runtime power management and error handling.
- When paired with `pcie_aspm=force` and `pcie_aspm.policy=powersupersave`, the Linux kernel overrides Dell's ACPI FADT restriction, safely placing PCIe links into ASPM L1/L1.1/L1.2 without triggering AER recovery lockups.

---

## 3. Dell OptiPlex 3000 BIOS Setup

To ensure hardware-level power saving and remote access compatibility, configure the BIOS (press **F2** on startup):

| Menu | Setting | Recommended Value | Purpose |
| :--- | :--- | :--- | :--- |
| **Performance** | `C-States Control` | **Enabled** | Allows CPU cores to enter C1E, C6, C8, and C10 sleep states. |
| **Performance** | `Intel SpeedStep` / `Speed Shift` | **Enabled** | Allows dynamic CPU frequency/voltage scaling down to 800 MHz at idle. |
| **Performance** | `Intel Turbo Boost` | **Enabled** | High clock performance under active load. |
| **Power** | `ASPM` | **Auto** / **Enabled** | PCIe link power management. |
| **Power** | `Block Sleep` | **Disabled** | Prevents the BIOS from blocking OS-level sleep modes. |
| **Power** | `Deep Sleep Control` | **Disabled** | Prevents cutting standby NIC power (preserves Wake-on-LAN and remote power). |
| **System Configuration** | `Integrated NIC` | **Enabled** (or `Enabled with PXE/WOL`) | Ensures onboard Realtek NIC is active. |

---

## 4. Declarative NixOS Configuration

In `hosts/silmeria/default.nix`:

```nix
  # Hardware power management & PCIe ASPM
  # Force PCIe ASPM to override Dell BIOS FADT ACPI restrictions, allowing package C8/C10
  boot.kernelParams = [
    "pcie_aspm=force"
    "pcie_aspm.policy=powersupersave"
  ];

  # Enable powertop auto-tuning on startup for runtime PM across PCI/USB/SATA devices
  powerManagement.powertop.enable = true;

  # Networking
  networking.hostName = "silmeria";
  networking.networkmanager.enable = true;
```

---

## 5. Verification & Troubleshooting

After deploying and rebooting into the new generation:

### 1. Verify C-State Residency
`powertop` is already installed on `silmeria` (`environment.systemPackages` in `modules/nixos/core/system.nix`), so no extra package is needed. Run it non-interactively and dump a report:
```bash
sudo powertop --csv=/tmp/powertop.csv --time=10
grep -E "C8|C10" /tmp/powertop.csv
```
*Expected:* The processor idle-state report shows core and package C8/C10 residency >80% at idle. (Interactively, `sudo powertop` → press `Tab` to the "Idle stats" tab; `q` to quit.)

*Alternative* (turbostat is not in the system packages and needs MSR access):
```bash
sudo modprobe msr
sudo nix run nixpkgs#linuxPackages.turbostat -- --quiet --interval 1 --num_iterations 3
```

### 2. Verify Zero PCIe AER Errors
Check kernel logs for any AER recovery errors:
```bash
journalctl -k -b | grep -i -E "AER|r8169|recovery"
```
*Expected:* Zero `AER: device recovery failed` messages.

### 3. Verify ASPM State
Check PCIe link power state for the Realtek NIC (`0000:01:00.0`):
```bash
cat /sys/bus/pci/devices/0000:01:00.0/power/control
# Output: auto
```

### 4. Verify the `r8169` Driver Is Bound
Confirm the in-tree driver (not the out-of-tree `r8168`) owns the NIC (`pciutils` is not in the system packages, so use `nix run`):
```bash
sudo nix run nixpkgs#pciutils -- lspci -k -d 10ec:8168 | grep -E "Kernel driver in use"
# Expected: "Kernel driver in use: r8169"
```
