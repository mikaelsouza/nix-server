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

  # Target hardware-specific customizations (Realtek network driver)
  boot.extraModulePackages = [ config.boot.kernelPackages.r8168 ];
  boot.blacklistedKernelModules = [ "r8169" ];
  boot.kernelModules = [ "r8168" ];
  boot.extraModprobeConfig = "options r8168 aspm=1 eee=1";

  # Networking
  networking.hostName = "silmeria";
  networking.networkmanager.enable = true;

  # Stateful data release version (do not change unless read the manual)
  system.stateVersion = "25.11";
}
