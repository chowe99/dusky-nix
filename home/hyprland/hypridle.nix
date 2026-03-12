{ config, pkgs, lib, ... }:

{
  # Deploy hypridle.conf
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    # 1. DIM KEYBOARD BACKLIGHT
    listener {
        timeout = 140
        on-timeout = brightnessctl -sd asus::kbd_backlight set 0
        on-resume = brightnessctl -rd asus::kbd_backlight
    }

    # 2. DIM SCREEN BRIGHTNESS
    listener {
        timeout = 150
        on-timeout = brightnessctl -s set 1
        on-resume = brightnessctl -r
    }

    # 3. LOCK SESSION
    listener {
        timeout = 300
        on-timeout = loginctl lock-session
    }

    # 4. SCREEN OFF (DPMS)
    listener {
        timeout = 330
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
    }

    # 5. SUSPEND (skip if audio playing)
    listener {
        timeout = 600
        on-timeout = pactl list sinks | grep -q "State: RUNNING" || systemctl suspend
    }
  '';

  # Enable hypridle systemd service
  systemd.user.services.hypridle = {
    Unit = {
      Description = "Hyprland idle daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.hypridle}/bin/hypridle";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
