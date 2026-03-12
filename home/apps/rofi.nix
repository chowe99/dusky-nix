{ config, pkgs, lib, dusky, ... }:

{
  # Deploy rofi config
  xdg.configFile."rofi/config.rasi".source = "${dusky}/.config/rofi/config.rasi";

  # Deploy wallpaper theme if it exists
  xdg.configFile."rofi/wallpaper.rasi".source = "${dusky}/.config/rofi/wallpaper.rasi";
}
