{ config, pkgs, lib, ... }:

{
  # Deploy mpv config
  xdg.configFile."mpv/mpv.conf".source = ../../dusky/.config/mpv/mpv.conf;
}
