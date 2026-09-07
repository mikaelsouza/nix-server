{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.git
    pkgs.neovim
    pkgs.nixd
    pkgs.direnv
    pkgs.uv
  ];
}
