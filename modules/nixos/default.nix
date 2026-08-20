{ ... }:

{
  imports = [
    ./core/system.nix
    ./core/users.nix
    ./services/comin.nix
    ./services/openssh.nix
    ./services/minecraft.nix
    ./services/omada.nix
    ./services/tailscale.nix
    ./services/virtualization.nix
  ];
}
