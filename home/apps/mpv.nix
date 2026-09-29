{
  config,
  pkgs,
  lib,
  dusky,
  ...
}: {
  # Deploy mpv config
  xdg.configFile."mpv/mpv.conf".source = "${dusky}/.config/mpv/mpv.conf";

  # The app this config is for, unless the user already configures it.
  home.packages = lib.optional (!config.programs.mpv.enable) pkgs.mpv;
}
