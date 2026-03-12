{ config, pkgs, lib, dusky, ... }:

{
  # Deploy waypaper config if it exists
  xdg.configFile."waypaper" = {
    source = "${dusky}/.config/waypaper";
    recursive = true;
  };
}
