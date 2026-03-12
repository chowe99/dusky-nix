{ pkgs, dusky }:

let
  dusky-scripts = import ./dusky-scripts { inherit pkgs dusky; };
in
{
  inherit (dusky-scripts)
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
    dusky-misc-scripts;

  # Meta-package that pulls everything
  dusky-scripts-all = pkgs.symlinkJoin {
    name = "dusky-scripts-all";
    paths = builtins.attrValues dusky-scripts;
  };
}
