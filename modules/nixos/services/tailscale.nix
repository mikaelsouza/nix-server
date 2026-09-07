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

    # The tailnet is NOT blanket-trusted: `tailscale0` is deliberately absent
    # from `networking.firewall.trustedInterfaces`, so the firewall applies to
    # tailnet peers like any other network. Each service opens only the port it
    # needs on `tailscale0` (see `minecraft.nix` for 25565/tcp); SSH is already
    # covered by the global `allowedTCPPorts = [ 22 ]` in `openssh.nix`.
    # Tailscale's own UDP underlay (port 41641) rides the physical interface,
    # not `tailscale0`, so it is unaffected by these rules.
  };
}
