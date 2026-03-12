{ config, pkgs, lib, dusky, ... }:

{
  # Deploy fastfetch config
  xdg.configFile."fastfetch" = {
    source = "${dusky}/.config/fastfetch";
    recursive = true;
  };
}
