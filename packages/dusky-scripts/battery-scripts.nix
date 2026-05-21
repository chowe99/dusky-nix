{ pkgs, dusky }:

let
  scriptDir = "${dusky}/user_scripts/battery";
in
pkgs.symlinkJoin {
  name = "dusky-battery-scripts";
  paths = [
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-battery-notify";
      runtimeInputs = with pkgs; [ libnotify acpi coreutils ];
      text = builtins.readFile "${scriptDir}/notify/dusky_battery_notify.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-power-saver";
      runtimeInputs = with pkgs; [ hyprland brightnessctl coreutils procps ];
      text = builtins.readFile "${scriptDir}/power_saver.sh";
    })
    (pkgs.writeShellScriptBin "dusky-power-saver-off" ''
      export PATH="${pkgs.lib.makeBinPath (with pkgs; [ hyprland brightnessctl coreutils procps ])}:$PATH"
      exec ${pkgs.bash}/bin/bash ${scriptDir}/power_saver.sh --disable "$@"
    '')
  ];
}
