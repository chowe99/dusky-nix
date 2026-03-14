{ pkgs, dusky }:

let
  scriptDir = ../../assets/scripts/battery;
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
      text = builtins.readFile "${scriptDir}/power_saving/power_saver.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-power-saver-off";
      runtimeInputs = with pkgs; [ hyprland brightnessctl coreutils procps ];
      text = builtins.readFile "${scriptDir}/power_saving_off/power_saver_off.sh";
    })
  ];
}
