{ pkgs, dusky }:

let
  scriptDir = "${dusky}/user_scripts/drives";
in
pkgs.symlinkJoin {
  name = "dusky-drive-scripts";
  paths = [
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-drive-manager";
      runtimeInputs = with pkgs; [ cryptsetup util-linux coreutils libnotify ];
      text = builtins.readFile "${scriptDir}/drive_manager.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-io-monitor";
      runtimeInputs = with pkgs; [ coreutils procps ];
      text = builtins.readFile "${scriptDir}/io_monitor.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-btrfs-stats";
      runtimeInputs = with pkgs; [ compsize btrfs-progs util-linux gawk gnugrep coreutils ];
      text = builtins.readFile "${scriptDir}/btrfs_zstd_compression_stats.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-ntfs-fix";
      runtimeInputs = with pkgs; [ ntfs3g cryptsetup util-linux coreutils ];
      text = builtins.readFile "${scriptDir}/ntfs_fix.sh";
    })
  ];
}
