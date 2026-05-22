{ pkgs, dusky }:

let
  scriptDir = "${dusky}/user_scripts/hypr";
  mkScript = name: src: deps:
    pkgs.writeShellScriptBin name ''
      export PATH="${pkgs.lib.makeBinPath deps}:$PATH"
      exec ${src} "$@"
    '';
in
pkgs.symlinkJoin {
  name = "dusky-hypr-scripts";
  paths = [
    (let python = pkgs.python3.withPackages (ps: with ps; [ ]); in
    pkgs.writeScriptBin "dusky-adjust-scale" ''
      #!${python}/bin/python3
      ${builtins.readFile "${scriptDir}/monitor/adjust_scale.py"}
    '')
    (let python = pkgs.python3.withPackages (ps: with ps; [ ]); in
    pkgs.writeScriptBin "dusky-screen-rotate" ''
      #!${python}/bin/python3
      ${builtins.readFile "${scriptDir}/monitor/screen_rotate.py"}
    '')
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-blur-toggle";
      runtimeInputs = with pkgs; [ hyprland jq libnotify ];
      text = builtins.readFile "${scriptDir}/hypr_blur_opacity_shadow_toggle.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-multi-monitor-workspace";
      runtimeInputs = with pkgs; [ hyprland jq ];
      # Upstream rewrote the dispatcher calls for Hyprland 0.55+ Lua-mode configs:
      #   hyprctl dispatch "hl.dsp.focus({ workspace = \"N\" })"
      # That syntax is only valid when Hyprland is loaded with a .lua config.
      # Our deployed config is the traditional hyprland.conf format, so the
      # Lua dispatchers come back as "Invalid dispatcher" and SUPER+N does
      # nothing. Substitute back to the classic dispatcher names.
      text = builtins.replaceStrings [
        ''hyprctl dispatch "hl.dsp.focus({ workspace = \"''${target_ws}\" })"''
        ''hyprctl dispatch "hl.dsp.window.move({ workspace = \"''${target_ws}\" })"''
        ''hyprctl dispatch \
            "hl.dsp.window.move({ workspace = \"''${target_ws}\", follow = false })"''
      ] [
        ''hyprctl dispatch workspace "''${target_ws}"''
        ''hyprctl dispatch movetoworkspace "''${target_ws}"''
        ''hyprctl dispatch movetoworkspacesilent "''${target_ws}"''
      ] (builtins.readFile "${scriptDir}/multi_monitor_workspace.sh");
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-appearances";
      runtimeInputs = with pkgs; [ hyprland gum ];
      text = builtins.replaceStrings [
        ''    register 3 "Shadow Ignore Win"  "ignore_window|bool|shadow|||"          "true"
''
      ] [
        ""
      ] (builtins.readFile "${scriptDir}/old/dusky_appearances.sh");
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-input";
      runtimeInputs = with pkgs; [ hyprland gum ];
      text = builtins.readFile "${scriptDir}/old/dusky_input.sh";
    })
    (let python = pkgs.python3.withPackages (ps: with ps; [ ]); in
    pkgs.writeScriptBin "dusky-keybinds" ''
      #!${python}/bin/python3
      ${builtins.readFile "${scriptDir}/input/dusky_keybinds.py"}
    '')
    (let python = pkgs.python3.withPackages (ps: with ps; [ ]); in
    pkgs.writeScriptBin "dusky-monitor" ''
      #!${python}/bin/python3
      ${builtins.readFile "${scriptDir}/monitor/monitor_wizard.py"}
    '')
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-window-rules";
      runtimeInputs = with pkgs; [ hyprland gum ];
      text = builtins.readFile "${scriptDir}/old/dusky_window_rules.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-workspace-manager";
      runtimeInputs = with pkgs; [ hyprland gum jq ];
      text = builtins.readFile "${scriptDir}/old/dusky_workspace_manager.sh";
    })
  ];
}
