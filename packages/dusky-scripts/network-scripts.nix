{ pkgs }:

let
  scriptDir = ../../assets/scripts/networking;
in
pkgs.symlinkJoin {
  name = "dusky-network-scripts";
  paths = [
    (pkgs.writeShellApplication {
      name = "dusky-network";
      runtimeInputs = with pkgs; [ networkmanager gum coreutils ];
      text = builtins.readFile "${scriptDir}/dusky_network.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-warp-toggle";
      runtimeInputs = with pkgs; [ coreutils ];
      text = builtins.readFile "${scriptDir}/warp_toggle.sh";
    })
  ];
}
