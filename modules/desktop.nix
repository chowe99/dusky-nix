{ config, pkgs, lib, ... }:

let
  cfg = config.dusky;
in
{
  # Hyprland compositor
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # UWSM session manager
  programs.uwsm = {
    enable = true;
    waylandCompositors.hyprland = {
      prettyName = "Hyprland";
      comment = "Hyprland compositor managed by UWSM";
      binPath = "/run/current-system/sw/bin/Hyprland";
    };
  };

  # XDG portals for screensharing, file picker, etc.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  # Polkit agent (for GUI privilege escalation)
  systemd.user.services.hyprpolkitagent = {
    description = "Hyprland Polkit Authentication Agent";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # Desktop packages
  environment.systemPackages = with pkgs; [
    # Wayland essentials
    wl-clipboard
    wl-clip-persist
    cliphist
    xdg-utils
    xdg-terminal-exec

    # Hyprland ecosystem
    hyprpicker
    hyprlock
    hypridle
    hyprsunset
    hyprpolkitagent

    # Wallpaper
    awww

    # Screenshot
    grim
    slurp
    satty

    # Notification
    swaynotificationcenter
    libnotify
    swayosd

    # App launcher
    rofi

    # Logout menu
    wlogout

    # File manager (CLI)
    yazi

    # Waypaper wallpaper GUI
    waypaper

    # Bars
    waybar

    # Misc desktop utils
    pavucontrol
    blueman
    networkmanagerapplet
    brightnessctl
    playerctl
    xhost
    glib.bin  # gdbus for control center D-Bus activation
    libxkbcommon  # xkbcli for keybindings rofi script

    # Cursor
    bibata-cursors
  ];

  # D-Bus
  services.dbus.enable = true;

  # Gnome keyring for credential storage
  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
}
