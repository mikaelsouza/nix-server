# Dell OptiPlex 3000 BIOS Setup Guide (`silmeria`)

This guide details the exact BIOS/UEFI settings required on the **Dell OptiPlex 3000** (Intel 12th Gen Core i5-12500T Alder Lake) to enable deep package C-states (**C8/C10**), ensure PCIe power efficiency, and maintain full network and server stability.

---

## 1. How to Enter BIOS Setup

1. Power off or restart the machine.
2. Turn the machine on and repeatedly press **F2** at the Dell splash logo until **"Preparing to enter Setup"** appears.
   *(Alternatively, press **F12** during boot and select **BIOS Setup** from the One-Time Boot Menu).*

---

## 2. Configuration Settings Map

Navigate the left-hand menu tree and configure the following options:

```text
├── Performance
│   ├── C-States Control          ──> [✓] Enabled
│   ├── Intel SpeedStep           ──> [✓] Enabled
│   ├── Intel Speed Shift         ──> [✓] Enabled
│   └── Intel Turbo Boost         ──> [✓] Enabled
│
├── Power / Power Management
│   ├── ASPM                      ──> [✓] Auto (or Enabled)  (see §5 for why the kernel override is still required)
│   ├── Block Sleep               ──> [ ] Disabled
│   ├── Deep Sleep Control        ──> [ ] Disabled
│   ├── USB Wake Support          ──> [✓] Enabled
│   └── AC Recovery               ──> [✓] Power On (Recommended for servers)
│
└── System Configuration / Integrated Devices
    └── Integrated NIC            ──> [✓] Enabled (or Enabled with PXE/WOL)
```

---

## 3. Settings Reference & Rationale

### 3.1 Performance Settings

| Setting | Recommended Value | Description & Rationale |
| :--- | :--- | :--- |
| **C-States Control** | **`Enabled`** (Checked) | **Mandatory.** Allows the Intel CPU cores to enter low-power sleep states (**C1E, C6, C8, and C10**) when idle. |
| **Intel SpeedStep** | **`Enabled`** | Enables dynamic frequency and voltage scaling so the CPU downclocks to **800 MHz** when idle. |
| **Intel Speed Shift** | **`Enabled`** | Hardware-managed P-states for ultra-fast frequency adjustments. |
| **Intel Turbo Boost** | **`Enabled`** | Allows the CPU to dynamically burst to maximum frequency when handling active workloads. |

### 3.2 Power Management Settings

| Setting | Recommended Value | Description & Rationale |
| :--- | :--- | :--- |
| **Active State Power Management (ASPM)** | **`Auto`** (or `Enabled`) | Enables PCIe link power saving (L0s/L1 states) for the onboard Realtek NIC and NVMe SSDs. |
| **Block Sleep** | **`Disabled`** (Unchecked) | **Crucial.** If enabled, the BIOS forces the OS to reject sleep and low-power standby modes. |
| **Deep Sleep Control** | **`Disabled`** | **Server Best Practice.** When enabled in S4/S5, Dell cuts standby power to the onboard NIC when powered down or suspended, which breaks **Wake-on-LAN** and remote power-on. |
| **AC Recovery** | **`Power On`** | Automatically powers the server back on following an AC power loss or outage. |
| **USB Wake Support** | **`Enabled`** | Allows waking or interacting via USB devices. |

### 3.3 System Configuration / Integrated Devices

| Setting | Recommended Value | Description & Rationale |
| :--- | :--- | :--- |
| **Integrated NIC** | **`Enabled`** | Ensures the onboard Realtek RTL8168/8111 controller is active and powered. |

---

## 4. Saving and Applying Changes

1. Click **Apply Changes** (or press the **Apply** button at the bottom right).
2. Click **Exit** to reboot the system.

---

## 5. Why NixOS `pcie_aspm=force` Is Also Required

Dell's BIOS firmware exports an ACPI FADT table containing the `ACPI_FADT_NO_ASPM` flag, which tells Linux that ASPM is unsupported by the OS even when ASPM is set to Auto in the BIOS.

In `hosts/silmeria/default.nix`, the following parameters override this ACPI flag at the kernel level:

```nix
boot.kernelParams = [
  "pcie_aspm=force"
  "pcie_aspm.policy=powersupersave"
];

powerManagement.powertop.enable = true;
```

This combination ensures the machine enters deep package C-states (**C10**) with zero PCIe AER crashes using the in-tree `r8169` driver.
