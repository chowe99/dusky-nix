{ config, pkgs, lib, dusky, ... }:

{
  # Swaync config with patched button commands
  xdg.configFile."swaync/config.json".text = builtins.toJSON {
    "$schema" = "/etc/xdg/swaync/configSchema.json";
    positionX = "left";
    positionY = "bottom";
    timeout = 5;
    timeout-low = 3;
    timeout-critical = 10;
    control-center-margin-top = 0;
    control-center-margin-bottom = 5;
    control-center-margin-right = 0;
    control-center-margin-left = 5;
    notification-window-width = 350;
    control-center-width = 300;
    fit-to-screen = true;
    layer = "overlay";
    control-center-layer = "top";
    layer-shell = true;
    cssPriority = "user";
    hide-on-action = false;
    script-fail-notify = true;
    ignore-gtk-theme = true;
    widgets = [ "title" "dnd" "buttons-grid" "volume" "backlight" "notifications" ];
    widget-config = {
      title = {
        clear-all-button = true;
        button-text = "Clear";
      };
      dnd.label = "󰂛";
      volume.label = "󰕾";
      backlight.label = "";
      buttons-grid.actions = [
        { label = "󰡬"; command = "uwsm-app -- dusky-sliders"; }
        { label = ""; command = "uwsm-app -- kitty --class dusky_network -e dusky-network"; }
        { label = "󰂯"; command = "uwsm-app -- blueman-manager"; }
        { label = "󰕾"; command = "uwsm-app -- pavucontrol"; }
        { label = ""; command = "uwsm-app -- dusky-theme-ctl random"; }
        { label = "󰓅"; command = "uwsm-app -- kitty -e --class performance dusky-process-terminator"; }
        { label = "󱫓"; command = "uwsm-app -- kitty -e --class dusky_hypridle dusky-hypridle"; }
      ];
    };
  };

  # Swaync style.css
  xdg.configFile."swaync/style.css".source = "${dusky}/.config/swaync/style.css";
}
