{
  description = "Dusky - NixOS + Hyprland desktop environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Upstream dusky dotfiles — `nix flake update dusky-dotfiles` pulls changes
    dusky-dotfiles = {
      url = "github:dusklinux/dusky";
      flake = false;
    };

    # --- Desktop profile layer (profiles/, hosts/will) ---
    # Prebuilt CachyOS kernels (overlays.cachyos, profiles/nixos/cachyos-kernel.nix).
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Zen browser for the standalone profile (profiles/home/standalone.nix).
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # TEMP(opencode-bun14): pinned ONLY for `pkgs.opencode` (overlays.opencode).
    # nixpkgs-unstable >= 02f5696b (2026-09-13) builds opencode 1.18.30 with bun
    # 1.4.2, and that binary dies on every prompt ("Unexpected server error",
    # TypeError 'a.name' in the Effect layer resolver). This rev (2026-09-10)
    # still builds the same version with bun 1.3.13 -- a working binary.
    # DELETE once unstable's opencode works: drop this input and
    # overlays.opencode, then `nix flake lock`. Test with
    # `opencode run x </dev/null` (stdin must be closed or it waits forever).
    # The overlay warns at eval once unstable's opencode moves off the pin.
    nixpkgs-opencode.url = "github:NixOS/nixpkgs/aff8a0b28396750446e5537a96461bc4facdb287";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    dusky-dotfiles,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    lib = nixpkgs.lib;
    duskyLib = import ./lib {inherit lib;};
    # The upstream dusky dotfiles path (used by modules to reference raw configs)
    dusky = dusky-dotfiles;
  in {
    # Reusable NixOS modules (for importing into other flakes).
    # The first group is the plain dusky port (modules/); the second is the
    # desktop profile layer (profiles/nixos/) built on top of it.
    nixosModules = {
      default = {...}: {
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

      # --- Desktop profile ---
      # Desktop core: greetd/UWSM/Hyprland, Plymouth, Snapper, dua snapshot.
      common = ./profiles/nixos/common.nix;
      # A complete machine: common + desktop-base + cachyos-kernel + basics.
      standalone = ./profiles/nixos/standalone.nix;
      desktop-base = ./profiles/nixos/desktop-base.nix;
      cachyos-kernel = ./profiles/nixos/cachyos-kernel.nix;
      disk-snapshot = ./profiles/nixos/disk-snapshot.nix;
    };

    # Reusable home-manager modules (for importing into other flakes)
    # IMPORTANT: When importing multiple modules, also import `dusky-args` once
    # to inject the `dusky` path argument. The `default` module includes it automatically.
    homeManagerModules = {
      # Arg injection — import this once alongside any individual modules
      dusky-args = {...}: {_module.args.dusky = dusky;};

      # Full dusky home — imports everything (includes dusky-args)
      default = {...}: {
        _module.args.dusky = dusky;
        imports = [./home];
      };

      # Individual modules for selective import (require dusky-args)
      hyprland = ./home/hyprland;
      shell = {...}: {imports = [./home/shell/zsh.nix ./home/shell/starship.nix ./home/shell/environment.nix];};
      terminal = {...}: {imports = [./home/terminal/kitty.nix ./home/terminal/alacritty.nix];};
      theming = {...}: {imports = [./home/theming/matugen.nix ./home/theming/gtk.nix ./home/theming/qt.nix ./home/theming/fonts.nix];};
      waybar = ./home/waybar;
      notifications = {...}: {imports = [./home/notifications/mako.nix];};
      apps = {...}: {
        imports = [
          ./home/apps/neovim.nix
          ./home/apps/rofi.nix
          ./home/apps/wlogout.nix
          ./home/apps/yazi.nix
          ./home/apps/zathura.nix
          ./home/apps/btop.nix
          ./home/apps/cava.nix
          ./home/apps/mpv.nix
          ./home/apps/zellij.nix
          ./home/apps/zed.nix
          ./home/apps/fastfetch.nix
          ./home/apps/waypaper.nix
          ./home/apps/blanket.nix
        ];
      };
      desktop-entries = ./home/desktop-entries;
      services-home = ./home/services;
      documents = ./home/documents;
      uwsm = ./home/uwsm.nix;

      # --- Desktop profile (profiles/home/) ---
      # Plain paths (not wrappers) so importing one from several places dedups.
      # standalone expects the `inputs` special arg to carry zen-browser
      # (lib.mkSystem passes this flake's inputs).
      common = ./profiles/home/common.nix;
      standalone = ./profiles/home/standalone.nix;
      package-set = ./profiles/home/package-set.nix;
      zsh = ./profiles/home/zsh.nix;
      kitty = ./profiles/home/kitty.nix;
      fastfetch = ./profiles/home/fastfetch.nix;
      zoxide = ./profiles/home/zoxide.nix;
      fzf = ./profiles/home/fzf.nix;
      fd = ./profiles/home/fd.nix;
      ripgrep = ./profiles/home/ripgrep.nix;
      tmux = ./profiles/home/tmux.nix;
      tmux-keybindings = ./profiles/home/tmux-keybindings.nix;
      hyprland-keybindings = ./profiles/home/hyprland-keybindings.nix;
      zen-transparency = ./profiles/home/zen-transparency.nix;
      dusky-extras = ./profiles/home/dusky-extras.nix;
      opencode = ./profiles/home/opencode.nix;
    };

    overlays = {
      # Expose packages as an overlay (pkgs.dusky.*)
      default = final: prev: {
        dusky = import ./packages {
          pkgs = final;
          inherit dusky;
        };
      };
      cachyos = inputs.nix-cachyos-kernel.overlays.pinned;
      # TEMP(opencode-bun14): see the nixpkgs-opencode input.
      opencode = final: prev: let
        pinned = inputs.nixpkgs-opencode.legacyPackages.${final.stdenv.hostPlatform.system}.opencode;
      in {
        opencode =
          lib.warnIf (prev.opencode.version != pinned.version)
          "unstable's opencode is now ${prev.opencode.version} (pinned ${pinned.version}): re-test it, and if it works delete the nixpkgs-opencode pin (TEMP(opencode-bun14) in dusky-nix's flake.nix)"
          pinned;
      };
    };

    lib = rec {
      # dusky's app configs, trimmed to what the desktop drives: rofi,
      # wlogout, yazi, btop, waypaper. (The full `apps` also brings
      # neovim, zathura, cava, mpv, zellij, zed, fastfetch and blanket.)
      standaloneApps = {
        imports = map (a: ./home/apps/${a}.nix) ["rofi" "wlogout" "yazi" "btop" "waypaper"];
      };

      # The dusky stack for a NixOS host with home-manager: its overlay,
      # NixOS options + desktop module, and the selective home-manager modules
      # (dusky theming ships its own matugen-coloured oh-my-posh prompt).
      duskyModules = {apps ? self.homeManagerModules.apps}: [
        {nixpkgs.overlays = [self.overlays.default];}
        self.nixosModules.options
        self.nixosModules.desktop
        {
          home-manager.sharedModules = [
            self.homeManagerModules.dusky-args
            self.homeManagerModules.hyprland
            self.homeManagerModules.theming
            self.homeManagerModules.notifications
            apps
            self.homeManagerModules.waybar
            self.homeManagerModules.desktop-entries
            self.homeManagerModules.services-home
            self.homeManagerModules.uwsm
            {programs.oh-my-posh.enable = lib.mkForce false;}
          ];
        }
      ];

      # A dusky desktop machine. hostConfig should import
      # nixosModules.standalone (plus its hardware file); homeConfig should
      # import homeManagerModules.standalone.
      mkSystem = {
        hostname,
        username ? hostname,
        system ? "x86_64-linux",
        hostConfig,
        homeConfig,
        apps ? standaloneApps,
        extraModules ? [],
        specialArgs ? {inherit inputs;},
      }:
        lib.nixosSystem {
          specialArgs = specialArgs // {inherit hostname username;};
          modules =
            [
              hostConfig
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.${username} = import homeConfig;
                home-manager.extraSpecialArgs = specialArgs // {inherit hostname username;};
              }
            ]
            ++ duskyModules {inherit apps;}
            ++ extraModules
            ++ [
              {
                nixpkgs.hostPlatform = system;
                nixpkgs.overlays = [self.overlays.cachyos self.overlays.opencode];
              }
            ];
        };
    };

    # Standalone packages
    packages.${system} = import ./packages {inherit pkgs dusky;};

    # `nix flake check`: every packaged script carries its own runtime deps.
    checks.${system}.runtime-deps = import ./checks/runtime-deps {
      inherit pkgs;
      packages = [self.packages.${system}.dusky-scripts-all];
    };

    # Complete NixOS configuration (for standalone dusky installs)
    nixosConfigurations = {
      default = lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs duskyLib dusky;};
        modules = [
          # pkgs.dusky.* (home/hyprland reads pkgs.dusky.dusky-user-scripts)
          {nixpkgs.overlays = [self.overlays.default];}
          ./options/dusky.nix
          ./modules
          ./hosts/default
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {inherit inputs duskyLib dusky;};
              users.dusk = import ./home;
            };
          }
        ];
      };

      # Will's machine: the desktop profile on unknown hardware (LUKS2 +
      # btrfs). See hosts/will/INSTALL.md.
      will = self.lib.mkSystem {
        hostname = "will";
        hostConfig = ./hosts/will/configuration.nix;
        homeConfig = ./hosts/will/home.nix;
      };
    };

    templates.default = {
      path = ./template;
      description = "A dusky desktop machine: flake + host + user skeleton";
    };
  };
}
