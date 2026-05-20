{ pkgs, ... }:

{
  # Container management and virtualization options
  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  # Distrobox allows running standard interactive distributions inside containers
  environment.systemPackages = with pkgs; [
    distrobox
  ];
}
