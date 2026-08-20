{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.git
    pkgs.neovim
    pkgs.nil
    pkgs.nixd
    pkgs.direnv
    pkgs.uv
  ];
}
