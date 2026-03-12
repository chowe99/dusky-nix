{
  description = "Dusky - NixOS + Hyprland desktop environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      duskyLib = import ./lib { inherit lib; };
    in
    {
      # NixOS system configurations
      nixosConfigurations = {
        default = lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs duskyLib; };
          modules = [
            ./options/dusky.nix
            ./modules
            ./hosts/default
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit inputs duskyLib; };
                users.dusk = import ./home;
              };
            }
          ];
        };
      };

      # Expose packages as an overlay
      overlays.default = final: prev: {
        dusky = import ./packages { pkgs = final; };
      };

      # Standalone packages
      packages.${system} = import ./packages { inherit pkgs; };
    };
}
