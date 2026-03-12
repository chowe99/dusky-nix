{ config, pkgs, lib, ... }:

{
  # Deploy zed config
  xdg.configFile."zed" = {
    source = ../../dusky/.config/zed;
    recursive = true;
  };

  # Theme dir for matugen
  home.activation.createZedThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/zed/themes"
  '';
}
