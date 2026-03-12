{ pkgs, dusky }:

let
  scriptDir = "${dusky}/user_scripts/waybar";
in
pkgs.symlinkJoin {
  name = "dusky-waybar-scripts";
  paths = [
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-waybar-autostart";
      runtimeInputs = with pkgs; [ waybar procps util-linux coreutils systemd ];
      text = builtins.readFile "${scriptDir}/waybar_autostart.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-waybars";
      runtimeInputs = with pkgs; [ waybar gum coreutils ];
      text = builtins.readFile "${scriptDir}/dusky_waybars.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-waybar-cava";
      runtimeInputs = with pkgs; [ cava ];
      text = builtins.readFile "${scriptDir}/cava.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-toggle-hypridle";
      runtimeInputs = with pkgs; [ hypridle procps libnotify ];
      text = builtins.readFile "${scriptDir}/toggle_hypridle.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-waybar-network-meter";
      runtimeInputs = with pkgs; [ coreutils iproute2 ];
      text = builtins.readFile "${scriptDir}/network/network_meter_daemon.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-waybar-weather";
      runtimeInputs = with pkgs; [ python3 ];
      text = ''exec python3 ${scriptDir}/weather.py "$@"'';
    })
  ];
}
