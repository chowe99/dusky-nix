{
  pkgs,
  dusky,
}: let
  scriptDir = "${dusky}/user_scripts/hypr";
in
  pkgs.symlinkJoin {
    name = "dusky-hypr-scripts";
    paths = [
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-adjust-scale";
        runtimeInputs = with pkgs; [python3 hyprland libnotify];
        text = ''exec python3 ${scriptDir}/monitor/adjust_scale.py "$@"'';
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-screen-rotate";
        runtimeInputs = with pkgs; [python3 hyprland libnotify];
        text = ''exec python3 ${scriptDir}/monitor/screen_rotate.py "$@"'';
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-blur-toggle";
        runtimeInputs = with pkgs; [hyprland jq libnotify mako];
        text = builtins.readFile "${scriptDir}/hypr_blur_opacity_shadow_toggle.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-multi-monitor-workspace";
        runtimeInputs = with pkgs; [hyprland jq];
        # Upstream's hl.dsp.* dispatcher calls work as-is now that we load a
        # .lua config; they used to need rewriting back to the classic names.
        text = builtins.readFile "${scriptDir}/multi_monitor_workspace.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-appearances";
        runtimeInputs = with pkgs; [hyprland gum];
        text =
          builtins.replaceStrings [
            ''              register 3 "Shadow Ignore Win"  "ignore_window|bool|shadow|||"          "true"
            ''
          ] [
            ""
          ] (builtins.readFile "${scriptDir}/old/dusky_appearances.sh");
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-input";
        runtimeInputs = with pkgs; [hyprland gum];
        text = builtins.readFile "${scriptDir}/old/dusky_input.sh";
      })
      (let
        python = pkgs.python3.withPackages (ps: with ps; [rich]);
      in
        pkgs.writeShellApplication {
          checkPhase = "";
          name = "dusky-keybinds";
          runtimeInputs = with pkgs; [hyprland fzf];
          text = ''exec ${python}/bin/python3 ${scriptDir}/input/dusky_keybinds.py "$@"'';
        })
      # dusky-monitor lives in tui-scripts.nix: monitor_wizard.py is a
      # dusky_tui schema now, not a standalone script.
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-window-rules";
        runtimeInputs = with pkgs; [hyprland gum jq wl-clipboard];
        text = builtins.readFile "${scriptDir}/old/dusky_window_rules.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-workspace-manager";
        runtimeInputs = with pkgs; [hyprland gum jq];
        text = builtins.readFile "${scriptDir}/old/dusky_workspace_manager.sh";
      })
    ];
  }
