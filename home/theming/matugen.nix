{ config, pkgs, lib, dusky, ... }:

let
  matugenSrc = "${dusky}/.config/matugen";
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

  home.packages = [ pkgs.matugen ];

  # Deploy default wallpaper from upstream dusky
  home.activation.deployWallpapers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/Pictures/wallpapers"
    if [ ! -f "$HOME/Pictures/wallpapers/dusk_default.jpg" ]; then
      run cp "${dusky}/Pictures/wallpapers/dusk_default.jpg" "$HOME/Pictures/wallpapers/"
    fi
  '';

  # Generate default matugen colors on first activation if none exist
  home.activation.createMatugenGenerated = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/matugen/generated"
    if [ ! -f "$HOME/.config/matugen/generated/rofi-colors.rasi" ]; then
      run ${pkgs.matugen}/bin/matugen \
        -c "$HOME/.config/matugen/config.toml" \
        --mode dark \
        image "${dusky}/Pictures/wallpapers/dusk_default.jpg" || true
    fi
  '';
}
