{ pkgs }:

{
  dusky-hypr-scripts = import ./hypr-scripts.nix { inherit pkgs; };
  dusky-theme-scripts = import ./theme-scripts.nix { inherit pkgs; };
  dusky-waybar-scripts = import ./waybar-scripts.nix { inherit pkgs; };
  dusky-rofi-scripts = import ./rofi-scripts.nix { inherit pkgs; };
  dusky-audio-scripts = import ./audio-scripts.nix { inherit pkgs; };
  dusky-battery-scripts = import ./battery-scripts.nix { inherit pkgs; };
  dusky-drive-scripts = import ./drive-scripts.nix { inherit pkgs; };
  dusky-screenshot-scripts = import ./screenshot-scripts.nix { inherit pkgs; };
  dusky-slider-scripts = import ./slider-scripts.nix { inherit pkgs; };
  dusky-control-center = import ./control-center.nix { inherit pkgs; };
  dusky-network-scripts = import ./network-scripts.nix { inherit pkgs; };
  dusky-misc-scripts = import ./misc-scripts.nix { inherit pkgs; };
}
