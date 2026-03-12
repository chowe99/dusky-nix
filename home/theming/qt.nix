{ config, pkgs, lib, dusky, ... }:

{
  # Qt5ct config
  xdg.configFile."qt5ct/qt5ct.conf".source =
    "${dusky}/.config/qt5ct/qt5ct.conf";

  # Qt6ct config
  xdg.configFile."qt6ct/qt6ct.conf".source =
    "${dusky}/.config/qt6ct/qt6ct.conf";
}
