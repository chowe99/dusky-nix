{ config, pkgs, lib, ... }:

{
  # Deploy zellij config
  xdg.configFile."zellij" = {
    source = ../../dusky/.config/zellij;
    recursive = true;
  };
}
