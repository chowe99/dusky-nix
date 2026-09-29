# profiles/nixos/common.nix — the desktop core of a dusky host: greetd → UWSM →
# Hyprland, Plymouth, dusky user options, Btrfs snapshots via Snapper, and
# the nightly dua snapshot that dusky-disk reads.
#
# Needs dusky-nix's own nixosModules (see lib.duskyModules) and the `username`
# module argument. Snapper expects / and /home to be btrfs subvolumes, each
# with a .snapshots subvolume.
{
  config,
  pkgs,
  lib,
  username,
  ...
}: let
  cfg = config.dusky-desktop;
in {
  imports = [
    ./disk-snapshot.nix
  ];

  options.dusky-desktop.autoLogin =
    lib.mkEnableOption "greetd autologin straight into Hyprland (off = tuigreet login prompt)"
    // {default = false;};

  config = {
    # Nightly root-level disk-usage snapshot, read by dusky-disk / SUPER+CTRL+U.
    dusky-desktop.diskSnapshot.enable = lib.mkDefault true;

    # Greetd + UWSM session for Hyprland. autoLogin: greetd's default_session
    # runs straight as the user (dusky default). Otherwise tuigreet asks for a
    # password and then starts the same session.
    services.greetd = {
      enable = true;
      settings.default_session =
        if cfg.autoLogin
        then {
          command = "start-hyprland";
          user = username;
        }
        else {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --greeting 'dusky' --cmd start-hyprland";
          user = "greeter";
        };
    };
    # tuigreet --remember keeps the last username here.
    systemd.tmpfiles.rules = lib.mkIf (!cfg.autoLogin) ["d /var/cache/tuigreet 0755 greeter greeter -"];

    # Plymouth — clean boot splash with password prompt for LUKS decryption
    boot.plymouth.enable = true;
    boot.initrd.systemd.enable = true; # required for Plymouth to show LUKS prompt

    # Set dusky NixOS options
    dusky.user.name = username;
    dusky.user.home = "/home/${username}";
    dusky.laptop.enable = true;

    # Btrfs snapshots via Snapper (daily — /nix is a separate subvolume so already excluded)
    services.snapper = {
      snapshotInterval = "daily";
      cleanupInterval = "1d";
      configs = {
        root = {
          SUBVOLUME = "/";
          ALLOW_USERS = [username];
          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
          TIMELINE_LIMIT_HOURLY = 0;
          TIMELINE_LIMIT_DAILY = 7;
          TIMELINE_LIMIT_WEEKLY = 4;
          TIMELINE_LIMIT_MONTHLY = 0;
          TIMELINE_LIMIT_YEARLY = 0;
        };
        home = {
          SUBVOLUME = "/home";
          ALLOW_USERS = [username];
          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
          TIMELINE_LIMIT_HOURLY = 0;
          TIMELINE_LIMIT_DAILY = 7;
          TIMELINE_LIMIT_WEEKLY = 4;
          TIMELINE_LIMIT_MONTHLY = 0;
          TIMELINE_LIMIT_YEARLY = 0;
        };
      };
    };
  };
}
