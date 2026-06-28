{ pkgs, ... }:

{
  services.tailscale = {
    enable = true;
    # Read the secret key locally from the server (outside the nix store / git)
    authKeyFile = "/var/lib/tailscale/authkey";
  };

  # Add the Tailscale CLI to PATH so it can be used directly in the terminal
  environment.systemPackages = [ pkgs.tailscale ];

  # Trust Tailscale interface so friends can connect to opened ports (like 25565)
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
