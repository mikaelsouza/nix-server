{ pkgs, ... }:

{
  # Define a user account
  users.users.mikaels = {
    isNormalUser = true;
    description = "Mikael Souza";
    extraGroups = [
      "networkmanager"
      "wheel"
      "podman"
    ];
    packages = with pkgs; [
      neovim
    ];
  };
}
