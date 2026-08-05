{
  pkgs,
  dusky,
}: let
  dusky-scripts = import ./dusky-scripts {inherit pkgs dusky;};

  # Meta-package that pulls everything
  dusky-scripts-all = pkgs.symlinkJoin {
    name = "dusky-scripts-all";
    paths = builtins.attrValues dusky-scripts;
  };
in {
  inherit
    (dusky-scripts)
    dusky-hypr-scripts
    dusky-theme-scripts
    dusky-waybar-scripts
    dusky-rofi-scripts
    dusky-audio-scripts
    dusky-battery-scripts
    dusky-drive-scripts
    dusky-screenshot-scripts
    dusky-slider-scripts
    dusky-control-center
    dusky-network-scripts
    dusky-mako-scripts
    dusky-misc-scripts
    dusky-tui-scripts
    ;

  inherit dusky-scripts-all;

  # Upstream's ~/user_scripts/ layout, symlinked to our packaged binaries.
  # Lets the upstream Hyprland .lua config deploy verbatim.
  dusky-user-scripts = import ./user-scripts.nix {
    inherit pkgs dusky-scripts-all;
  };
}
