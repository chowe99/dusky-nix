# profiles/nixos/standalone.nix — a complete dusky desktop machine (NixOS side):
# common.nix + desktop-base + CachyOS kernel, plus the system basics (nix,
# boot, firmware, NetworkManager, the user). No sshd, no remote access.
#
# Use via lib.mkSystem (which adds the dusky stack and home-manager).
# Host specifics (hardware, timezone, locale) go in hosts/<host>/configuration.nix.
{
  config,
  pkgs,
  lib,
  hostname,
  username,
  ...
}: {
  imports = [
    ./desktop-base.nix
    ./cachyos-kernel.nix
    ./common.nix
  ];

  # --- Nix -----------------------------------------------------------------
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nixpkgs.config.allowUnfree = true;

  # --- Boot / kernel / firmware -------------------------------------------
  boot.loader = {
    systemd-boot.enable = lib.mkDefault true;
    systemd-boot.configurationLimit = lib.mkDefault 10;
    efi.canTouchEfiVariables = lib.mkDefault true;
  };
  # CachyOS kernel, prebuilt from the lantian attic cache that
  # cachyos-kernel.nix adds as a substituter.
  cachyos-kernel.enable = lib.mkDefault true;

  # Unknown hardware: ship every firmware blob (WiFi/BT/GPU/SOF audio).
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
  # Generic GPU stack (mesa: Intel/AMD/nouveau).
  hardware.graphics.enable = true;
  zramSwap.enable = lib.mkDefault true;

  # --- Networking ----------------------------------------------------------
  networking.hostName = hostname;
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # --- User ----------------------------------------------------------------
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = ["wheel" "networkmanager" "video" "audio"];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;
  home-manager.backupFileExtension = "backup";

  # --- Desktop extras -----------------------------------------------------
  # Required when home-manager.useUserPackages is enabled with xdg portals
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];
  environment.variables.QT_QPA_PLATFORM = "wayland";
  # Thunar thumbnails (Thunar hands off to tumbler over D-Bus).
  services.tumbler.enable = true;

  environment.systemPackages = with pkgs; [
    btrfs-progs
    git # flakes fetch over git
    ffmpegthumbnailer # video thumbnails for tumbler
  ];
}
