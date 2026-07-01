{ pkgs, dusky }:

# Python GTK control center app.
# Upstream dusky_control_center.py hard-requires Python 3.14.3+
# (sys.version_info < (3, 14, 3) → sys.exit). pkgs.python3 in current
# nixpkgs is still 3.13, so pin to python314 explicitly.
let
  python = pkgs.python314.withPackages (ps: with ps; [
    pygobject3
    pycairo
    pyyaml
  ]);
  scriptDir = "${dusky}/user_scripts/dusky_system/control_center";

  # Mapping of hardcoded $HOME/user_scripts/ paths → Nix package binary names.
  # Each entry is [pattern replacement]. Longest paths first to avoid partial matches.
  pathSubstitutions = [
    # --- Upstream dusky_tui textual framework (settings screens) ---
    # Normalize ~ to $HOME first so the rules below match both forms the config
    # uses (the control center shell-expands $HOME, proven by upstream's own
    # literal $HOME commands).
    ["~/user_scripts"                                             "\\$HOME/user_scripts"]
    # The shared dispatcher (main.py) becomes our packaged binary.
    ["\\$HOME/user_scripts/dusky_tui/python/main/main.py"          "dusky-tui"]
    # Each schema argument → absolute store path, because main.py resolves a
    # direct path but its dot-notation fallback mangles full $HOME paths.
    ["\\$HOME/user_scripts/hypr/visual/tui_appearance.py"          "${dusky}/user_scripts/hypr/visual/tui_appearance.py"]
    ["\\$HOME/user_scripts/hypr/input/tui_input.py"                "${dusky}/user_scripts/hypr/input/tui_input.py"]
    ["\\$HOME/user_scripts/hypr/monitor/monitor_wizard.py"         "${dusky}/user_scripts/hypr/monitor/monitor_wizard.py"]
    ["\\$HOME/user_scripts/hypridle/tui_dusky_hypridle.py"         "${dusky}/user_scripts/hypridle/tui_dusky_hypridle.py"]
    ["\\$HOME/user_scripts/services/tui_service_toggle.py"         "${dusky}/user_scripts/services/tui_service_toggle.py"]
    ["\\$HOME/user_scripts/mako_osd/mako_tui/tui_mako.py"          "${dusky}/user_scripts/mako_osd/mako_tui/tui_mako.py"]
    ["\\$HOME/user_scripts/waybar/tui_waybars.py"                  "${dusky}/user_scripts/waybar/tui_waybars.py"]
    # Direct-invocation scripts → their packaged binaries (paths moved upstream).
    ["\\$HOME/user_scripts/hypr/monitor/adjust_scale.py"           "dusky-adjust-scale"]
    ["\\$HOME/user_scripts/hypr/monitor/screen_rotate.py"          "dusky-screen-rotate"]
    ["\\$HOME/user_scripts/hypr/input/dusky_keybinds.py"           "dusky-keybinds"]
    ["\\$HOME/user_scripts/hypr/rules/window_rules_generator.py"   "dusky-window-rules-gen"]
    ["\\$HOME/user_scripts/external/usb_sound_toggle.py"           "dusky-usb-sound"]
    ["\\$HOME/user_scripts/battery/power_saver.sh"                 "dusky-power-saver"]
    ["\\$HOME/user_scripts/locale/locale_tui.sh"                   "dusky-locale-tui"]
    ["\\$HOME/user_scripts/waybar/toggle_time.sh"                  "dusky-waybar-toggle-time"]
    ["\\$HOME/user_scripts/wayclick/sounds/wayclick_soundpacks_download.sh" "dusky-wayclick-soundpacks"]
    ["\\$HOME/user_scripts/networking/dusky_wireguard_new.sh"      "dusky-wireguard-new"]
    ["\\$HOME/user_scripts/networking/dusky_wireguard_setup.sh"    "dusky-wireguard-setup"]

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
    ["\\$HOME/user_scripts/dusky_system/quickpanal/dusky_quickpanal.py" "dusky-sliders"]

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
    ["\\$HOME/user_scripts/drives/dusky_disk_monitor_io.py"         "dusky-io-monitor"]
    ["\\$HOME/user_scripts/drives/drive_manager/drive_manager.py"   "dusky-drive-manager"]

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

    # Mako OSD / TUI
    ["\\$HOME/user_scripts/mako_osd/mako_tui/tui_mako.sh"          "dusky-mako-tui"]
    ["\\$HOME/user_scripts/mako_osd/osd_router.sh"                 "dusky-osd-router"]
    ["\\$HOME/user_scripts/rofi/rofi_mako.sh"                      "dusky-rofi-mako"]

    # TTS/STT (launchers → packaged wrappers)
    ["\\$HOME/user_scripts/tts_stt/dusky_kokoro/kokoro_installer.sh"   "dusky-kokoro-tts"]
    ["\\$HOME/user_scripts/tts_stt/dusky_parakeet/parakeet_installer.sh" "dusky-parakeet-stt"]

    # Portable arch_setup_scripts (work on NixOS)
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/150_wallpapers_download.sh" "dusky-wallpaper-download"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/265_mouse_button_reverse.sh" "dusky-mouse-reverse"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/235_file_manager_switch.sh" "dusky-file-manager-switch"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/236_browser_switcher.sh" "dusky-browser-switch"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/237_text_editer_switcher.sh" "dusky-editor-switch"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/238_terminal_switcher.sh" "dusky-terminal-switch"]
    # 170_waypaper_config_reset.sh removed upstream (waypaper dropped for awww)
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/175_animation_default.sh" "dusky-animation-default"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/375_cursor_theme_bibata_classic_modern.sh" "dusky-cursor-bibata"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/460_switch_clipboard.sh" "dusky-clipboard-switch"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/390_clipboard_persistance.sh" "dusky-clipboard-persistence"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/325_hosts_files_block.sh" "dusky-hosts-blocker"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/155_blur_shadow_opacity.sh" "dusky-blur-visibility"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/305_new_github_repo_to_backup.sh" "dusky-github-backup-new"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/310_reconnect_and_push_new_changes_to_github.sh" "dusky-github-backup-sync"]

    # Waybar (additional)
    ["\\$HOME/user_scripts/waybar/mako.sh"                              "dusky-waybar-mako"]
    ["\\$HOME/user_scripts/waybar/update_counter.sh"                    "dusky-waybar-update-counter"]

    # Neovim
    ["\\$HOME/user_scripts/nvim/dusky_neovim_manager.sh"                "dusky-neovim-manager"]
    ["\\$HOME/user_scripts/nvim/reset/01_reset_neovim.sh"               "dusky-reset-neovim"]
    ["\\$HOME/user_scripts/nvim/reset/02_cli_plugins_download.sh"       "dusky-neovim-plugins"]

    # GTK
    ["\\$HOME/user_scripts/gtk/dusky_gsettings.sh"                      "dusky-gsettings"]

    # Drives (additional)
    ["\\$HOME/user_scripts/drives/btrfs_zstd_compression_stats.sh"      "dusky-btrfs-stats"]
    ["\\$HOME/user_scripts/drives/ntfs_fix.sh"                          "dusky-ntfs-fix"]

    # Networking (additional)
    ["\\$HOME/user_scripts/networking/arp_scan.sh"                      "dusky-arp-scan"]

    # Portable Arch Setup Scripts (additional — work on NixOS)
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/020_desktop_apps_username_setter.sh" "dusky-desktop-apps-fix"]
    ["\\$HOME/user_scripts/firefox/400_firefox_matugen_pywalfox.sh"  "dusky-firefox-matugen"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/135_battery_notify_service.sh"    "dusky-battery-notify"]

    # --- Arch/service/app buttons adapted for NixOS via the dusky-nixos-ctl shim ---
    # service <unit> -- <cmd> : manage if the unit is declaratively present, else
    #   guide (a system service can't be imperatively installed on NixOS).
    # install <attr> : nix profile install nixpkgs#<attr> (imperative user pkg).
    # na '<msg>' : managed declaratively / not applicable — informative no-op.
    # Services (detect + manage on this host, guide on others):
    ["\\$HOME/user_scripts/networking/01_tailscale_setup.sh"                      "dusky-nixos-ctl service tailscaled.service -- tailscale status"]
    ["\\$HOME/user_scripts/networking/02_openssh_setup.py"                        "dusky-nixos-ctl service sshd.service -- systemctl status sshd"]
    # App installs (nix profile):
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/260_spotify.sh"             "dusky-nixos-ctl install spotify Spotify"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/470_vesktop_matugen.sh"     "dusky-nixos-ctl install vesktop Vesktop"]
    # Declarative / Arch-only — informative no-op with the Nix way to do it:
    ["\\$HOME/user_scripts/networking/uninstall_tailscale.sh"                     "dusky-nixos-ctl na 'Tailscale is declarative: services.tailscale.enable'"]
    ["\\$HOME/user_scripts/networking/airmon_ng.sh"                               "dusky-nixos-ctl na 'Add aircrack-ng to your config if needed'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/005_hypr_custom_config_setup.py"     "dusky-nixos-ctl na 'Hyprland config is managed by dusky-nix (home-manager)'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/035_configure_uwsm_gpu.sh"  "dusky-nixos-ctl na 'GPU/UWSM configured declaratively'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/055_pacman_reflector.sh"    "dusky-nixos-ctl na 'No pacman on NixOS'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/080_aur_paru_fallback_yay.sh" "dusky-nixos-ctl na 'No AUR on NixOS; add packages to your config'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/085_warp.sh"                "dusky-nixos-ctl na 'Cloudflare Warp is a service; enable declaratively'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/090_paru_packages_optional.sh" "dusky-nixos-ctl na 'Add packages to your Nix config'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/170_waypaper_config_reset.sh" "dusky-nixos-ctl na 'waypaper removed upstream (awww)'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/205_zram_configuration.sh"  "dusky-nixos-ctl na 'zram is declarative: zramSwap.enable'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/210_zram_optimize_swappiness.sh" "dusky-nixos-ctl na 'Set kernel sysctls declaratively'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/250_ftp_arch.sh"            "dusky-nixos-ctl na 'FTP is declarative: services.vsftpd'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/285_tty_autologin.sh"       "dusky-nixos-ctl na 'Declarative: services.getty.autologinUser'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/300_git_config.sh"          "dusky-nixos-ctl na 'Configure git via programs.git'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/335_preload_config.sh"      "dusky-nixos-ctl na 'preload is a service; enable declaratively'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/365_cache_purge.sh"         "dusky-nixos-ctl na 'Use nix-collect-garbage'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/380_nvidia_open_source.sh"  "dusky-nixos-ctl na 'Declarative: hardware.nvidia.open'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/385_waydroid_setup.sh"      "dusky-nixos-ctl na 'Declarative: virtualisation.waydroid.enable'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/405_spicetify_matugen_setup.sh" "dusky-nixos-ctl na 'Add spotify + spicetify-cli to your config'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/scripts/465_sddm_setup.sh"          "dusky-nixos-ctl na 'Declarative: services.displayManager.sddm'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/ORCHESTRA.sh"                       "dusky-nixos-ctl na 'Arch installer; not used on NixOS'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/deploy_dotfiles.sh"                 "dusky-nixos-ctl na 'dusky-nix deploys configs declaratively'"]
    ["\\$HOME/user_scripts/arch_setup_scripts/send_logs.sh"                       "dusky-nixos-ctl na 'Arch-only'"]
    ["\\$HOME/user_scripts/update_dusky/update_dusky.sh"                          "dusky-nixos-ctl na 'Update: nix flake update dusky-nix then rebuild'"]
    ["\\$HOME/user_scripts/ftp/change_ftp_directory_server.sh"                    "dusky-nixos-ctl na 'FTP is declarative: services.vsftpd'"]
  ];

  # Build a chain of sed commands from the substitution list. The sed script is
  # single-quoted in the shell, so any literal ' in a pattern/replacement (e.g. a
  # `na 'message'` replacement) must be escaped as '\'' or it terminates the quote
  # and the substitution silently no-ops.
  shEsc = builtins.replaceStrings ["'"] ["'\\''"];
  sedCommands = builtins.concatStringsSep "\n" (
    builtins.map (pair:
      let
        pattern = shEsc (builtins.elemAt pair 0);
        replacement = shEsc (builtins.elemAt pair 1);
      in
      "sed -i 's|${pattern}|${replacement}|g' $out/lib/dusky-control-center/dusky_config.toml"
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

    # nix-compat: upstream bumped its hard Python floor to 3.14.5, but pkgs.python314
    # is 3.14.3 → the app sys.exit()s at startup ("[FATAL] Python 3.14.5+ is required"),
    # so the D-Bus/dusky.service (ALT+SPACE) never starts. Point releases add no language
    # features it needs; relax the gate to any 3.14.x.
    sed -i 's/sys.version_info < (3, 14, 5)/sys.version_info < (3, 14, 0)/' \
      $out/lib/dusky-control-center/dusky_control_center.py

    # Replace hardcoded $HOME/user_scripts/ paths with Nix-packaged binary names
    ${sedCommands}

    # Inject dharmx/walls download button after the existing wallpaper download button.
    # Upstream config is now TOML; anchor on the post-substitution download command
    # then the next `terminal = false`. Guarded so a missing anchor is a no-op (not a
    # build crash) in case upstream restructures the wallpaper section again.
    local toml="$out/lib/dusky-control-center/dusky_config.toml"
    local line_num
    line_num=$(grep -n 'dusky-wallpaper-download' "$toml" | tail -1 | cut -d: -f1)
    if [[ -n "$line_num" ]]; then
      local rel insert_after
      rel=$(tail -n +"$line_num" "$toml" | grep -n 'terminal = false' | head -1 | cut -d: -f1)
      if [[ -n "$rel" ]]; then
        insert_after=$((line_num + rel - 1))
        local snippet
        snippet=$(mktemp)
        cat > "$snippet" << 'WALLS_EOF'

[[pages.layout.items]]
type = "button"
[pages.layout.items.properties]
title = "dharmx/walls Collection"
description = "Download ~56 themed wallpaper categories via git"
icon = "image-x-generic-symbolic"
button_text = "Download"
[pages.layout.items.on_press]
type = "exec"
command = "kitty --class dusky_walls_download --hold sh -c \"dusky-walls-download\""
terminal = false
WALLS_EOF
        sed -i "''${insert_after}r $snippet" "$toml"
        rm -f "$snippet"
      fi
    fi
  '';

  postFixup = ''
    makeWrapper ${python}/bin/python3 $out/bin/dusky-control-center \
      --add-flags "$out/lib/dusky-control-center/dusky_control_center.py" \
      "''${gappsWrapperArgs[@]}" \
      --prefix GI_TYPELIB_PATH : "${pkgs.gobject-introspection}/lib/girepository-1.0"
  '';
}
