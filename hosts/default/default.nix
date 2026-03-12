{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Machine-specific hostname
  networking.hostName = "dusky";

  # GPU type for this host
  dusky.gpu.type = "intel";

  # Laptop features (ASUS TUF F15)
  dusky.laptop.enable = true;

  # User
  dusky.user.name = "dusk";
  dusky.user.home = "/home/dusk";

  # Session manager
  dusky.displayManager = "uwsm";

  # Defaults
  dusky.terminal = "kitty";
  dusky.browser = "firefox";

  # Virtualization (enable for Looking Glass / KVM)
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # Tailscale
  services.tailscale.enable = true;

  # Host-specific extra packages
  environment.systemPackages = with pkgs; [
    firefox
    vesktop
    obs-studio
    mpv
    zathura
    neovim
    kitty
    alacritty
    gnome-calculator
    gnome-disk-utility
  ];
}
