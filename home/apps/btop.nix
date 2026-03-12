{ config, pkgs, lib, dusky, ... }:

{
  # Deploy btop config
  xdg.configFile."btop/btop.conf".source = "${dusky}/.config/btop/btop.conf";

  # Theme dir for matugen-generated theme
  home.activation.createBtopThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/btop/themes"
  '';
}
