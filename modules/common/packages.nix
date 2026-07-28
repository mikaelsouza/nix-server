{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.git
    pkgs.neovim
  ];
}
