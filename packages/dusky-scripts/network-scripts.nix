{ pkgs, dusky }:

let
  scriptDir = ../../assets/scripts/networking;
in
pkgs.symlinkJoin {
  name = "dusky-network-scripts";
  paths = [
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-network";
      runtimeInputs = with pkgs; [ networkmanager gum coreutils ];
      text = builtins.readFile "${scriptDir}/dusky_network.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-warp-toggle";
      runtimeInputs = with pkgs; [ coreutils ];
      text = builtins.readFile "${scriptDir}/warp_toggle.sh";
    })
  ];
}
