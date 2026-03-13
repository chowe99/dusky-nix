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

  # Create mutable generated/ directory and default color file via activation
  home.activation.createMatugenGenerated = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/matugen/generated"
    if [ ! -f "$HOME/.config/matugen/generated/hyprland-colors.conf" ]; then
      cat > "$HOME/.config/matugen/generated/hyprland-colors.conf" << 'COLORS'
# Default Matugen colors (run matugen to generate from wallpaper)
$primary = rgb(89b4fa)
$on_primary = rgb(1e1e2e)
$primary_container = rgb(313244)
$on_primary_container = rgb(cdd6f4)
$secondary = rgb(a6adc8)
$on_secondary = rgb(1e1e2e)
$tertiary = rgb(f5c2e7)
$on_tertiary = rgb(1e1e2e)
$error = rgb(f38ba8)
$on_error = rgb(1e1e2e)
$background = rgb(1e1e2e)
$on_background = rgb(cdd6f4)
$surface = rgb(1e1e2e)
$on_surface = rgb(cdd6f4)
$inverse_surface = rgb(cdd6f4)
$inverse_on_surface = rgb(1e1e2e)
$outline = rgb(6c7086)
$shadow = rgb(11111b)
COLORS
    fi
  '';
}
