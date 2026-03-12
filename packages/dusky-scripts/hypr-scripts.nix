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
      ${builtins.readFile "${scriptDir}/adjust_scale.py"}
    '')
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-screen-rotate";
      runtimeInputs = with pkgs; [ hyprland jq ];
      text = builtins.readFile "${scriptDir}/screen_rotate.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-blur-toggle";
      runtimeInputs = with pkgs; [ hyprland jq libnotify ];
      text = builtins.readFile "${scriptDir}/hypr_blur_opacity_shadow_toggle.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-multi-monitor-workspace";
      runtimeInputs = with pkgs; [ hyprland jq ];
      text = builtins.readFile "${scriptDir}/multi_monitor_workspace.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-appearances";
      runtimeInputs = with pkgs; [ hyprland gum ];
      text = builtins.readFile "${scriptDir}/dusky_appearances.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-input";
      runtimeInputs = with pkgs; [ hyprland gum ];
      text = builtins.readFile "${scriptDir}/dusky_input.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-keybinds";
      runtimeInputs = with pkgs; [ hyprland gum ];
      text = builtins.readFile "${scriptDir}/dusky_keybinds.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-monitor";
      runtimeInputs = with pkgs; [ hyprland gum jq ];
      text = builtins.readFile "${scriptDir}/dusky_monitor.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-window-rules";
      runtimeInputs = with pkgs; [ hyprland gum ];
      text = builtins.readFile "${scriptDir}/dusky_window_rules.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-workspace-manager";
      runtimeInputs = with pkgs; [ hyprland gum jq ];
      text = builtins.readFile "${scriptDir}/dusky_workspace_manager.sh";
    })
  ];
}
