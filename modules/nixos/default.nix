{ ... }:

{
  imports = [
    ./core/system.nix
    ./core/users.nix
    ./services/comin.nix
    ./services/openssh.nix
    ./services/minecraft.nix
    ./services/tailscale.nix
    ./services/virtualization.nix
  ];
}
