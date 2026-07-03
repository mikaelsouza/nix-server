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
      openFirewall = true; # Opens port 25565 TCP/UDP
      package = pkgs.papermc; # Use PaperMC instead of vanilla Mojang
      jvmOpts = "-Xms10G -Xmx10G -XX:+UseG1GC"; # Allocate 10GB of RAM with G1 Garbage Collector
      serverProperties = {
        online-mode = false;
      };
    };
  };
}
