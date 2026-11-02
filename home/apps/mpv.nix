{
  config,
  pkgs,
  lib,
  dusky,
  ...
}: let
  inherit (pkgs.mpvScripts) uosc thumbfast;
in {
  # Deploy mpv config.
  xdg.configFile."mpv/mpv.conf".source = "${dusky}/.config/mpv/mpv.conf";

  # The conf sets osc=no for uosc (Arch ships it as mpv-uosc/mpv-thumbfast);
  # without the scripts mpv has no controls at all. Installed as config
  # files rather than an mpv override so they work with any mpv package.
  xdg.configFile."mpv/scripts/uosc".source = "${uosc}/share/mpv/scripts/uosc";
  xdg.configFile."mpv/scripts/thumbfast.lua".source = "${thumbfast}/share/mpv/scripts/thumbfast.lua";
  xdg.configFile."mpv/fonts/uosc_icons.otf".source = "${uosc}/share/fonts/opentype/uosc_icons.otf";
  xdg.configFile."mpv/fonts/uosc_textures.ttf".source = "${uosc}/share/fonts/truetype/uosc_textures.ttf";

  # The app this config is for, unless the user already configures it.
  home.packages = lib.optional (!config.programs.mpv.enable) pkgs.mpv;
}
