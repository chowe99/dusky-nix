{ config, pkgs, lib, ... }:

let
  # Patch waybar theme configs to replace hardcoded $HOME/user_scripts/ paths
  # with Nix-packaged binary names (same substitutions as control-center.nix)
  patchedThemes = pkgs.runCommand "dusky-waybar-themes-patched" {} ''
    cp -r ${./themes} $out
    chmod -R u+w $out

    # Replace hardcoded paths with Nix-packaged binary names
    find $out -name '*.jsonc' -exec sed -i \
      -e 's|\$HOME/user_scripts/battery/power_saving/power_saver.sh|dusky-power-saver|g' \
      -e 's|\$HOME/user_scripts/battery/power_saving_off/power_saver_off.sh|dusky-power-saver-off|g' \
      -e 's|\$HOME/user_scripts/hypridle/dusky_hypridle.sh|dusky-hypridle|g' \
      -e 's|\$HOME/user_scripts/hyprlock/lock.sh|dusky-lock|g' \
      -e 's|\$HOME/user_scripts/performance/sysbench_benchmark.sh|dusky-sysbench|g' \
      -e 's|\$HOME/user_scripts/rofi/shader_menu.sh|dusky-rofi-shader|g' \
      -e 's|\$HOME/user_scripts/wlogout/wlogout_scale.sh|dusky-wlogout-scale|g' \
      -e 's|\$HOME/user_scripts/audio/router/audio_routing_output_to_mic.py|dusky-mono-audio|g' \
      {} +
  '';
in
{
  # Deploy all 15+ waybar theme directories (patched for NixOS)
  xdg.configFile."waybar/themes" = {
    source = patchedThemes;
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
