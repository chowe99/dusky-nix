{ pkgs, dusky }:

let
  scriptDir = "${dusky}/user_scripts/rofi";
in
pkgs.symlinkJoin {
  name = "dusky-rofi-scripts";
  paths = [
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-rofi-emoji";
      runtimeInputs = with pkgs; [ rofi wl-clipboard wtype ];
      text = builtins.readFile "${scriptDir}/emoji.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-rofi-calculator";
      runtimeInputs = with pkgs; [ rofi wl-clipboard ];
      text = builtins.readFile "${scriptDir}/calculator.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-rofi-cliphist";
      runtimeInputs = with pkgs; [ rofi cliphist wl-clipboard ];
      text = builtins.readFile "${scriptDir}/rofi_cliphist.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-rofi-wallpaper";
      runtimeInputs = with pkgs; [ rofi swww matugen coreutils findutils gawk imagemagick util-linux ];
      text = builtins.replaceStrings
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
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-rofi-theme";
      runtimeInputs = with pkgs; [ rofi matugen ];
      text = builtins.readFile "${scriptDir}/rofi_theme.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-rofi-keybindings";
      runtimeInputs = with pkgs; [ rofi hyprland gnugrep gawk libxkbcommon jq ];
      text = builtins.readFile "${scriptDir}/keybindings.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-rofi-powermenu";
      runtimeInputs = with pkgs; [ rofi systemd ];
      text = builtins.readFile "${scriptDir}/powermenu.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-rofi-shader";
      runtimeInputs = with pkgs; [ rofi hyprland ];
      text = builtins.readFile "${scriptDir}/shader_menu.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-rofi-animations";
      runtimeInputs = with pkgs; [ rofi hyprland ];
      text = builtins.readFile "${scriptDir}/hypr_anim.sh";
    })
  ];
}
