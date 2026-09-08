{
  description = "NixOS configuration for silmeria";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
      # Collapse comin's dev-only formatter tree onto ours; left alone it pins
      # a second, months-stale nixpkgs that every lock operation refetches.
      inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      comin,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;

      nixosConfigurations.silmeria = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs.pkgs-unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
        modules = [
          ./configuration.nix
          comin.nixosModules.comin
        ];
      };
    };
}
