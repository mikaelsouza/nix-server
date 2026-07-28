{ pkgs, ... }:

{
  # Prevent nix-darwin from clashing with the Determinate installer's daemon
  nix.enable = false;

  system.primaryUser = "mikael";

  # Install standard Nix packages
  environment.systemPackages = [
    pkgs.neovim
    pkgs.git
    pkgs.nil
    pkgs.nixd
    pkgs.nixpkgs-fmt
    pkgs.direnv
  ];

  programs.zsh.enable = true;
  programs.zsh.interactiveShellInit = ''
    eval "$(direnv hook zsh)"
  '';

  # Manage Homebrew packages (Casks, Mac App Store apps, Formulas)
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    taps = [ ];
    brews = [ ];
    casks = [
      "ghostty"
      "musescore"
      "google-chrome"
      "google-drive"
      "zed"
      "antigravity"
      "antigravity-ide"
      "telegram"
      "discord"
      "orbstack"
      "rectangle"
      "transmission"
      "vlc"
      "whatsapp"
      "obsidian"
    ];
  };

  # Zhaofeng Li's nix-homebrew configuration
  nix-homebrew = {
    enable = true;
    enableRosetta = true; # Allow installing x86 packages on Apple Silicon
    user = "mikael"; # Must exactly match your macOS short username
    autoMigrate = true; # Automatically migrate if you already installed Homebrew manually
  };

  system.stateVersion = 5;
}
