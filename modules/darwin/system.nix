{ ... }:

{
  # Prevent nix-darwin from clashing with the Determinate installer's daemon
  nix.enable = false;
}
