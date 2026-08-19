{ config, ... }:

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
  my.services.comin.enable = true;
  my.services.openssh.enable = true;
  my.services.minecraft.enable = true;
  my.services.tailscale.enable = true;
  my.services.virtualization.enable = true;

  # Bootloader settings
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

  # Stateful data release version (do not change unless read the manual)
  system.stateVersion = "25.11";
}
