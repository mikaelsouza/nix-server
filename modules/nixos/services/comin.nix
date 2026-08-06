{ config, lib, ... }:

let
  cfg = config.my.services.comin;
in
{
  options.my.services.comin = {
    enable = lib.mkEnableOption "Comin GitOps deployment service";

    accessTokenPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/etc/comin/access_token";
      description = "Path to access token file on the host system for authenticating with the private git repository.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.comin = {
      enable = true;
      remotes = [
        ({
          name = "origin";
          url = "https://github.com/mikaelsouza/nix-server.git";
          branches.main.name = "main";
        } // lib.optionalAttrs (cfg.accessTokenPath != null) {
          auth.access_token_path = cfg.accessTokenPath;
        })
      ];
    };

    systemd.services.comin.environment.COMIN_CONFIG_HASH =
      builtins.hashString "sha256" (builtins.toJSON config.services.comin);
  };
}
