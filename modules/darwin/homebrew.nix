{ ... }:

{
  # Prevent Homebrew JSON API parsing bugs with legacy cask attributes like command_wrapper
  environment.variables.HOMEBREW_NO_INSTALL_FROM_API = "1";

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
