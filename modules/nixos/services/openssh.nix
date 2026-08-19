{ config, lib, ... }:

let
  cfg = config.my.services.openssh;
in
{
  options.my.services.openssh = {
    enable = lib.mkEnableOption "OpenSSH daemon and firewall rules";
  };

  config = lib.mkIf cfg.enable {
    # OpenSSH daemon settings
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true;
        PermitRootLogin = "no";
      };
    };

    # Firewall configuration
    networking.firewall.allowedTCPPorts = [ 22 ];
  };
}
