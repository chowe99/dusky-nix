{ config, pkgs, lib, ... }:

{
  # Battery notification service
  systemd.user.services.dusky-battery-notify = {
    Unit = {
      Description = "Dusky battery notification daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c 'dusky-battery-notify'";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Swaync notification daemon
  systemd.user.services.swaync = {
    Unit = {
      Description = "Sway Notification Center";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.swaynotificationcenter}/bin/swaync";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Dusky control center daemon (D-Bus activated via SUPER+Space)
  systemd.user.services.dusky = {
    Unit = {
      Description = "Dusky Control Center Daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      Environment = "PYTHONUNBUFFERED=1";
      ExecStart = "/etc/profiles/per-user/%u/bin/dusky-control-center --gapplication-service";
      Restart = "always";
      RestartSec = 3;
      Slice = "app.slice";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # D-Bus service file for control center activation
  xdg.dataFile."dbus-1/services/com.github.dusky.controlcenter.service".text = lib.mkDefault ''
    [D-BUS Service]
    Name=com.github.dusky.controlcenter
    SystemdService=dusky.service
    Exec=/usr/bin/false
  '';

  # Kokoro TTS daemon (auto-starts on login, required by voice assistant)
  systemd.user.services.dusky-kokoro-tts = {
    Unit = {
      Description = "Dusky Kokoro TTS daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "/etc/profiles/per-user/%u/bin/dusky-kokoro-tts-daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Parakeet STT daemon (lazy-started by trigger, or auto-start on login)
  systemd.user.services.dusky-parakeet-stt = {
    Unit = {
      Description = "Dusky Parakeet STT daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "/etc/profiles/per-user/%u/bin/dusky-parakeet-stt-daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
    # Not in WantedBy — started on-demand by trigger script
    # To auto-start: systemctl --user enable dusky-parakeet-stt.service
  };

  # Dusky Voice Assistant daemon (always listening for wake word on login)
  systemd.user.services.dusky-voice-assistant = {
    Unit = {
      Description = "Dusky Voice Assistant daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" "dusky-kokoro-tts.service" ];
      Requires = [ "dusky-kokoro-tts.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "/etc/profiles/per-user/%u/bin/dusky-voice-assistant-daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Hyprsunset (blue light filter)
  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "Hyprland sunset (blue light filter)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.hyprsunset}/bin/hyprsunset";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
