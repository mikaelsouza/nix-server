{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:

let
  cfg = config.my.core.system;
in
{
  options.my.core.system = {
    enable = lib.mkEnableOption "core system configurations";
  };

  config = lib.mkIf cfg.enable {
    # Enable modern Nix CLI and Flakes (NixOS-only: nix-darwin manages its own daemon)
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Set time zone
    time.timeZone = "America/Sao_Paulo";

    # Select internationalisation properties
    i18n.defaultLocale = "en_US.UTF-8";

    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };

    # Configure keymap in X11
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    # List packages installed in system profile
    environment.systemPackages = with pkgs; [
      vim
      powertop
      python3
      pkgs-unstable.antigravity-cli
      pkgs-unstable.claude-code
    ];
  };
}
