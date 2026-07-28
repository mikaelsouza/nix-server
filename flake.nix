{
  description = "Unified Nix Flake for macOS (hrist) and NixOS (silmeria)";

  inputs = {
    # macOS inputs
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Server inputs
    nixpkgs-server.url = "github:nixos/nixpkgs/nixos-25.11";
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs-server";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs-darwin,
      nix-darwin,
      nix-homebrew,
      nixpkgs-server,
      comin,
      ...
    }:
    {
      formatter.x86_64-linux = nixpkgs-server.legacyPackages.x86_64-linux.nixfmt-rfc-style;
      formatter.aarch64-linux = nixpkgs-server.legacyPackages.aarch64-linux.nixfmt-rfc-style;

      # macOS Host Configuration
      darwinConfigurations."hrist" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./hosts/hrist
          nix-homebrew.darwinModules.nix-homebrew
        ];
      };

      # Server Host Configuration
      nixosConfigurations."silmeria" = nixpkgs-server.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/silmeria
          comin.nixosModules.comin
        ];
      };
    };
}
