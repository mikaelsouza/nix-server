{ ... }:

{
  # Allow unfree packages across all platforms
  nixpkgs.config.allowUnfree = true;

  # Flakes are enabled per-platform: the Determinate installer does so on
  # macOS, while the NixOS module enables them elsewhere.
}
