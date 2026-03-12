{ config, pkgs, lib, ... }:

{
  # Deploy waypaper config if it exists
  xdg.configFile."waypaper" = {
    source = ../../dusky/.config/waypaper;
    recursive = true;
  };
}
