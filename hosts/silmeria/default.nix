{ ... }:

{
  imports = [
    # Include hardware configuration
    ./hardware-configuration.nix

    # Include shared and NixOS module definitions
    ../../modules/common
    ../../modules/nixos
  ];

  # Enable core and custom services options
  my.core.system.enable = true;
  my.core.users.enable = true;
  my.services.autoUpdate.enable = true;
  # deployKeyFile is left at the module default on purpose: the root-only, repo-scoped deploy key.
  my.services.comin.enable = true;
  my.services.openssh.enable = true;
  my.services.minecraft.enable = true;
  my.services.tailscale.enable = true;

  # Bootloader settings
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Bound the ESP: comin builds a generation per push, and /boot is a 1G vfat partition.
  boot.loader.systemd-boot.configurationLimit = 10;

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

  # DNS is pinned statically rather than taken from DHCP, for two reasons:
  #
  #   1. The LAN router reboots daily around 06:00 and flaps enp1s0 for ~60s.
  #      tailscaled recomputes its upstream resolvers on a link change, reading
  #      them from resolvconf, but NetworkManager re-registers its DHCP-derived
  #      record ~10s *after* the link returns. tailscaled therefore read an
  #      empty list, pinned `Routes:{.:[]}`, and answered every query with
  #      SERVFAIL until restarted. Routes stayed up, so the host remained
  #      reachable over SSH/Tailscale while all outbound lookups failed.
  #   2. That DHCP lease also advertises 192.168.1.1, which is off-subnet and
  #      unroutable here, so each lookup stalled ~5s before falling back.
  #
  # `dns = "none"` keeps NetworkManager off resolv.conf, and networking.nameservers
  # registers a static resolvconf record (`resolvconf -m 1 -a static`) from a
  # oneshot unit that does not depend on link state. tailscaled then always reads
  # a non-empty upstream list, flap or not. The gateway stays first so LAN names
  # still resolve; the public resolvers cover the router's reboot window.
  networking.networkmanager.dns = "none";
  networking.nameservers = [
    "192.168.0.1"
    "1.1.1.1"
    "1.0.0.1"
  ];

  # Stateful data release version (do not change unless read the manual)
  system.stateVersion = "25.11";
}
