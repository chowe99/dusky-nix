{
  pkgs,
  dusky,
}: let
  scriptDir = "${dusky}/user_scripts/rofi";
  inputDir = "${dusky}/user_scripts/hypr/input";
  keybindsCheatsheet = pkgs.writeShellApplication {
    checkPhase = "";
    name = "dusky-keybinds-cheatsheet";
    runtimeInputs = [(pkgs.python3.withPackages (ps: [ps.rich])) pkgs.hyprland];
    text = ''exec python3 ${inputDir}/keybinds_cheatsheet.py "$@"'';
  };
in
  pkgs.symlinkJoin {
    name = "dusky-rofi-scripts";
    paths = [
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-rofi-emoji";
        runtimeInputs = with pkgs; [rofi wl-clipboard wtype libnotify];
        text = builtins.readFile "${scriptDir}/emoji.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-rofi-calculator";
        runtimeInputs = with pkgs; [rofi wl-clipboard libqalculate libnotify];
        text = builtins.readFile "${scriptDir}/calculator.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-rofi-cliphist";
        runtimeInputs = with pkgs; [rofi cliphist wl-clipboard imagemagick];
        # Upstream renamed rofi_cliphist.sh → rofi_clipboard.sh.
        text = builtins.readFile "${scriptDir}/rofi_clipboard.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-rofi-wallpaper";
        runtimeInputs = with pkgs; [rofi awww matugen coreutils findutils gawk imagemagick util-linux hyprland jq libnotify uwsm];
        text =
          builtins.replaceStrings
          [
            ''readonly THEME_CTL="''${HOME}/user_scripts/theme_matugen/theme_ctl.sh"''
            ''[[ ! -x "$THEME_CTL" ]]''
          ]
          [
            ''readonly THEME_CTL="dusky-theme-ctl"''
            ''! command -v "$THEME_CTL" >/dev/null 2>&1''
          ]
          (builtins.readFile "${scriptDir}/rofi_wallpaper_selctor.sh");
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-rofi-theme";
        runtimeInputs = with pkgs; [rofi matugen libnotify];
        # nix-compat: upstream hardcodes $HOME/user_scripts/theme_matugen/theme_ctl.sh
        # (fatal "Controller script missing/non-executable" on NixOS). Point at our
        # packaged binary + relax the file/exec test to a PATH lookup (same as the
        # dusky-rofi-wallpaper patch above).
        text =
          builtins.replaceStrings
          [
            ''readonly THEME_CTL="''${HOME}/user_scripts/theme_matugen/theme_ctl.sh"''
            ''[[ -f $THEME_CTL && -x $THEME_CTL ]]''
          ]
          [
            ''readonly THEME_CTL="dusky-theme-ctl"''
            ''command -v "$THEME_CTL" >/dev/null 2>&1''
          ]
          (builtins.readFile "${scriptDir}/rofi_theme.sh");
      })
      # Upstream moved the keybind menu to hypr/input/rofi_keybinds/, split
      # into keybindings.sh + a Python categorizer + a luajit dispatcher for
      # Lua-function binds, with a rich cheatsheet as the first row. The
      # helpers are read from the store copy instead of ~/user_scripts.
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-rofi-keybindings";
        runtimeInputs = with pkgs; [rofi hyprland gawk libxkbcommon jq luajit python3 libnotify kitty keybindsCheatsheet];
        text =
          builtins.replaceStrings
          ["\${HOME}/user_scripts/hypr/input/" "-e python3.14 \${script_path}"]
          ["${inputDir}/" "-e dusky-keybinds-cheatsheet"]
          (builtins.readFile "${inputDir}/rofi_keybinds/keybindings.sh");
      })
      keybindsCheatsheet
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-rofi-powermenu";
        runtimeInputs = with pkgs; [rofi systemd hyprlock uwsm];
        text = builtins.readFile "${scriptDir}/powermenu.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-rofi-shader";
        runtimeInputs = with pkgs; [rofi hyprland hyprshade util-linux libnotify];
        text = builtins.readFile "${scriptDir}/shader_menu.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-rofi-animations";
        runtimeInputs = with pkgs; [rofi hyprland libnotify];
        text = builtins.readFile "${scriptDir}/hypr_anim.sh";
      })
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-rofi-mako";
        runtimeInputs = with pkgs; [rofi mako jq libnotify coreutils hyprland gtk3 uwsm];
        text = builtins.readFile "${scriptDir}/rofi_mako.sh";
      })
    ];
  }
