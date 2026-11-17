{
  pkgs,
  dusky,
}: let
  scriptDir = "${dusky}/user_scripts/battery";
  # asusctl / tlp come from their NixOS services (services.asusd, services.tlp),
  # and sudo from /run/wrappers, so they are allowlisted in checks/runtime-deps
  # rather than wrapped here.
  # ponytail: no ddcutil: without i2c-dev (nothing here enables it) it aborts the
  # whole transition. A user-installed ddcutil on PATH is still used.
  powerSaverDeps = with pkgs; [hyprland brightnessctl coreutils gum hyprshade playerctl wireplumber util-linux systemd bash];
  hypr = import ./hypr-scripts.nix {inherit pkgs dusky;};
  theme = import ./theme-scripts.nix {inherit pkgs dusky;};
  # Upstream rewrote the power saver as stateful Python 3.15 (`lazy import`,
  # builtin frozendict) that reads <script>.toml from beside itself. The
  # integrations must be absolute executables, so point them at our packages.
  # Targets: dusky-nix runs kokoro/parakeet/battery-notify/hyprsunset/awww as
  # user units under its own names. Bare processes are dropped: Nix wrappers
  # `exec -a` the wrapper path, which the script refuses to restore (argv[0]).
  # ponytail: so waybar isn't stopped; tlp_script (tlp_mode_toggle.sh) isn't
  # packaged, so it falls back to plain `tlp`/`tlp-stat`.
  powerSaver = pkgs.runCommand "dusky-power-saver" {nativeBuildInputs = [pkgs.makeWrapper];} ''
    mkdir -p $out/libexec $out/bin
    cp ${scriptDir}/power_saver/power_saver.py $out/libexec/
    substitute ${scriptDir}/power_saver/power_saver.toml $out/libexec/power_saver.toml \
      --replace-fail '~/user_scripts/hypr/hypr_blur_opacity_shadow_toggle.sh' '${hypr}/bin/dusky-blur-toggle' \
      --replace-fail '~/user_scripts/theme_matugen/theme_ctl.sh' '${theme}/bin/dusky-theme-ctl' \
      --replace-fail '"battery_notify",' '"dusky-battery-notify",' \
      --replace-fail '"dusky_kokoro.socket", "dusky_kokoro", "dusky_stt"]' '"dusky-kokoro-tts", "dusky-parakeet-stt", "hyprsunset", "awww-daemon"]' \
      --replace-fail 'processes = ["hyprsunset", "awww-daemon", "waybar", "blueman-manager"]' 'processes = []' \
      --replace-fail 'scripts = ["dusky_main.py", "dusky_stt_main.py"]' 'scripts = []'
    for v in dusky-power-saver: dusky-power-saver-off:--disable; do
      makeWrapper ${pkgs.python315}/bin/python3 $out/bin/''${v%%:*} \
        --add-flags "$out/libexec/power_saver.py ''${v#*:}" \
        --prefix PATH : ${pkgs.lib.makeBinPath powerSaverDeps}
    done
  '';
in
  pkgs.symlinkJoin {
    name = "dusky-battery-scripts";
    paths = [
      # Upstream rewrote the daemon as notify/battery_notify.sh: event-driven
      # on `upower --monitor-detail`, thresholds overridable from the
      # environment. Its config TUI (tui_battery.py) edits the script in place,
      # which a store path can't take, so it isn't packaged.
      (pkgs.writeShellApplication {
        checkPhase = "";
        name = "dusky-battery-notify";
        runtimeInputs = with pkgs; [upower libnotify pulseaudio pipewire gawk gnused systemd];
        text =
          builtins.replaceStrings
          ["/usr/share/sounds/freedesktop"]
          ["${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop"]
          (builtins.readFile "${scriptDir}/notify/battery_notify.sh");
      })
      powerSaver
    ];
  }
