{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.services.virtualization;
in
{
  options.my.services.virtualization = {
    enable = lib.mkEnableOption "container virtualization with Podman and Distrobox";
  };

  config = lib.mkIf cfg.enable {
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
  };
}
