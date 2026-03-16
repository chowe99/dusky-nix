{ pkgs, dusky }:

# Python GTK control center app
let
  python = pkgs.python3.withPackages (ps: with ps; [
    pygobject3
    pycairo
    pyyaml
  ]);
  scriptDir = "${dusky}/user_scripts/dusky_system/control_center";

  # Mapping of hardcoded $HOME/user_scripts/ paths → Nix package binary names.
  # Each entry is [pattern replacement]. Longest paths first to avoid partial matches.
  pathSubstitutions = [
    # Theme / Matugen
    ["\\$HOME/user_scripts/theme_matugen/theme_ctl.sh"              "dusky-theme-ctl"]
    ["~/user_scripts/theme_matugen/dusky_matugen_presets.sh"        "dusky-matugen-presets"]
    ["\\$HOME/user_scripts/theme_matugen/dusky_matugen_presets.sh"  "dusky-matugen-presets"]
    ["\\$HOME/user_scripts/theme_matugen/theme_favorites_ctl.sh"   "dusky-theme-favorites"]

    # Control center reload
    ["\\$HOME/user_scripts/dusky_system/reload_cc/cc_restart.sh"    "dusky-cc-restart"]

    # Hypr scripts
    ["\\$HOME/user_scripts/hypr/screen_rotate.sh"                   "dusky-screen-rotate"]
    ["\\$HOME/user_scripts/hypr/adjust_scale.py"                    "dusky-adjust-scale"]
    ["\\$HOME/user_scripts/hypr/hypr_blur_opacity_shadow_toggle.sh" "dusky-blur-toggle"]
    ["\\$HOME/user_scripts/hypr/dusky_appearances.sh"               "dusky-appearances"]
    ["\\$HOME/user_scripts/hypr/dusky_input.sh"                     "dusky-input"]
    ["\\$HOME/user_scripts/hypr/dusky_keybinds.sh"                  "dusky-keybinds"]
    ["\\$HOME/user_scripts/hypr/dusky_monitor.sh"                   "dusky-monitor"]
    ["\\$HOME/user_scripts/hypr/dusky_window_rules.sh"              "dusky-window-rules"]
    ["\\$HOME/user_scripts/hypr/dusky_workspace_manager.sh"         "dusky-workspace-manager"]
    ["\\$HOME/user_scripts/hypr/multi_monitor_workspace.sh"         "dusky-multi-monitor-workspace"]

    # Audio
    ["\\$HOME/user_scripts/audio/audio_switch.sh"                   "dusky-audio-switch"]
    ["\\$HOME/user_scripts/audio/mic_switch.sh"                     "dusky-mic-switch"]
    ["\\$HOME/user_scripts/audio/mono_audio_pipewire.py"            "dusky-mono-audio"]

    # Rofi
    ["\\$HOME/user_scripts/rofi/rofi_wallpaper_selctor.sh"          "dusky-rofi-wallpaper"]
    ["\\$HOME/user_scripts/rofi/rofi_theme.sh"                      "dusky-rofi-theme"]
    ["\\$HOME/user_scripts/rofi/keybindings.sh"                     "dusky-rofi-keybindings"]
    ["\\$HOME/user_scripts/rofi/shader_menu.sh"                     "dusky-rofi-shader"]
    ["\\$HOME/user_scripts/rofi/hypr_anim.sh"                       "dusky-rofi-animations"]
    ["\\$HOME/user_scripts/rofi/powermenu.sh"                       "dusky-rofi-powermenu"]
    ["\\$HOME/user_scripts/rofi/emoji.sh"                           "dusky-rofi-emoji"]
    ["\\$HOME/user_scripts/rofi/calculator.sh"                      "dusky-rofi-calculator"]
    ["\\$HOME/user_scripts/rofi/rofi_cliphist.sh"                   "dusky-rofi-cliphist"]

    # Sliders
    ["\\$HOME/user_scripts/sliders/dusky_sliders.py"                "dusky-sliders"]

    # Wlogout
    ["\\$HOME/user_scripts/wlogout/wlogout_scale.sh"                "dusky-wlogout-scale"]

    # Waybar
    ["\\$HOME/user_scripts/waybar/dusky_waybars.sh"                 "dusky-waybars"]
    ["\\$HOME/user_scripts/waybar/toggle_hypridle.sh"               "dusky-toggle-hypridle"]

    # Hyprlock
    ["\\$HOME/user_scripts/hyprlock/dusky_hyprlock_switcher.sh"     "dusky-hyprlock-switcher"]
    ["\\$HOME/user_scripts/hyprlock/lock.sh"                        "dusky-lock"]

    # Hypridle
    ["\\$HOME/user_scripts/hypridle/dusky_hypridle.sh"              "dusky-hypridle"]

    # Services / Performance / Power
    ["\\$HOME/user_scripts/services/dusky_service_toggle.sh"        "dusky-service-toggle"]
    ["\\$HOME/user_scripts/performance/services_and_process_terminator.sh" "dusky-process-terminator"]
    ["\\$HOME/user_scripts/performance/sysbench_benchmark.sh"            "dusky-sysbench"]
    ["\\$HOME/user_scripts/power/dusky_power.sh"                    "dusky-power"]

    # Battery
    ["\\$HOME/user_scripts/battery/power_saving/power_saver.sh"     "dusky-power-saver"]
    ["\\$HOME/user_scripts/battery/power_saving_off/power_saver_off.sh" "dusky-power-saver-off"]

    # Drives
    ["\\$HOME/user_scripts/drives/io_monitor.sh"                    "dusky-io-monitor"]
    ["\\$HOME/user_scripts/drives/drive_manager.sh"                 "dusky-drive-manager"]

    # Networking
    ["\\$HOME/user_scripts/networking/warp_toggle.sh"               "dusky-warp-toggle"]
    # ~/user_scripts/networking/airmon_ng.sh — no Nix equivalent, left as-is

    # Wayclick
    ["\\$HOME/user_scripts/wayclick/dusky_wayclick.sh"              "dusky-wayclick"]
    ["\\$HOME/user_scripts/wayclick/dusky_tui_wayclick.sh"          "dusky-wayclick"]

    # Media
    ["\\$HOME/user_scripts/google_image_search/google_image_search.sh" "dusky-google-image-search"]
    ["\\$HOME/user_scripts/music/music_recognition.sh"              "dusky-music-recognition"]
    ["\\$HOME/user_scripts/spotify/spotify_toggle.sh"               "dusky-spotify-toggle"]

    # LLM
    ["\\$HOME/user_scripts/llm/ollama_terminal.sh"                  "dusky-ollama-terminal"]

    # Screenshot
    ["\\$HOME/user_scripts/images/dusky_screenshot.sh"              "dusky-screenshot"]

    # SwayOSD
    ["\\$HOME/user_scripts/swayosd/restart_swayosd.sh"              "dusky-restart-swayosd"]

    # TTS/STT (launchers → packaged wrappers)
    ["\\$HOME/user_scripts/tts_stt/dusky_kokoro/kokoro_installer.sh"   "dusky-kokoro-tts"]
    ["\\$HOME/user_scripts/tts_stt/dusky_parakeet/parakeet_installer.sh" "dusky-parakeet-stt"]

    # Wallpaper download (from arch_setup_scripts but not actually Arch-specific)
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/150_wallpapers_download.sh" "dusky-wallpaper-download"]

    # NOTE: The following scripts are referenced in dusky_config.yaml but do NOT
    # have Nix packages yet. They remain as hardcoded paths until packaged:
    #   - $HOME/user_scripts/swaync/dusky_swaync_side.sh
    #   - $HOME/user_scripts/nvim/dusky_neovim_manager.sh
    #   - $HOME/user_scripts/nvim/reset/01_reset_neovim.sh
    #   - $HOME/user_scripts/nvim/reset/02_cli_plugins_download.sh
    #   - $HOME/user_scripts/gtk/dusky_gsettings.sh
    #   - $HOME/user_scripts/arch_setup_scripts/* (remaining Arch-specific scripts)
    #   - $HOME/user_scripts/update_dusky/* (Arch-specific)
    #   - $HOME/user_scripts/ftp/* (no Nix equivalent)
  ];

  # Build a chain of sed commands from the substitution list
  sedCommands = builtins.concatStringsSep "\n" (
    builtins.map (pair:
      let
        pattern = builtins.elemAt pair 0;
        replacement = builtins.elemAt pair 1;
      in
      "sed -i 's|${pattern}|${replacement}|g' $out/lib/dusky-control-center/dusky_config.yaml"
    ) pathSubstitutions
  );
in
pkgs.stdenv.mkDerivation {
  pname = "dusky-control-center";
  version = "1.0.0";

  src = scriptDir;

  nativeBuildInputs = with pkgs; [ makeWrapper wrapGAppsHook4 gobject-introspection ];

  buildInputs = with pkgs; [
    gtk4
    libadwaita
    glib
  ];

  dontWrapGApps = true;

  installPhase = ''
    mkdir -p $out/bin $out/lib/dusky-control-center
    cp -r . $out/lib/dusky-control-center/

    # Replace hardcoded $HOME/user_scripts/ paths with Nix-packaged binary names
    ${sedCommands}
  '';

  postFixup = ''
    makeWrapper ${python}/bin/python3 $out/bin/dusky-control-center \
      --add-flags "$out/lib/dusky-control-center/dusky_control_center.py" \
      "''${gappsWrapperArgs[@]}" \
      --prefix GI_TYPELIB_PATH : "${pkgs.gobject-introspection}/lib/girepository-1.0"
  '';
}
