{
  pkgs,
  dusky,
}: let
  scriptDir = "${dusky}/user_scripts/drives";

  # drive_manager.py uses tomllib (Python 3.11+) but has no version guard, so
  # pkgs.python3 (>= 3.11) is sufficient. Upstream pacman-installs keyring + rich
  # on Arch; provide them via Nix instead so the auto-bootstrapper never fires.
  driveManagerPython = pkgs.python3.withPackages (ps: with ps; [keyring rich]);

  # dusky_disk_monitor_io.py is a Textual TUI; needs textual + rich.
  ioMonitorPython = pkgs.python3.withPackages (ps: with ps; [textual rich]);
in
  pkgs.symlinkJoin {
    name = "dusky-drive-scripts";
    paths = [
      # drive_manager.py locates its config via Path(__file__).parent / "drives.toml"
      # (after checking ~/.config/drive_manager/drives.toml). Running the interpreter
      # against the upstream copy in place means __file__ resolves into the dusky
      # store dir, where drives.toml already sits beside it — so it finds the bundled
      # default with no copy, and a user override still takes precedence.
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-drive-manager";
        runtimeInputs = with pkgs; [cryptsetup util-linux lsof udisks2 coreutils];
        text = ''exec ${driveManagerPython}/bin/python3 ${scriptDir}/drive_manager/drive_manager.py "$@"'';
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-io-monitor";
        runtimeInputs = with pkgs; [util-linux nvme-cli smartmontools];
        text = ''exec ${ioMonitorPython}/bin/python3 ${scriptDir}/dusky_disk_monitor_io.py "$@"'';
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-btrfs-stats";
        runtimeInputs = with pkgs; [compsize btrfs-progs util-linux gawk gnugrep coreutils];
        text = builtins.readFile "${scriptDir}/btrfs_zstd_compression_stats.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-ntfs-fix";
        runtimeInputs = with pkgs; [ntfs3g cryptsetup util-linux coreutils];
        text = builtins.readFile "${scriptDir}/ntfs_fix.sh";
      })
    ];
  }
