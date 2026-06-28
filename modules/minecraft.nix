{ pkgs, ... }:

{
  services.minecraft-server = {
    enable = true;
    eula = true; # Agree to Minecraft EULA
    openFirewall = true; # Opens port 25565 TCP/UDP
    package = pkgs.papermc; # Use PaperMC instead of vanilla Mojang
    jvmOpts = "-Xms10G -Xmx10G -XX:+UseG1GC"; # Allocate 10GB of RAM with G1 Garbage Collector
  };
}
