{
  description = "My NixOS Config with Comin";

  inputs = {
    # Pin to a specific NixOS version (e.g., 25.11 or nixos-unstable)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Add Comin as a dependency
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      comin,
      ...
    }@inputs:
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
      formatter.aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixfmt-rfc-style;

      nixosConfigurations.silmeria = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          # This points to the host entrypoint
          ./hosts/silmeria
          # This pulls in the Comin module automatically
          comin.nixosModules.comin
        ];
      };
    };
}
