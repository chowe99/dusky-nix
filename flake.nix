{
  description = "Dusky - NixOS + Hyprland desktop environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Upstream dusky dotfiles — `nix flake update dusky-dotfiles` pulls changes
    dusky-dotfiles = {
      url = "github:dusklinux/dusky";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, dusky-dotfiles, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      duskyLib = import ./lib { inherit lib; };
      # The upstream dusky dotfiles path (used by modules to reference raw configs)
      dusky = dusky-dotfiles;
    in
    {
      # Reusable NixOS modules (for importing into other flakes)
      nixosModules = {
        default = { ... }: {
          imports = [
            ./options/dusky.nix
            ./modules
          ];
        };
        options = ./options/dusky.nix;
        base = ./modules/base.nix;
        desktop = ./modules/desktop.nix;
        audio = ./modules/audio.nix;
        networking = ./modules/networking.nix;
        services = ./modules/services.nix;
        laptop = ./modules/laptop.nix;
        virtualization = ./modules/virtualization.nix;
        gpu = ./modules/gpu;
      };

      # Reusable home-manager modules (for importing into other flakes)
      # IMPORTANT: When importing multiple modules, also import `dusky-args` once
      # to inject the `dusky` path argument. The `default` module includes it automatically.
      homeManagerModules = {
        # Arg injection — import this once alongside any individual modules
        dusky-args = { ... }: { _module.args.dusky = dusky; };

        # Full dusky home — imports everything (includes dusky-args)
        default = { ... }: {
          _module.args.dusky = dusky;
          imports = [ ./home ];
        };

        # Individual modules for selective import (require dusky-args)
        hyprland = ./home/hyprland;
        shell = { ... }: { imports = [ ./home/shell/zsh.nix ./home/shell/starship.nix ./home/shell/environment.nix ]; };
        terminal = { ... }: { imports = [ ./home/terminal/kitty.nix ./home/terminal/alacritty.nix ]; };
        theming = { ... }: { imports = [ ./home/theming/matugen.nix ./home/theming/gtk.nix ./home/theming/qt.nix ./home/theming/fonts.nix ]; };
        waybar = ./home/waybar;
        notifications = { ... }: { imports = [ ./home/notifications/swaync.nix ./home/notifications/swayosd.nix ]; };
        apps = { ... }: {
          imports = [
            ./home/apps/neovim.nix ./home/apps/rofi.nix ./home/apps/wlogout.nix
            ./home/apps/yazi.nix ./home/apps/zathura.nix ./home/apps/btop.nix
            ./home/apps/cava.nix ./home/apps/mpv.nix ./home/apps/zellij.nix
            ./home/apps/zed.nix ./home/apps/fastfetch.nix ./home/apps/waypaper.nix
          ];
        };
        desktop-entries = ./home/desktop-entries;
        services-home = ./home/services;
        documents = ./home/documents;
        uwsm = ./home/uwsm.nix;
      };

      # Expose packages as an overlay
      overlays.default = final: prev: {
        dusky = import ./packages { pkgs = final; inherit dusky; };
      };

      # Standalone packages
      packages.${system} = import ./packages { inherit pkgs dusky; };

      # Complete NixOS configuration (for standalone dusky installs)
      nixosConfigurations = {
        default = lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs duskyLib dusky; };
          modules = [
            ./options/dusky.nix
            ./modules
            ./hosts/default
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit inputs duskyLib dusky; };
                users.dusk = import ./home;
              };
            }
          ];
        };
      };
    };
}
