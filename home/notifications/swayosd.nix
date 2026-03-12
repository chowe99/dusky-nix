{ config, pkgs, lib, ... }:

{
  # Swayosd config
  xdg.configFile."swayosd/config.toml".text = ''
    [server]
    show_percentage = true
    max_volume = 100
    style = "style.css"
  '';

  # Swayosd style
  xdg.configFile."swayosd/style.css".source = ../../dusky/.config/swayosd/style.css;
}
