{ config, lib, ... }:

let
  cfg = config.my.services.comin;
in
{
  options.my.services.comin = {
    enable = lib.mkEnableOption "Comin GitOps deployment service";
  };

  config = lib.mkIf cfg.enable {
    services.comin = {
      enable = true;
      remotes = [
        {
          name = "origin";
          url = "https://github.com/mikaelsouza/nix-server.git";
          branches.main.name = "main";
        }
      ];
    };
  };
}
