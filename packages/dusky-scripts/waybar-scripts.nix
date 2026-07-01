{
  pkgs,
  dusky,
}: let
  scriptDir = "${dusky}/user_scripts/waybar";
in
  pkgs.symlinkJoin {
    name = "dusky-waybar-scripts";
    paths = [
      (pkgs.writeShellApplication {
        checkPhase = "";
        # Upstream's waybar TUI rewrite removed waybar_autostart.sh. waybar_toggle.sh
        # is the successor "state manager for Waybar" (start/stop/toggle; default
        # action is toggle). Kept under the dusky-waybar-autostart name so existing
        # consumers (keybinds.conf ALT+9) keep resolving.
        name = "dusky-waybar-autostart";
        runtimeInputs = with pkgs; [waybar procps util-linux coreutils systemd];
        text = builtins.readFile "${scriptDir}/waybar_toggle.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        # tui_waybars.py replaces the removed dusky_waybars.sh switcher/manager CLI
        # (its docstring states it duplicates dusky_waybars.sh as a standalone CLI).
        # It imports the dusky_tui package (implicit namespace packages, stdlib-only),
        # so expose that dir on PYTHONPATH for the headless flag operations
        # (--toggle / --back_toggle / --apply, used by keybinds.conf). With no args it
        # execs the TUI from ~/user_scripts/dusky_tui (deployed dotfiles).
        name = "dusky-waybars";
        runtimeInputs = with pkgs; [python3 waybar procps];
        text = ''
          export PYTHONPATH="${dusky}/user_scripts/dusky_tui''${PYTHONPATH:+:$PYTHONPATH}"
          exec python3 ${scriptDir}/tui_waybars.py "$@"
        '';
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-waybar-cava";
        runtimeInputs = with pkgs; [cava];
        text = builtins.readFile "${scriptDir}/cava.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-toggle-hypridle";
        runtimeInputs = with pkgs; [hypridle procps libnotify];
        text = builtins.readFile "${scriptDir}/toggle_hypridle.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-waybar-network-meter";
        runtimeInputs = with pkgs; [coreutils iproute2];
        text = builtins.readFile "${scriptDir}/network/network_meter_daemon.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-waybar-weather";
        runtimeInputs = with pkgs; [python3];
        text = ''exec python3 ${scriptDir}/weather.py "$@"'';
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-waybar-mako";
        runtimeInputs = with pkgs; [mako jq coreutils];
        text = builtins.readFile "${scriptDir}/mako.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-waybar-update-counter";
        runtimeInputs = with pkgs; [jq coreutils iputils];
        text = builtins.readFile "${scriptDir}/update_counter.sh";
      })
    ];
  }
