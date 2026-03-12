{ config, pkgs, lib, ... }:

{
  # Alacritty config — imports matugen-generated colors
  xdg.configFile."alacritty/alacritty.toml".text = ''
    general.import = ["alacritty-colors.toml"]
  '';
}
