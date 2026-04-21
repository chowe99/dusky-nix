{ config, pkgs, lib, dusky, ... }:

let
  # Source waybar themes from upstream dusky, patch hardcoded paths at build time
  patchedThemes = pkgs.runCommand "dusky-waybar-themes-patched" {} ''
    cp -r ${dusky}/.config/waybar $out
    chmod -R u+w $out

    # Replace hardcoded paths with Nix-packaged binary names
    find $out -name '*.jsonc' -exec sed -i \
      -e 's|python3 ~/user_scripts/dusky_system/control_center/dusky_control_center.py|dusky-control-center|g' \
      -e 's|\$HOME/user_scripts/battery/power_saving/power_saver.sh|dusky-power-saver|g' \
      -e 's|\$HOME/user_scripts/battery/power_saving_off/power_saver_off.sh|dusky-power-saver-off|g' \
      -e 's|~/user_scripts/waybar/toggle_hypridle.sh|dusky-toggle-hypridle|g' \
      -e 's|\$HOME/user_scripts/hypridle/dusky_hypridle.sh|dusky-hypridle|g' \
      -e 's|\$HOME/user_scripts/hyprlock/lock.sh|dusky-lock|g' \
      -e 's|~/user_scripts/hyprlock/lock.sh|dusky-lock|g' \
      -e 's|\$HOME/user_scripts/performance/sysbench_benchmark.sh|dusky-sysbench|g' \
      -e 's|~/user_scripts/rofi/shader_menu.sh|dusky-rofi-shader|g' \
      -e 's|\$HOME/user_scripts/rofi/shader_menu.sh|dusky-rofi-shader|g' \
      -e 's|~/user_scripts/wlogout/wlogout_scale.sh|dusky-wlogout-scale|g' \
      -e 's|\$HOME/user_scripts/wlogout/wlogout_scale.sh|dusky-wlogout-scale|g' \
      -e 's|\$HOME/user_scripts/audio/router/audio_routing_output_to_mic.py|dusky-mono-audio|g' \
      -e 's|~/user_scripts/waybar/mako.sh|dusky-waybar-mako|g' \
      -e 's|~/user_scripts/rofi/rofi_mako.sh|dusky-rofi-mako|g' \
      -e 's|~/user_scripts/waybar/waybar_autostart.sh|dusky-waybar-autostart|g' \
      -e 's|\$HOME/user_scripts/waybar/network/network_meter_calling.sh|dusky-waybar-network-meter|g' \
      -e 's|~/user_scripts/waybar/network/network_meter_calling.sh|dusky-waybar-network-meter|g' \
      -e 's|~/user_scripts/theme_matugen/theme_ctl.sh|dusky-theme-ctl|g' \
      -e 's|\$HOME/user_scripts/theme_matugen/theme_ctl.sh|dusky-theme-ctl|g' \
      -e 's|~/user_scripts/sliders/dusky_sliders.py|dusky-sliders|g' \
      -e 's|\$HOME/user_scripts/sliders/dusky_sliders.py|dusky-sliders|g' \
      -e 's|~/user_scripts/drives/io_monitor.sh|dusky-io-monitor|g' \
      -e 's|\$HOME/user_scripts/drives/io_monitor.sh|dusky-io-monitor|g' \
      -e 's|~/user_scripts/waybar/update_counter.sh|dusky-waybar-update-counter|g' \
      -e 's|\$HOME/user_scripts/waybar/update_counter.sh|dusky-waybar-update-counter|g' \
      -e 's|pactl set-sink-mute @DEFAULT_SINK@ toggle|dusky-osd-router --vol-mute|g' \
      -e 's|pactl set-sink-volume @DEFAULT_SINK@ +5%|dusky-osd-router --vol-up 5|g' \
      -e 's|pactl set-sink-volume @DEFAULT_SINK@ -5%|dusky-osd-router --vol-down 5|g' \
      -e 's|brightnessctl set +5%|dusky-osd-router --bright-up 5|g' \
      -e 's|brightnessctl set 5%-|dusky-osd-router --bright-down 5|g' \
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
