{ config, pkgs, lib, ... }:

{
  imports = [
    ./hyprland
    ./uwsm.nix
    ./shell/zsh.nix
    ./shell/starship.nix
    ./shell/environment.nix
    ./terminal/kitty.nix
    ./terminal/alacritty.nix
    ./theming/matugen.nix
    ./theming/gtk.nix
    ./theming/qt.nix
    ./theming/fonts.nix
    ./waybar
    ./notifications/mako.nix
    ./apps/neovim.nix
    ./apps/rofi.nix
    ./apps/wlogout.nix
    ./apps/yazi.nix
    ./apps/zathura.nix
    ./apps/btop.nix
    ./apps/cava.nix
    ./apps/mpv.nix
    ./apps/zellij.nix
    ./apps/zed.nix
    ./apps/fastfetch.nix
    ./apps/waypaper.nix
    ./apps/blanket.nix
    ./desktop-entries
    ./services
    ./documents
  ];

  # Basic home-manager settings
  home = {
    username = "dusk";
    homeDirectory = "/home/dusk";
    stateVersion = "24.11";
  };

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # User packages (CLI tools that aren't system-level)
  home.packages = with pkgs; [
    # File management
    eza
    bat
    delta
    gdu
    fzf
    zoxide
    jq

    # Media
    cava
    peaclock
    kew

    # System info
    fastfetch
    cpufetch

    # Network
    speedtest-cli

    # Development
    python3
    nodejs

    # Theming
    matugen
    papirus-icon-theme
    adw-gtk3

    # Misc
    wtype
  ];

  # XDG base directories
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };
}
