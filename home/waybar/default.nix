{ config, pkgs, lib, ... }:

{
  # Deploy all 15+ waybar theme directories
  xdg.configFile."waybar/themes" = {
    source = ./themes;
    recursive = true;
  };

  # Create runtime symlinks via activation
  # waybar_autostart.sh manages which theme is active by symlinking
  # config.jsonc and style.css to the waybar root
  home.activation.createWaybarSymlinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Set default waybar theme if no symlinks exist
    if [ ! -L "$HOME/.config/waybar/config.jsonc" ]; then
      run ln -snf "$HOME/.config/waybar/themes/01_horizontal_block/config.jsonc" "$HOME/.config/waybar/config.jsonc"
    fi
    if [ ! -L "$HOME/.config/waybar/style.css" ]; then
      run ln -snf "$HOME/.config/waybar/themes/01_horizontal_block/style.css" "$HOME/.config/waybar/style.css"
    fi
  '';
}
