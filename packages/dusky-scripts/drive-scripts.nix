{ pkgs, dusky }:

let
  scriptDir = ../../assets/scripts/drives;
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
  ];
}
