{ pkgs, dusky }:

let
  scriptDir = "${dusky}/user_scripts/theme_matugen";
  gtkDir = "${dusky}/user_scripts/gtk";
in
pkgs.symlinkJoin {
  name = "dusky-theme-scripts";
  paths = [
    (pkgs.writeShellApplication {
      name = "dusky-theme-ctl";
      runtimeInputs = with pkgs; [ swww matugen coreutils findutils gnugrep gawk procps ];
      text = builtins.readFile "${scriptDir}/theme_ctl.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-matugen-presets";
      runtimeInputs = with pkgs; [ matugen rofi coreutils ];
      text = builtins.readFile "${scriptDir}/dusky_matugen_presets.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-theme-favorites";
      runtimeInputs = with pkgs; [ coreutils ];
      text = builtins.readFile "${scriptDir}/theme_favorites_ctl.sh";
    })
    (pkgs.writeShellApplication {
      name = "dusky-papirus-folder-colors";
      runtimeInputs = with pkgs; [ python3 papirus-folders gsettings-desktop-schemas glib ];
      text = ''exec python3 ${gtkDir}/papirus_folder_colors.py "$@"'';
    })
  ];
}
