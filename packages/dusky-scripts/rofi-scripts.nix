{ pkgs }:

let
  scriptDir = ../../assets/scripts/rofi;
in
pkgs.symlinkJoin {
  name = "dusky-rofi-scripts";
  paths = [
    (pkgs.writeShellApplication {
      name = "dusky-rofi-emoji";
      runtimeInputs = with pkgs; [ rofi-wayland wl-clipboard wtype ];
      text = builtins.readFile "${scriptDir}/emoji.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-rofi-calculator";
      runtimeInputs = with pkgs; [ rofi-wayland wl-clipboard ];
      text = builtins.readFile "${scriptDir}/calculator.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-rofi-cliphist";
      runtimeInputs = with pkgs; [ rofi-wayland cliphist wl-clipboard ];
      text = builtins.readFile "${scriptDir}/rofi_cliphist.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-rofi-wallpaper";
      runtimeInputs = with pkgs; [ rofi-wayland swww matugen coreutils ];
      text = builtins.readFile "${scriptDir}/rofi_wallpaper_selctor.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-rofi-theme";
      runtimeInputs = with pkgs; [ rofi-wayland matugen ];
      text = builtins.readFile "${scriptDir}/rofi_theme.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-rofi-keybindings";
      runtimeInputs = with pkgs; [ rofi-wayland hyprland gnugrep gawk ];
      text = builtins.readFile "${scriptDir}/keybindings.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-rofi-powermenu";
      runtimeInputs = with pkgs; [ rofi-wayland systemd ];
      text = builtins.readFile "${scriptDir}/powermenu.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-rofi-shader";
      runtimeInputs = with pkgs; [ rofi-wayland hyprland ];
      text = builtins.readFile "${scriptDir}/shader_menu.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-rofi-animations";
      runtimeInputs = with pkgs; [ rofi-wayland hyprland ];
      text = builtins.readFile "${scriptDir}/hypr_anim.sh";
    })
  ];
}
