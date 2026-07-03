{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.core.users;
in
{
  options.my.core.users = {
    enable = lib.mkEnableOption "core users profiles";
  };

  config = lib.mkIf cfg.enable {
    # Define a user account
    users.users.mikaels = {
      isNormalUser = true;
      description = "Mikael Souza";
      extraGroups = [
        "networkmanager"
        "wheel"
        "podman"
      ];
      packages = with pkgs; [
        neovim
      ];
    };
  };
}
