# profiles/nixos/standalone.nix — a complete dusky desktop machine (NixOS side):
# the plain port's own system modules (base, desktop, audio, networking,
# services, gpu, laptop) + common.nix + desktop-base + CachyOS kernel.
# No sshd, no remote access, no virtualisation.
#
# The port modules carry dusky's system half (nix settings, fonts, polkit,
# PAM for hyprlock, PipeWire/WirePlumber, NetworkManager, zram, fstrim,
# backlight udev rules, TLP, the user account); this file only adds what a
# machine of unknown hardware needs on top and the profile's own choices.
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
    ../../options/dusky.nix
    ../../modules/base.nix
    ../../modules/desktop.nix
    ../../modules/audio.nix
    ../../modules/networking.nix
    ../../modules/services.nix
    ../../modules/gpu
    ../../modules/laptop.nix
    ./desktop-base.nix
    ./cachyos-kernel.nix
    ./common.nix
  ];

  # --- Nix -----------------------------------------------------------------
  # (flakes, gc, allowUnfree: modules/base.nix) Keep two weeks of generations.
  nix.gc.options = "--delete-older-than 14d";

  # --- Boot / kernel / firmware -------------------------------------------
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 10;
  # CachyOS kernel, prebuilt from the lantian attic cache that
  # cachyos-kernel.nix adds as a substituter.
  cachyos-kernel.enable = lib.mkDefault true;

  # Unknown hardware: ship every firmware blob (WiFi/BT/GPU/SOF audio).
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
  # Generic GPU stack only (Mesa: Intel/AMD/nouveau), no vendor extras.
  dusky.gpu.type = lib.mkDefault "mesa";

  # --- Networking ----------------------------------------------------------
  # (NetworkManager + firewall: modules/networking.nix)
  networking.hostName = hostname;

  # --- User ----------------------------------------------------------------
  # (account, groups, zsh: modules/base.nix, via dusky.user from common.nix)
  users.users.${username}.description = username;
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
    ffmpegthumbnailer # video thumbnails for tumbler
  ];
}
