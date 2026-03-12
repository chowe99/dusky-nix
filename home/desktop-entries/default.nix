{ config, pkgs, lib, ... }:

{
  xdg.desktopEntries = {
    # --- System Monitors ---
    btop = {
      name = "btop++";
      exec = "uwsm-app -- kitty --class btop btop";
      icon = "btop";
      comment = "Resource monitor";
      categories = [ "System" "Monitor" ];
    };
    htop = {
      name = "Htop";
      exec = "uwsm-app -- kitty --class htop -e htop";
      icon = "htop";
      comment = "Interactive process viewer";
      categories = [ "System" "Monitor" ];
    };
    dgop = {
      name = "dgop";
      exec = "uwsm-app -- kitty --class dgop -e dgop";
      icon = "preferences-desktop-display";
      comment = "Interactive process viewer";
      categories = [ "System" "Monitor" ];
    };
    powertop = {
      name = "PowerTOP";
      exec = "uwsm-app -- kitty --class powertop -e sudo powertop";
      icon = "utilities-system-monitor";
      comment = "Monitor power usage";
      categories = [ "System" "Monitor" ];
    };
    intel_gpu_top = {
      name = "Intel GPU Top";
      exec = "uwsm-app -- kitty --class intel_gpu_top -e sudo intel_gpu_top";
      icon = "video-display";
      comment = "Intel GPU usage statistics";
      categories = [ "System" "Monitor" ];
    };
    fastfetch = {
      name = "Fastfetch";
      exec = "uwsm-app -- kitty --class fastfetch --hold -e fastfetch";
      icon = "utilities-terminal";
      comment = "Display system information";
      categories = [ "System" "Monitor" ];
    };
    dysk = {
      name = "Dysk";
      exec = "uwsm-app -- kitty --class dysk --hold -e dysk";
      icon = "drive-harddisk";
      comment = "Display filesystem information";
      categories = [ "System" "Monitor" ];
    };

    # --- TUI Apps ---
    cava = {
      name = "Cava";
      exec = "uwsm-app -- kitty --class cava -e cava";
      icon = "utilities-terminal";
      comment = "Console-based Audio Visualizer";
      categories = [ "Audio" "Video" ];
    };
    peaclock = {
      name = "Peaclock";
      exec = "uwsm-app -- kitty --class peaclock -e peaclock";
      icon = "utilities-terminal";
      comment = "Console-based Clock";
      categories = [ "Utility" ];
    };
    kew = {
      name = "kew";
      exec = "uwsm-app -- kitty --class kew -e kew";
      icon = "utilities-terminal";
      comment = "TUI Music Player";
      categories = [ "Audio" "Music" ];
    };
    wifitui = {
      name = "Wifi TUI";
      exec = "uwsm-app -- kitty --class wifitui -e wifitui";
      icon = "network-wireless";
      comment = "TUI for managing Wi-Fi connections";
      categories = [ "Network" ];
    };
    bluetui = {
      name = "Blue TUI";
      exec = "uwsm-app -- kitty --class bluetui -e bluetui";
      icon = "bluetooth";
      comment = "TUI for managing Bluetooth devices";
      categories = [ "Hardware" "Settings" ];
    };
    traytui = {
      name = "Tray TUI";
      exec = "uwsm-app -- kitty --class tray-tui -e tray-tui";
      icon = "preferences-system-windows";
      comment = "TUI System Tray";
      categories = [ "System" "Utility" ];
    };

    # --- Dusky Control Apps ---
    dusky_control_center = {
      name = "Dusky Control Center";
      exec = "dusky-control-center";
      icon = "preferences-system";
      comment = "Centralized configuration for Dusky OS";
      categories = [ "System" "Settings" ];
    };
    dusky_appearances = {
      name = "Dusky Appearance TUI";
      exec = "uwsm-app -- kitty --class dusky_appearances -e dusky-appearances";
      icon = "preferences-desktop-display";
      comment = "Hyprland appearance configurator";
      categories = [ "Settings" "DesktopSettings" ];
    };
    dusky_input = {
      name = "Dusky Input TUI";
      exec = "uwsm-app -- kitty --class dusky_input -e dusky-input";
      icon = "preferences-desktop-keyboard";
      comment = "Hyprland input configurator";
      categories = [ "Settings" "DesktopSettings" ];
    };
    dusky_keybinds = {
      name = "Dusky Keybind Manager";
      exec = "uwsm-app -- kitty --hold --class dusky_keybinds -e dusky-keybinds";
      icon = "preferences-desktop-keyboard";
      comment = "Keybind manager with conflict resolution";
      categories = [ "System" "Settings" ];
    };
    dusky_monitor = {
      name = "Dusky Monitor Wizard";
      exec = "uwsm-app -- kitty --class dusky_monitor -e dusky-monitor";
      icon = "preferences-desktop-display";
      comment = "Configure monitors, resolution, and scaling";
      categories = [ "Settings" "Hardware" ];
    };
    dusky_window_rules = {
      name = "Window Rule Manager";
      exec = "uwsm-app -- kitty --class dusky_window_rules -e dusky-window-rules";
      icon = "preferences-system-windows";
      comment = "Interactive Hyprland window rules";
      categories = [ "System" "Utility" ];
    };
    dusky_workspace_manager = {
      name = "Dusky Workspace Manager TUI";
      exec = "uwsm-app -- kitty --class dusky_workspace_manager -e dusky-workspace-manager";
      icon = "preferences-desktop-display";
      comment = "Workspace layout configurator";
      categories = [ "Settings" "DesktopSettings" ];
    };

    # --- Theming ---
    dusky_matugen = {
      name = "Matugen Theme";
      exec = "uwsm-app -- dusky-theme-ctl random";
      icon = "preferences-desktop-theme";
      comment = "Regenerate system colors from wallpaper";
      categories = [ "Settings" ];
    };
    dusky_matugen_presets = {
      name = "Dusky Matugen Presets";
      exec = "uwsm-app -- kitty --class dusky_matugen_presets -e dusky-matugen-presets";
      icon = "preferences-desktop-theme";
      comment = "Material Design Theme Switcher";
      categories = [ "Settings" "Utility" ];
    };
    dusky_sliders = {
      name = "Dusky Sliders";
      exec = "uwsm-app -- dusky-sliders";
      icon = "preferences-system";
      comment = "Adjust Brightness, Volume, and Nightlight";
      categories = [ "Audio" "Settings" ];
    };

    # --- Waybar ---
    dusky_waybars = {
      name = "Dusky Waybar Swap";
      exec = "uwsm-app -- kitty --class dusky_waybars -e dusky-waybars";
      icon = "image-x-generic";
      comment = "Toggle between Waybar configurations";
      categories = [ "Settings" "DesktopSettings" ];
    };

    # --- Power & Battery ---
    dusky_battery_notify = {
      name = "Dusky Battery";
      exec = "uwsm-app -- kitty --class dusky_battery_notify -e dusky-battery-notify";
      icon = "preferences-system-power";
      comment = "Configure Battery Timeout Settings";
      categories = [ "Settings" "System" ];
    };
    dusky_power = {
      name = "Dusky Power";
      exec = "uwsm-app -- kitty --class dusky_power -e dusky-power";
      icon = "system-shutdown";
      comment = "Power Management";
      categories = [ "Settings" "System" ];
    };
    powersave = {
      name = "Power Saver Mode";
      exec = "uwsm-app -- kitty --hold --class power_saver -e dusky-power-saver";
      icon = "battery-low";
      comment = "Enable Power Saving Mode";
      categories = [ "System" "Settings" ];
    };
    powersave_off = {
      name = "Turn off Power Saver";
      exec = "uwsm-app -- kitty --hold --class power_saver_off -e dusky-power-saver-off";
      icon = "battery-low";
      comment = "Reverses Power Saving Mode";
      categories = [ "System" "Settings" ];
    };

    # --- Network ---
    dusky_network = {
      name = "Dusky Network";
      exec = "uwsm-app -- kitty --class dusky_network -e dusky-network";
      icon = "network-wireless";
      comment = "WiFi Manager (TUI)";
      categories = [ "Network" "Settings" ];
    };
    warp = {
      name = "Toggle Warp";
      exec = "uwsm-app -- dusky-warp-toggle";
      icon = "network-vpn";
      comment = "Toggle Cloudflare Warp Connection";
      categories = [ "Network" ];
    };

    # --- Lock & Session ---
    dusky_hyprlock_switcher = {
      name = "Dusky Hyprlock Theme Manager";
      exec = "uwsm-app -- kitty --class dusky_hyprlock_switcher -e dusky-hyprlock-switcher";
      icon = "preferences-desktop-screensaver";
      comment = "Switch Hyprlock configurations";
      categories = [ "Settings" "DesktopSettings" ];
    };
    dusky_hypridle_timeout = {
      name = "Dusky Hypridle Timeout";
      exec = "uwsm-app -- kitty --class dusky_hypridle -e dusky-hypridle";
      icon = "preferences-system-power";
      comment = "Configure Idle Timeout Settings";
      categories = [ "Settings" "System" ];
    };

    # --- Screenshot & Capture ---
    screenshot_swappy = {
      name = "Screenshot Region";
      exec = "dusky-screenshot --region --freeze --annotate --no-notify --tool arrow";
      icon = "camera-photo";
      comment = "Capture region and annotate";
      categories = [ "Utility" ];
    };
    google_image_search = {
      name = "Google Lens Capture";
      exec = "uwsm-app -- dusky-google-image-search";
      icon = "camera-web";
      comment = "Capture and search with Google Lens";
      categories = [ "Utility" "Graphics" ];
    };

    # --- Rofi Shortcuts ---
    rofi_calculator = {
      name = "Rofi Calculator";
      exec = "uwsm-app -- dusky-rofi-calculator";
      icon = "calc";
      comment = "Calculator in Rofi";
      categories = [ "Utility" ];
    };
    rofi_emoji = {
      name = "Rofi Emoji";
      exec = "uwsm-app -- dusky-rofi-emoji";
      icon = "face-smile";
      comment = "Emoji picker";
      categories = [ "Utility" ];
    };
    rofi_wallpaper = {
      name = "Rofi Wallpaper";
      exec = "uwsm-app -- dusky-rofi-wallpaper";
      icon = "preferences-desktop-wallpaper";
      comment = "Switch/Change Wallpapers";
      categories = [ "Settings" ];
    };

    # --- Display ---
    scale_up = {
      name = "Scale UI Up";
      exec = "uwsm-app -- dusky-adjust-scale +";
      icon = "zoom-in";
      comment = "Increase display scaling";
      categories = [ "Settings" ];
    };
    scale_down = {
      name = "Scale UI Down";
      exec = "uwsm-app -- dusky-adjust-scale -";
      icon = "zoom-out";
      comment = "Decrease display scaling";
      categories = [ "Settings" ];
    };
    rotate_screen_clockwise = {
      name = "Rotate Screen Clockwise";
      exec = "uwsm-app -- dusky-screen-rotate -90";
      icon = "object-rotate-right";
      comment = "Rotate display -90 degrees";
      categories = [ "Settings" ];
    };
    rotate_screen_counter_clockwise = {
      name = "Rotate Screen Anti-Clockwise";
      exec = "uwsm-app -- dusky-screen-rotate +90";
      icon = "object-rotate-left";
      comment = "Rotate display +90 degrees";
      categories = [ "Settings" ];
    };
    opacity_blur_shadow = {
      name = "Toggle Appearance";
      exec = "uwsm-app -- dusky-blur-toggle";
      icon = "preferences-desktop-theme";
      comment = "Toggle Blur, Opacity, and Shadows";
      categories = [ "Settings" ];
    };

    # --- Drives ---
    IO_Monitor = {
      name = "IO Monitor";
      exec = "uwsm-app -- kitty --class io_monitor -e dusky-io-monitor";
      icon = "drive-harddisk";
      comment = "Real-time Disk I/O Monitoring";
      categories = [ "System" "Monitor" ];
    };

    # --- Notifications ---
    swaync = {
      name = "Toggle Notification Center";
      exec = "uwsm-app -- swaync-client -t";
      icon = "preferences-system-notifications";
      comment = "Open/Close SwayNC";
      categories = [ "Utility" ];
    };

    # --- Dev ---
    nvim = {
      name = "Neovim";
      exec = "uwsm-app -- kitty --class nvim -e nvim";
      icon = "nvim";
      comment = "Edit text files";
      categories = [ "Utility" "TextEditor" "Development" ];
    };

    # --- Media ---
    music_recognition = {
      name = "Music Recognition";
      exec = "uwsm-app -- kitty --hold --class music_recognition -e dusky-music-recognition";
      icon = "audio-input-microphone";
      comment = "Identify playing music";
      categories = [ "Audio" "Utility" ];
    };

    # --- Misc ---
    dusky_service_toggle = {
      name = "Dusky Toggle Service";
      exec = "uwsm-app -- kitty --class dusky_service_toggle -e dusky-service-toggle";
      icon = "preferences-system-power";
      comment = "Configure Service Settings";
      categories = [ "Settings" "System" ];
    };
    process_terminator = {
      name = "Process Terminator";
      exec = "uwsm-app -- kitty --hold --class performance -e dusky-process-terminator";
      icon = "process-stop";
      comment = "Select and kill running processes";
      categories = [ "System" "Monitor" ];
    };
  };
}
