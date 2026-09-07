{ ... }:

{
  imports = [
    ./core/system.nix
    ./core/users.nix
    ./services/auto-update.nix
    ./services/comin.nix
    ./services/openssh.nix
    ./services/minecraft.nix
    ./services/tailscale.nix
  ];
}
