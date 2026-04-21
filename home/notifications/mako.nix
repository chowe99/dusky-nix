{ config, pkgs, lib, dusky, ... }:

{
  # Mako notification daemon config
  xdg.configFile."mako/config".source = "${dusky}/.config/mako/config";
}
