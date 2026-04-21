{ pkgs, dusky }:

{
  dusky-hypr-scripts = import ./hypr-scripts.nix { inherit pkgs dusky; };
  dusky-theme-scripts = import ./theme-scripts.nix { inherit pkgs dusky; };
  dusky-waybar-scripts = import ./waybar-scripts.nix { inherit pkgs dusky; };
  dusky-rofi-scripts = import ./rofi-scripts.nix { inherit pkgs dusky; };
  dusky-audio-scripts = import ./audio-scripts.nix { inherit pkgs dusky; };
  dusky-battery-scripts = import ./battery-scripts.nix { inherit pkgs dusky; };
  dusky-drive-scripts = import ./drive-scripts.nix { inherit pkgs dusky; };
  dusky-screenshot-scripts = import ./screenshot-scripts.nix { inherit pkgs dusky; };
  dusky-slider-scripts = import ./slider-scripts.nix { inherit pkgs dusky; };
  dusky-control-center = import ./control-center.nix { inherit pkgs dusky; };
  dusky-network-scripts = import ./network-scripts.nix { inherit pkgs dusky; };
  dusky-mako-scripts = import ./mako-scripts.nix { inherit pkgs dusky; };
  dusky-misc-scripts = import ./misc-scripts.nix { inherit pkgs dusky; };
}
