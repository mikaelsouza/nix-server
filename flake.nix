{
  description = "Unified Nix Flake for macOS (hrist) and NixOS (silmeria)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      nix-darwin,
      nix-homebrew,
      comin,
      ...
    }:
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
      formatter.aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixfmt;
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
      formatter.x86_64-darwin = nixpkgs.legacyPackages.x86_64-darwin.nixfmt;

      # macOS Host Configuration
      darwinConfigurations."hrist" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./hosts/hrist
          nix-homebrew.darwinModules.nix-homebrew
        ];
      };

      # Server Host Configuration
      nixosConfigurations."silmeria" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/silmeria
          comin.nixosModules.comin
          ({ ... }: {
            nixpkgs.overlays = [
              (final: prev: {
                antigravity-cli = nixpkgs-unstable.legacyPackages.x86_64-linux.antigravity-cli;
              })
            ];
          })
        ];
      };
    };
}
