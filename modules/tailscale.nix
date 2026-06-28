{ pkgs, ... }:

{
  services.tailscale = {
    enable = true;
    # Read the secret key locally from the server (outside the nix store / git)
    authKeyFile = "/var/lib/tailscale/authkey";
  };

  # Trust Tailscale interface so friends can connect to opened ports (like 25565)
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
