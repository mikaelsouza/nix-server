{ ... }:

{
  # Manage Homebrew packages (Casks, Mac App Store apps, Formulas)
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    taps = [ ];
    brews = [ ];
    casks = [
      "ghostty"
      # "musescore" # Upstream Homebrew cask definition contains deprecated `command_wrapper`
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
      # "vlc" # Upstream Homebrew cask definition contains deprecated `command_wrapper`
      "whatsapp"
      "obsidian"
      "opencode-desktop"
    ];
  };

  # Zhaofeng Li's nix-homebrew configuration
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "mikael";
    autoMigrate = true;
  };
}
