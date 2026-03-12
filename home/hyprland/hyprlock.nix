{ config, pkgs, lib, ... }:

{
  # Deploy hyprlock.conf (sources the active theme)
  xdg.configFile."hypr/hyprlock.conf".text = ''
    source = ~/.config/hypr/hyprlock_themes/006_stacked_clock/hyprlock.conf
  '';
}
