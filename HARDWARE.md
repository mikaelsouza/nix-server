# Hardware — Dell OptiPlex 3000 (`silmeria`)

Intel i5-12500T (Alder Lake), onboard Realtek RTL8111/8168 NIC (`[10ec:8168] rev 1b`).

## The problem

The NIC used to drop its link after hours or days, and the kernel log filled with PCIe AER
recovery failures until a reboot:

```text
pcieport 0000:00:1c.0: AER: Uncorrectable (Fatal) error from 0000:01:00.0
r8168 0000:01:00.0: AER: can't recover (no error_detected callback)
pcieport 0000:00:1c.0: AER: device recovery failed
```

Two causes:

1. **Dell's ACPI FADT sets `ACPI_FADT_NO_ASPM`**, so Linux disables PCIe ASPM on every link even
   when ASPM is enabled in the BIOS. Alder Lake needs all PCIe links in ASPM L1 substates to reach
   package C8/C10, so the CPU never idled below PC2.
2. **The out-of-tree `r8168` driver was used to work around this.** It performs ad-hoc ASPM
   transitions without kernel ACPI coordination and implements no `pci_error_handlers` callbacks —
   so when a link transition threw a fatal PCIe error, the root port could not recover the device
   and looped resetting it forever.

## The fix

Use the in-tree `r8169` driver (default; nothing to configure) and override the FADT flag in the
kernel instead. In `configuration.nix`:

```nix
boot.kernelParams = [
  "pcie_aspm=force"
  "pcie_aspm.policy=powersupersave"
];

powerManagement.powertop.enable = true;
```

`r8169` implements PCIe runtime PM and error handling correctly, so the links enter L1/L1.1/L1.2
without triggering AER lockups, and the package reaches C10.

## BIOS settings

Press **F2** at the Dell splash to enter setup.

| Menu | Setting | Value | Why |
| :--- | :--- | :--- | :--- |
| Performance | C-States Control | Enabled | Required for core C1E/C6/C8/C10. |
| Performance | Intel SpeedStep | Enabled | Lets the CPU drop to 800 MHz at idle. |
| Performance | Intel Speed Shift | Enabled | Hardware-managed P-states. |
| Performance | Intel Turbo Boost | Enabled | Burst clock under load. |
| Power | ASPM | Auto | PCIe link power saving. The kernel override above is still required — the FADT flag overrules this setting. |
| Power | Block Sleep | Disabled | Otherwise the BIOS makes the OS reject low-power states. |
| Power | Deep Sleep Control | Disabled | Enabled, it cuts standby NIC power in S4/S5 and breaks Wake-on-LAN. |
| Power | AC Recovery | Power On | Server comes back after an outage. |
| Power | USB Wake Support | Enabled | Wake via USB. |
| System Configuration | Integrated NIC | Enabled | Keeps the onboard Realtek active. |

## Verification

After a reboot into the new generation:

```bash
# C-state residency — expect package C8/C10 >80% at idle.
# powertop is in environment.systemPackages (configuration.nix).
sudo powertop --csv=/tmp/powertop.csv --time=10
grep -E "C8|C10" /tmp/powertop.csv

# No AER recovery failures.
journalctl -k -b | grep -iE "AER|r8169|recovery"

# NIC PCIe runtime PM — expect "auto".
cat /sys/bus/pci/devices/0000:01:00.0/power/control

# In-tree driver is bound — expect "Kernel driver in use: r8169".
sudo nix run nixpkgs#pciutils -- lspci -k -d 10ec:8168 | grep "Kernel driver in use"
```
