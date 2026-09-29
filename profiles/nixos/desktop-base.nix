# profiles/nixos/desktop-base.nix — Shared desktop environment settings
# Pipewire, Bluetooth, Polkit, udiskie, udisks2, fonts, logind lid handling
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.desktop-base;
in {
  options.desktop-base = {
    kdeconnect = lib.mkEnableOption "KDE Connect (phone integration, opens 1714-1764)";
    mosh = lib.mkEnableOption "mosh server (UDP 60000-61000)";
  };

  config = {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;

      # NOTE: PipeWire echo-cancel module disabled — the module's playback node
      # routes mic capture to speakers causing feedback, even with node.passive.
      # The voice assistant works around this by waiting for TTS to finish before
      # recording. Revisit AEC if barge-in support is needed later.
      # See: https://docs.pipewire.org/page_module_echo_cancel.html
    };

    # Tame internal mic ALSA capture gain — default 100% (30dB) amplifies
    # laptop mic self-noise badly. 40% (~1.5dB) is clean for speech.
    # Silently skips if no PCH card exists (servers, external audio only).
    systemd.services.alsa-mic-gain = {
      description = "Set ALSA internal mic capture gain";
      after = ["sound.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "set-mic-gain" ''
          ${pkgs.alsa-utils}/bin/amixer -c PCH sset Capture 40% 2>/dev/null || true
        '';
      };
    };

    hardware.bluetooth.enable = true;
    security.polkit.enable = true;
    powerManagement.enable = true;
    services.udisks2.enable = true;
    services.gvfs.enable = true;

    # Automount removable media
    fileSystems."/run/media" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = ["nosuid" "nodev" "mode=755" "uid=1000" "gid=100"];
    };

    systemd.user.services.udiskie = {
      description = "udiskie auto-mounter";
      wantedBy = ["graphical-session.target"];
      serviceConfig = {
        Restart = "always";
        ExecStart = "${pkgs.udiskie}/bin/udiskie";
        Environment = ["WAYLAND_DISPLAY=wayland-1"];
      };
    };

    # Ignore lid switch when docked or on external power; never idle-suspend on AC
    services.logind.settings.Login = {
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      IdleAction = "ignore";
      IdleActionSec = "infinity";
    };

    # KDE Connect — phone ↔ desktop integration (opens firewall ports 1714-1764)
    programs.kdeconnect.enable = cfg.kdeconnect;

    # LocalSend — AirDrop-for-everything. Opens TCP+UDP 53317 (LAN discovery).
    programs.localsend = {
      enable = true;
      openFirewall = true;
    };

    # gpu-screen-recorder — must come from this module, not systemPackages: it
    # installs the setcap wrapper that lets the kms capture backend work without
    # root. Driven by `dusky-screenrecord` (profiles/home/dusky-extras.nix).
    programs.gpu-screen-recorder.enable = true;

    # mosh — SSH that survives a wifi drop or a closed lid. Opens UDP
    # 60000-61000. Off unless desktop-base.mosh is set.
    programs.mosh.enable = cfg.mosh;

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
    ];
  };
}
