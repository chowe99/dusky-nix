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
      # Upstream rewrote the daemon as notify/battery_notify.sh: event-driven
      # on `upower --monitor-detail`, thresholds overridable from the
      # environment. Its config TUI (tui_battery.py) edits the script in place,
      # which a store path can't take, so it isn't packaged.
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-battery-notify";
        runtimeInputs = with pkgs; [upower libnotify pulseaudio pipewire gawk gnused systemd];
        text =
          builtins.replaceStrings
          ["/usr/share/sounds/freedesktop"]
          ["${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop"]
          (builtins.readFile "${scriptDir}/notify/battery_notify.sh");
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
