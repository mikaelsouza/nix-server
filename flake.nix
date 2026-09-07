{
  description = "Unified Nix Flake for macOS (hrist) and NixOS (silmeria)";

  inputs = {
    # NixOS server track: gated on the NixOS release tests (boot, systemd, installer).
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # macOS workstation track: the same release, gated on the Darwin jobset.
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
      # Collapse comin's dev-only formatter tree onto ours; left alone it pins
      # a second, months-stale nixpkgs that every lock operation refetches.
      inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-darwin,
      nixpkgs-unstable,
      nix-darwin,
      nix-homebrew,
      comin,
      ...
    }:
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
      formatter.aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixfmt;
      formatter.aarch64-darwin = nixpkgs-darwin.legacyPackages.aarch64-darwin.nixfmt;
      formatter.x86_64-darwin = nixpkgs-darwin.legacyPackages.x86_64-darwin.nixfmt;

      # macOS Host Configuration
      darwinConfigurations."hrist" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./hosts/hrist
          nix-homebrew.darwinModules.nix-homebrew
        ];
        specialArgs = {
          pkgs-unstable = import nixpkgs-unstable {
            system = "aarch64-darwin";
            config.allowUnfree = true;
          };
        };
      };

      # Server Host Configuration
      nixosConfigurations."silmeria" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          pkgs-unstable = import nixpkgs-unstable {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
        };
        modules = [
          ./hosts/silmeria
          comin.nixosModules.comin
        ];
      };
    };
}
