{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.dusky;
in {
  # Host-specific choices below are mkDefault so a host (or a profile built
  # on this module) can set its own without a conflict.

  # Bootloader
  boot.loader = {
    systemd-boot.enable = lib.mkDefault true;
    efi.canTouchEfiVariables = lib.mkDefault true;
  };

  # Nix settings
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      warn-dirty = false;
    };
    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
      options = lib.mkDefault "--delete-older-than 7d";
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Locale and timezone
  time.timeZone = lib.mkDefault "Asia/Karachi";
  i18n = {
    defaultLocale = lib.mkDefault "en_US.UTF-8";
    extraLocaleSettings = lib.mapAttrs (_: lib.mkDefault) {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  # Console
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  # User account
  users.users.${cfg.user.name} = {
    isNormalUser = true;
    home = cfg.user.home;
    description = lib.mkDefault "Dusky";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "render"
    ];
    shell = pkgs.zsh;
  };

  # Enable zsh system-wide (required for user shell)
  programs.zsh.enable = true;

  # Core system packages
  environment.systemPackages = with pkgs; [
    # System essentials
    git
    curl
    wget
    unzip
    zip
    ripgrep
    fd
    tree
    htop
    btop
    killall
    pciutils
    usbutils
    lsof

    # Filesystem
    btrfs-progs
    ntfs3g
    dosfstools

    # Build tools
    gcc
    gnumake
    cmake
    pkg-config

    # Nix tools
    nh
    nix-output-monitor
    nvd
  ];

  # Fonts
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
      fira-code
      fira-code-symbols
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      font-awesome
    ];
    fontconfig = {
      defaultFonts = {
        serif = ["Noto Serif"];
        sansSerif = ["Noto Sans"];
        monospace = ["JetBrainsMono Nerd Font"];
        emoji = ["Noto Color Emoji"];
      };
    };
  };

  # Security
  security = {
    polkit.enable = true;
    rtkit.enable = true; # Needed by PipeWire
    sudo.wheelNeedsPassword = true;
    pam.services.hyprlock = {};
  };

  # System state version
  system.stateVersion = lib.mkDefault "24.11";
}
