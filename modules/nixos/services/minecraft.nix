{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.services.minecraft;
in
{
  options.my.services.minecraft = {
    enable = lib.mkEnableOption "PaperMC Minecraft Server";
  };

  config = lib.mkIf cfg.enable {
    services.minecraft-server = {
      enable = true;
      eula = true; # Agree to Minecraft EULA
      declarative = true; # REQUIRED to make serverProperties actually do something!
      openFirewall = false; # Never open 25565 globally; it is opened on tailscale0 only (below)
      package = pkgs.papermc; # Use PaperMC instead of vanilla Mojang
      jvmOpts = "-Xms10G -Xmx10G -XX:+UseG1GC"; # Allocate 10GB of RAM with G1 Garbage Collector
      serverProperties = {
        # LOCKED (README §0): offline-mode with no whitelist is deliberate.
        # 25565 is unreachable except over Tailscale (openFirewall = false +
        # the tailscale0-scoped rule below), so tailnet membership is the
        # access control. Players are added/removed in Tailscale, not here.
        online-mode = false;
      };
    };

    # Open 25565 for tailnet peers only. Minecraft Java is TCP-only, so no UDP
    # rule is needed. Scoped per-interface because `tailscale0` is not a
    # trusted interface (see `tailscale.nix`).
    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 25565 ];
  };
}
