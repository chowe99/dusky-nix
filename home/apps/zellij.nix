{ config, pkgs, lib, dusky, ... }:

{
  # Deploy zellij config
  xdg.configFile."zellij" = {
    source = "${dusky}/.config/zellij";
    recursive = true;
  };
}
