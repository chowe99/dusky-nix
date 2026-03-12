{ config, pkgs, lib, dusky, ... }:

{
  # Deploy cava config
  xdg.configFile."cava/config".source = "${dusky}/.config/cava/config";

  # Theme dir for matugen-generated colors
  home.activation.createCavaThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/cava/themes"
  '';
}
