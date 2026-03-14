{ pkgs, dusky }:

let
  scriptDir = "${dusky}/user_scripts/images";
in
pkgs.symlinkJoin {
  name = "dusky-screenshot-scripts";
  paths = [
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-screenshot";
      runtimeInputs = with pkgs; [ grim slurp satty wl-clipboard libnotify hyprland jq coreutils ];
      text = builtins.readFile "${scriptDir}/dusky_screenshot.sh";
    })
  ];
}
