{
  config,
  lib,
  ...
}:

let
  cfg = config.my.services.tailscale;
in
{
  options.my.services.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN service";

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to a host-local file holding a Tailscale auth key, used to enroll
        the node. Leave null once enrolled: tailscaled persists its own state,
        and a path pointing at a missing file makes tailscaled-autoconnect
        fail the next time the node needs to log in.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      # Read the secret key locally from the server (outside the nix store / git)
      inherit (cfg) authKeyFile;
    };

    # Trust Tailscale interface so friends can connect to opened ports (like 25565)
    networking.firewall.trustedInterfaces = [ "tailscale0" ];
  };
}
