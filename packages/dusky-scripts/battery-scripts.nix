{
  pkgs,
  dusky,
}: let
  scriptDir = "${dusky}/user_scripts/battery";
  # asusctl / tlp come from their NixOS services (services.asusd, services.tlp),
  # so they are allowlisted in checks/runtime-deps rather than wrapped here.
  powerSaverDeps = with pkgs; [hyprland brightnessctl coreutils procps gum hyprshade playerctl wireplumber uwsm ddcutil libnotify];
in
  pkgs.symlinkJoin {
    name = "dusky-battery-scripts";
    paths = [
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-battery-notify";
        runtimeInputs = with pkgs; [libnotify acpi coreutils];
        text = builtins.readFile "${scriptDir}/notify/dusky_battery_notify.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-power-saver";
        runtimeInputs = powerSaverDeps;
        text = builtins.readFile "${scriptDir}/power_saver.sh";
      })
      (pkgs.writeShellScriptBin "dusky-power-saver-off" ''
        export PATH="${pkgs.lib.makeBinPath powerSaverDeps}:$PATH"
        exec ${pkgs.bash}/bin/bash ${scriptDir}/power_saver.sh --disable "$@"
      '')
    ];
  }
