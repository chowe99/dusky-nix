# Mirror of upstream dusky's ~/user_scripts/ tree, with every script that we
# package natively replaced by a symlink to its dusky-* binary.
#
# This lets upstream's .lua config files be deployed verbatim: they all resolve
# scripts through `dusky_scripts .. "some/path.sh"`, so pointing dusky_scripts
# at this tree is enough — no per-path sed patching of the config.
#
# ponytail: paths upstream references but we don't package simply don't exist
# here, exactly as before. Add a mapping when you package the script.
{
  pkgs,
  dusky-scripts-all,
}: let
  shims = {
    "arch_setup_scripts/scripts/006_animation_default.sh" = "dusky-animation-default";
    "arch_setup_scripts/scripts/020_desktop_apps_username_setter.sh" = "dusky-desktop-apps-fix";
    "arch_setup_scripts/scripts/135_battery_notify_service.sh" = "dusky-battery-notify";
    "arch_setup_scripts/scripts/150_wallpapers_download.sh" = "dusky-wallpaper-download";
    "arch_setup_scripts/scripts/235_file_manager_switch.sh" = "dusky-file-manager-switch";
    "arch_setup_scripts/scripts/236_browser_switcher.sh" = "dusky-browser-switch";
    "arch_setup_scripts/scripts/237_text_editer_switcher.sh" = "dusky-editor-switch";
    "arch_setup_scripts/scripts/238_terminal_switcher.sh" = "dusky-terminal-switch";
    "arch_setup_scripts/scripts/265_mouse_button_reverse.sh" = "dusky-mouse-reverse";
    "arch_setup_scripts/scripts/305_new_github_repo_to_backup.sh" = "dusky-github-backup-new";
    "arch_setup_scripts/scripts/310_reconnect_and_push_new_changes_to_github.sh" = "dusky-github-backup-sync";
    "arch_setup_scripts/scripts/325_hosts_files_block.sh" = "dusky-hosts-blocker";
    "arch_setup_scripts/scripts/375_cursor_theme_bibata_classic_modern.sh" = "dusky-cursor-bibata";
    "arch_setup_scripts/scripts/390_clipboard_persistance.sh" = "dusky-clipboard-persistence";
    "arch_setup_scripts/scripts/460_switch_clipboard.sh" = "dusky-clipboard-switch";
    "asus/asusctl.sh" = "dusky-asus-control";
    "audio/dusky_input.sh" = "dusky-mic-switch";
    "audio/dusky_output.sh" = "dusky-audio-switch";
    "audio/mono_audio_pipewire.py" = "dusky-mono-audio";
    "audio/router/TTS_VC.sh" = "dusky-voice-assistant";
    "battery/notify/dusky_battery_notify.sh" = "dusky-battery-notify";
    "battery/power_saver.sh" = "dusky-power-saver";
    "drives/btrfs_zstd_compression_stats.sh" = "dusky-btrfs-stats";
    "drives/drive_manager.sh" = "dusky-drive-manager";
    "drives/drive_manager/drive_manager.py" = "dusky-drive-manager";
    "drives/dusky_disk_monitor_io.py" = "dusky-io-monitor";
    "drives/ntfs_fix.sh" = "dusky-ntfs-fix";
    "dusky_tui/python/main/main.py" = "dusky-tui";
    "external/usb_sound_toggle.py" = "dusky-usb-sound";
    "firefox/400_firefox_matugen_pywalfox.sh" = "dusky-firefox-matugen";
    "google_image_search/google_image_search.sh" = "dusky-google-image-search";
    "gtk/dusky_gsettings.sh" = "dusky-gsettings";
    "gtk/papirus_folder_colors.py" = "dusky-papirus-folder-colors";
    "hypr/hypr_blur_opacity_shadow_toggle.sh" = "dusky-blur-toggle";
    "hypr/input/dusky_keybinds.py" = "dusky-keybinds";
    "hypr/monitor/adjust_scale.py" = "dusky-adjust-scale";
    "hypr/monitor/monitor_wizard.py" = "dusky-monitor";
    "hypr/monitor/screen_rotate.py" = "dusky-screen-rotate";
    "hypr/multi_monitor_workspace.sh" = "dusky-multi-monitor-workspace";
    "hypr/old/dusky_appearances.sh" = "dusky-appearances";
    "hypr/old/dusky_input.sh" = "dusky-input";
    "hypr/old/dusky_window_rules.sh" = "dusky-window-rules";
    "hypr/old/dusky_workspace_manager.sh" = "dusky-workspace-manager";
    "hypr/rules/window_rules_generator.py" = "dusky-window-rules-gen";
    "hypridle/dusky_hypridle.sh" = "dusky-hypridle";
    "hyprlock/battery_status.sh" = "dusky-hyprlock-battery";
    "hyprlock/check_capslock.sh" = "dusky-hyprlock-capslock";
    "hyprlock/dusky_hyprlock_switcher.sh" = "dusky-hyprlock-switcher";
    "hyprlock/lock.sh" = "dusky-lock";
    "images/dusky_screenshot.sh" = "dusky-screenshot";
    "llm/ollama_terminal.sh" = "dusky-ollama-terminal";
    "locale/locale_tui.sh" = "dusky-locale-tui";
    "mako_osd/mako_tui/tui_mako.py" = "dusky-mako-tui";
    "mako_osd/osd_router/osd_router.py" = "dusky-mako-osd-daemon";
    "mako_osd/osd_router/osd_router.sh" = "dusky-osd-router";
    "music/music_recognition.sh" = "dusky-music-recognition";
    "network_manager/dusky_network.sh" = "dusky-network";
    "networking/arp_scan.sh" = "dusky-arp-scan";
    "networking/dusky_wireguard_new.sh" = "dusky-wireguard-new";
    "networking/dusky_wireguard_setup.sh" = "dusky-wireguard-setup";
    "networking/warp_toggle.sh" = "dusky-warp-toggle";
    "nvim/dusky_neovim_manager.sh" = "dusky-neovim-manager";
    "nvim/reset/01_reset_neovim.sh" = "dusky-reset-neovim";
    "nvim/reset/02_cli_plugins_download.sh" = "dusky-neovim-plugins";
    "performance/services_and_process_terminator.sh" = "dusky-process-terminator";
    "performance/sysbench_benchmark.sh" = "dusky-sysbench";
    "power/dusky_power.sh" = "dusky-power";
    "rofi/calculator.sh" = "dusky-rofi-calculator";
    "rofi/emoji.sh" = "dusky-rofi-emoji";
    "rofi/hypr_anim.sh" = "dusky-rofi-animations";
    "rofi/keybindings.sh" = "dusky-rofi-keybindings";
    "rofi/powermenu.sh" = "dusky-rofi-powermenu";
    "rofi/rofi_cliphist.sh" = "dusky-rofi-cliphist";
    "rofi/rofi_mako.sh" = "dusky-rofi-mako";
    "rofi/rofi_theme.sh" = "dusky-rofi-theme";
    "rofi/rofi_wallpaper_selctor.sh" = "dusky-rofi-wallpaper";
    "rofi/shader_menu.sh" = "dusky-rofi-shader";
    "services/dusky_service_manager.sh" = "dusky-service-toggle";
    "spotify/spotify_toggle.sh" = "dusky-spotify-toggle";
    "theme_matugen/dusky_matugen_presets.sh" = "dusky-matugen-presets";
    "theme_matugen/theme_ctl.sh" = "dusky-theme-ctl";
    "theme_matugen/theme_favorites_ctl.sh" = "dusky-theme-favorites";
    "tts_stt/dusky_kokoro/trigger.sh" = "dusky-kokoro-tts";
    "tts_stt/dusky_parakeet/trigger.sh" = "dusky-parakeet-stt";
    "waybar/cava.sh" = "dusky-waybar-cava";
    "waybar/mako.sh" = "dusky-waybar-mako";
    "waybar/network/network_meter_daemon.sh" = "dusky-waybar-network-meter";
    "waybar/toggle_hypridle.sh" = "dusky-toggle-hypridle";
    "waybar/toggle_time.sh" = "dusky-waybar-toggle-time";
    "waybar/toggle_timer_waybar.sh" = "dusky-waybar-toggle-time";
    "waybar/tui_waybars.py" = "dusky-waybars";
    "waybar/update_counter.sh" = "dusky-waybar-update-counter";
    "waybar/waybar_toggle.sh" = "dusky-waybar-autostart";
    "waybar/weather.py" = "dusky-waybar-weather";
    "wayclick/dusky_wayclick.sh" = "dusky-wayclick";
    "wayclick/sounds/wayclick_soundpacks_download.sh" = "dusky-wayclick-soundpacks";
    "wlogout/wlogout_scale.sh" = "dusky-wlogout-scale";
  };
in
  pkgs.runCommand "dusky-user-scripts" {} (''
      mkdir -p $out/user_scripts
    ''
    + pkgs.lib.concatStrings (pkgs.lib.mapAttrsToList (path: bin: ''
        mkdir -p "$out/user_scripts/$(dirname ${path})"
        ln -s ${dusky-scripts-all}/bin/${bin} "$out/user_scripts/${path}"
      '')
      shims))
