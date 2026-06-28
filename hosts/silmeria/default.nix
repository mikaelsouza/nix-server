{ config, pkgs, ... }:

{
  imports = [
    # Include hardware configuration
    ./hardware-configuration.nix

    # Include modular global systems
    ../../modules/system.nix
    ../../modules/services.nix
    ../../modules/minecraft.nix
    ../../modules/virtualization.nix
    ../../modules/users.nix
  ];

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
}
