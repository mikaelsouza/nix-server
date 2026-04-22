{
  description = "My NixOS Config with Comin";

  inputs = {
    # Pin to a specific NixOS version (e.g., 25.11 or nixos-unstable)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    
    # Add Comin as a dependency
    comin.url = "github:nlewo/comin";
  };

  outputs = { self, nixpkgs, comin, ... }@inputs: {
    nixosConfigurations.silmeria = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        # This points to your existing configuration
        ./configuration.nix
        # This pulls in the Comin module automatically
        comin.nixosModules.comin
      ];
    };
  };
}
