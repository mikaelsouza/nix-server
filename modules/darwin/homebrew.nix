{ ... }:

{
  # Manage Homebrew packages (Casks, Mac App Store apps, Formulas)
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    taps = [ ];
    brews = [ ];
    casks = [
      "google-chrome"
      "google-drive"
      "antigravity"
      "antigravity-ide"
      "claude"
      "telegram"
      "discord"
      "orbstack"
      "rectangle"
      "transmission"
      "vlc"
      "whatsapp"
      "obsidian"
      "opencode-desktop"
      "tailscale-app"
      "visual-studio-code"
    ];
  };

  # Zhaofeng Li's nix-homebrew configuration
  nix-homebrew = {
    enable = true;
    user = "mikaelsouza";
    autoMigrate = true;
  };
}
