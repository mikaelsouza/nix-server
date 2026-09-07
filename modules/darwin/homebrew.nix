{ ... }:

{
  # Manage Homebrew packages (Casks, Mac App Store apps, Formulas)
  homebrew = {
    enable = true;
    # LOCKED (README §0): "zap" is how apps are uninstalled on this host.
    # Dropping a cask from the list below IS the uninstall, and zap is what
    # makes it complete -- it removes the app plus its leftover preferences,
    # support dirs and launch agents. Do not lower this to "uninstall"/"none".
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
