{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.core.users;
in
{
  options.my.core.users = {
    enable = lib.mkEnableOption "core users profiles";
  };

  config = lib.mkIf cfg.enable {
    # Define a user account
    users.users.mikaels = {
      isNormalUser = true;
      description = "Mikael Souza";
      # Match the shell that modules/common/shell.nix configures, otherwise the
      # direnv hook in programs.zsh.interactiveShellInit never runs.
      shell = pkgs.zsh;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      # Declared here so a rebuild onto fresh hardware is still reachable.
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMC624R5uwRjD8KVkbHZKolaXSRX8E6kzbJD3U+WUyXJ mikaelsouza@hrist.local"
      ];
    };
  };
}
