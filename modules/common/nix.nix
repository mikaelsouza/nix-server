{ ... }:

{
  # Allow unfree packages across all platforms
  nixpkgs.config.allowUnfree = true;

  # Enable modern Nix CLI and Flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
