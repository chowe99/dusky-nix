{
  pkgs,
  dusky,
}: let
  scriptDir = "${dusky}/user_scripts/hypr";
in
  pkgs.symlinkJoin {
    name = "dusky-hypr-scripts";
    paths = [
      # Upstream's app launcher (v6), which its keybinds, rofi config and
      # waybar configs now call as `dusky-run <cmd>`. Arch deploys it to
      # /usr/local/bin from arch_iso_scripts/offline_iso/165_deploy_dusky_run.py,
      # where it lives as an embedded string, hence copied here rather than
      # read. Runs the command in a transient app.slice scope with a raised
      # OOM score, so an OOM kill takes the app and not the session.
      # systemd-run is the system's (it must match the running user manager).
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-run";
        runtimeInputs = [];
        text = ''
          # Upstream callers mix `dusky-run cmd` and `dusky-run -- cmd`; a second
          # `--` makes systemd-run exec a binary literally named "--".
          if [[ ''${1:-} == -- ]]; then shift; fi
          if [[ $# -eq 0 ]]; then
            echo "usage: dusky-run <cmd> [args...]" >&2
            exit 1
          fi
          if ! printf '%d\n' 200 >/proc/self/oom_score_adj 2>/dev/null; then
            echo "dusky-run: warning: cannot set oom_score_adj" >&2
          fi
          exec systemd-run --user --scope --slice=app.slice --collect \
            --property=OOMPolicy=continue \
            --property=ManagedOOMPreference=none \
            --property=MemoryAccounting=yes \
            -- "$@"
        '';
      })
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
