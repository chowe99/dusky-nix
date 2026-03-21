{ pkgs, dusky }:

let
  scriptDir = "${dusky}/user_scripts";
in
pkgs.symlinkJoin {
  name = "dusky-network-scripts";
  paths = [
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-network";
      runtimeInputs = with pkgs; [ networkmanager gum coreutils ];
      text = builtins.readFile "${scriptDir}/network_manager/dusky_network.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-warp-toggle";
      runtimeInputs = with pkgs; [ coreutils ];
      text = builtins.readFile "${scriptDir}/networking/warp_toggle.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-arp-scan";
      runtimeInputs = with pkgs; [ arp-scan coreutils gnugrep gawk ];
      text = builtins.readFile "${scriptDir}/networking/arp_scan.sh";
    })
  ];
}
