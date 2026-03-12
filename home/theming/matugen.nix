{ config, pkgs, lib, ... }:

let
  dusky = ../..;
  matugenSrc = "${dusky}/dusky/.config/matugen";
in
{
  # Deploy matugen config.toml with patched post_hooks
  # Post hooks use packaged script names on $PATH instead of ~/user_scripts/...
  xdg.configFile."matugen/config.toml".source = ./matugen-config.toml;

  # Deploy all templates
  xdg.configFile."matugen/templates" = {
    source = "${matugenSrc}/templates";
    recursive = true;
  };

  # Deploy all presets
  xdg.configFile."matugen/presets" = {
    source = "${matugenSrc}/presets";
    recursive = true;
  };

  # Create mutable generated/ directory via activation
  home.activation.createMatugenGenerated = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/matugen/generated"
  '';
}
