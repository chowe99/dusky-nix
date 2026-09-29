# profiles/home/common.nix — the desktop core of a dusky user: dusky-extras menu, Zen transparency seed, mako/battery unit fixes,
# default apps, autostart, the patched waybar themes (workspace names, RunCat,
# net-speed chomper), and first-login matugen/wallpaper bootstrap.
#
# Needs dusky-nix's own homeManagerModules (see lib.duskyModules) and the
# hyprland-keybindings module.
{
  config,
  pkgs,
  lib,
  dusky,
  ...
}: {
  imports = [
    ./zen-transparency.nix
    ./dusky-extras.nix
  ];

  # Omarchy-style menu + screenrecord/QR/transcode helpers. Its keybinds ride
  # on programs.hyprland-keybindings.extraConfig, which only the dusky variant
  # renders — so hosts that leave keybindings off just get the commands.
  programs.dusky-extras.enable = lib.mkDefault true;

  # All dusky users get the Transparent Zen mod seeded into their Zen profile (opt out per host).
  dusky-desktop.zenTransparency.enable = lib.mkDefault true;

  # Disable home-manager modules that dusky replaces (if a config enables them)
  wayland.windowManager.hyprland.enable = lib.mkForce false;
  programs.hyprland-keybindings.enable = lib.mkOverride 900 false;
  home.file.".config/rofi".enable = lib.mkForce false;
  programs.waybar.enable = lib.mkForce false;
  programs.hyprlock.enable = lib.mkForce false;
  # dusky's Hyprland autostart.conf launches mako directly (`uwsm-app -- mako`),
  # so this unit stays out of graphical-session.target (WantedBy = []) to avoid
  # a duplicate second instance racing for the D-Bus name at login. It exists
  # for two reasons instead:
  #   1. mako ships fr.emersion.mako.service, a D-Bus activation file that
  #      expects a real "mako.service" systemd unit to fall back to if nothing
  #      currently owns org.freedesktop.Notifications. Previously this option
  #      only set Install.WantedBy with no Unit/Service content, so
  #      home-manager wrote an empty unit file — systemd treats an empty unit
  #      as masked, so that fallback silently failed (confirmed in
  #      `journalctl --user`: "Activation request for 'org.freedesktop.Notifications'
  #      failed: The systemd unit 'mako.service' is masked"). Giving it a real
  #      ExecStart un-masks it, so any app's first notify-send after the
  #      exec-once instance has died (crash, OOM, whatever) auto-launches mako.
  #   2. Restart = "always" then supervises whichever instance ends up running
  #      under this unit (activated via #1, or manually via
  #      `systemctl --user start mako.service`) so a later crash self-heals
  #      instead of leaving notifications dead until the next reboot.
  systemd.user.services.mako = lib.mkForce {
    Unit = {
      Description = "Wayland notification daemon (org.freedesktop.Notifications)";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.mako}/bin/mako";
      Restart = "always";
      RestartSec = 1;
    };
    Install.WantedBy = [];
  };
  systemd.user.services.dusky-mako-osd.Unit.After = lib.mkForce ["graphical-session.target"];
  # No battery on any dusky host (all desktops) — script needs a TTY we don't have anyway
  systemd.user.services.dusky-battery-notify.Install.WantedBy = lib.mkForce [];

  # Dusky default apps (users can override in their home.nix).
  # Globals — source/keybinds.lua reads them.
  xdg.configFile."hypr/edit_here/source/default_apps.lua".text = lib.mkDefault ''
    terminal    = "kitty"
    fileManager = "yazi"
    menu        = "rofi -show drun"
    browser     = "firefox"
    textEditor  = "nvim"
  '';

  # Override dusky's autostart — launch waybar directly instead of via
  # dusky-waybar-autostart wrapper which gets killed by UWSM scope cleanup.
  # ponytail: replaces upstream's autostart.lua wholesale; it is entirely
  # commented out upstream, so there is nothing to preserve from it.
  xdg.configFile."hypr/source/autostart.lua".source = lib.mkForce (pkgs.writeText "autostart.lua" ''
    -- Dusky desktop autostart (NixOS)
    hl.on("hyprland.start", function()
        hl.exec_cmd("uwsm-app -- xhost +si:localuser:root")
        hl.exec_cmd("uwsm-app -- wl-paste --type text --watch cliphist store")
        hl.exec_cmd("uwsm-app -- wl-paste --type image --watch cliphist store")
        hl.exec_cmd("uwsm-app -- wl-clip-persist --clipboard regular")
        hl.exec_cmd("uwsm-app -- waybar")
        hl.exec_cmd("sleep 1 && dusky-theme-ctl restore || dusky-theme-ctl random")
        hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
        hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    end)
  '');

  # Workaround for dusky activation scripts that assume dirs exist
  home.activation.ensureDuskyDirs = lib.hm.dag.entryBefore ["createWaybarSymlinks"] ''
    run mkdir -p "$HOME/.config/waybar"
  '';

  # Waybar's hyprland/workspaces module shows the workspace id/a dot icon by
  # default. Switching its format to "{name}" lets hl.workspace_rule's
  # default_name (set per-workspace in edit_here/hyprland.lua, see that file)
  # show up on the bar instead of a number. xdg.configFile."waybar" is one
  # all-or-nothing directory tree owned by dusky-nix's waybar module, so there
  # is no way to override just that one JSON value — this rebuilds the same
  # derivation (same script-path sed patches + tui-modules.py button
  # rewiring) with one extra JSON-level patch applied to every theme.
  # ponytail: duplicates the sed list of home/waybar/default.nix; re-diff
  # against it after an upstream sync if
  # workspace names ever silently revert to numbers.
  xdg.configFile."waybar".source = lib.mkForce (let
    terminal = "${pkgs.kitty}/bin/kitty";
    # RunCat-style CPU cat (plugins.omarchy.org "Running Cat" — a Quickshell
    # widget, so only its gnome-runcat sprite frames are reused, GPL-3.0).
    runcat = pkgs.fetchFromGitHub {
      owner = "kaiizu";
      repo = "runningcat";
      rev = "63146002445fa92ea43c57973d56b21c1347deba";
      hash = "sha256-ivsUBVD4mdOsS5AiHhabQNa+ipBJdMK3RjRapU/u2dI=";
    };
    # Streams one waybar JSON line per frame; the class picks the sprite in CSS.
    # Cycle = 250ms at 100% CPU .. 1100ms at idle, eased by (1-x)^2 like RunCat.
    runcatStream = pkgs.writeShellScript "waybar-runcat" ''
      read -r _ a b c d e f g h _ < /proc/stat
      pt=$((a + b + c + d + e + f + g + h)) pi=$((d + e)) u=0 frame=0 next=0
      while :; do
        now=$(${pkgs.coreutils}/bin/date +%s%N)
        if ((now >= next)); then
          read -r _ a b c d e f g h _ < /proc/stat
          t=$((a + b + c + d + e + f + g + h)) i=$((d + e))
          ((t > pt)) && u=$((100 * ((t - pt) - (i - pi)) / (t - pt)))
          pt=$t pi=$i next=$((now + 2000000000))
        fi
        cls=\"f$frame\"
        ((u >= 90)) && cls="$cls,\"critical\"" || { ((u >= 70)) && cls="$cls,\"warning\""; }
        printf '{"text":"%s%%","tooltip":"CPU: %s%%","class":[%s]}\n' "$u" "$u" "$cls"
        frame=$(((frame + 1) % 5))
        ms=$(((250 + 850 * (100 - u) * (100 - u) / 10000) / 5))
        ${pkgs.coreutils}/bin/sleep "0.$(printf %03d "$ms")"
      done
    '';
    runcatCss = pkgs.writeText "runcat.css" (''
        #custom-runcat {
          padding-left: 26px;
          background-size: 20px 20px;
          background-repeat: no-repeat;
          background-position: 4px center;
        }
      ''
      + lib.concatMapStrings (n: ''
        #custom-runcat.f${n} { background-image: -gtk-recolor(url("${runcat}/assets/active/${n}.svg")); }
      '') ["0" "1" "2" "3" "4"]);
    # Chomper eating a row of dots for the net-speed module: 4 frames of mouth
    # (open → half → shut → half) with the dots stepping 1.5px toward it.
    chompFrames = lib.imap0 (k: mouth: let
      dots = lib.filter (x: x > 15 && x < 25) (map (j: 17 - 1.5 * k + 6 * j) [0 1 2]);
    in
      pkgs.writeText "chomp-${toString k}.svg" ''
        <svg xmlns="http://www.w3.org/2000/svg" width="26" height="24" viewBox="0 0 26 24">
          <path d="M8,12 L${mouth} Z" fill="#fff"/>
          ${lib.concatMapStrings (x: ''<circle cx="${toString x}" cy="12" r="1.4" fill="#fff"/>'') dots}
        </svg>
      '') [
      "13.36,7.5 A7,7 0 1,0 13.36,16.5"
      "14.49,9.38 A7,7 0 1,0 14.49,14.62"
      "14.98,11.51 A7,7 0 1,0 14.98,12.49"
      "14.49,9.38 A7,7 0 1,0 14.49,14.62"
    ];
    # Wraps dusky's meter: same text/tooltip/class, plus an n<frame> class
    # whose rate follows total up+down throughput (log-ish tiers).
    netStream = pkgs.writeShellScript "waybar-net-chomp" ''
      state="''${XDG_RUNTIME_DIR:-/run/user/$UID}/waybar-net/state"
      frame=0 next=0 ms=400 out='{}'
      while :; do
        now=''${EPOCHREALTIME/./}
        if ((now >= next)); then
          out=$(dusky-waybar-network-meter "$@")
          unit=- up=0 down=0
          [[ -r $state ]] && read -r unit up down _ < "$state"
          up=''${up//[!0-9.]/} down=''${down//[!0-9.]/}
          kb=$((10#''${up%.*}0 / 10 + 10#''${down%.*}0 / 10))
          [[ $unit == MB ]] && kb=$((kb * 1024))
          if ((kb < 5)); then ms=400
          elif ((kb < 100)); then ms=220
          elif ((kb < 1000)); then ms=130
          elif ((kb < 10000)); then ms=80
          else ms=45
          fi
          next=$((now + 1000000))
        fi
        cls=
        [[ $out =~ \"class\":\"([^\"]*)\" ]] && cls=''${BASH_REMATCH[1]}
        old="\"class\":\"$cls\"" new="\"class\":[\"$cls\",\"n$frame\"]"
        printf '%s\n' "''${out/"$old"/"$new"}"
        frame=$(((frame + 1) % 4))
        ${pkgs.coreutils}/bin/sleep "0.$(printf %03d "$ms")"
      done
    '';
    netCss = pkgs.writeText "net-chomp.css" (''
        #custom-net-speed {
          padding-left: 30px;
          background-size: 22px 20px;
          background-repeat: no-repeat;
          background-position: 5px center;
        }
      ''
      + lib.concatImapStrings (i: f: ''
        #custom-net-speed.n${toString (i - 1)} { background-image: -gtk-recolor(url("${f}")); }
      '')
      chompFrames);
    patchedThemes = pkgs.runCommand "dusky-waybar-themes-patched" {} ''
      cp -r ${dusky}/.config/waybar $out
      chmod -R u+w $out

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
        -e 's|python3 ~/user_scripts/waybar/weather.py|dusky-waybar-weather|g' \
        -e 's|python3 \$HOME/user_scripts/waybar/weather.py|dusky-waybar-weather|g' \
        -e 's|pactl set-sink-mute @DEFAULT_SINK@ toggle|dusky-osd-router --vol-mute|g' \
        -e 's|pactl set-sink-volume @DEFAULT_SINK@ +5%|dusky-osd-router --vol-up 5|g' \
        -e 's|pactl set-sink-volume @DEFAULT_SINK@ -5%|dusky-osd-router --vol-down 5|g' \
        -e 's|brightnessctl set +5%|dusky-osd-router --bright-up 5|g' \
        -e 's|brightnessctl set 5%-|dusky-osd-router --bright-down 5|g' \
        -e 's|"format-bluetooth": "󰂰|"format-bluetooth": "{icon}|' \
        -e 's|"format-bluetooth-muted": "󰂲|"format-bluetooth-muted": "󰖁|' \
        {} +

      ${pkgs.python3}/bin/python3 ${../../home/waybar/tui-modules.py} $out \
        "${terminal} --class dusky-tui -e ${pkgs.impala}/bin/impala" \
        "${terminal} --class dusky-tui -e ${pkgs.bluetui}/bin/bluetui" \
        "${terminal} --class dusky-tui -e ${pkgs.wiremix}/bin/wiremix"

      ${pkgs.python3}/bin/python3 ${pkgs.writeText "waybar-workspace-names.py" ''
        import json, pathlib, sys

        def strip_jsonc(text):
            out, i, n = [], 0, len(text)
            while i < n:
                c = text[i]
                if c == '"':
                    j = i + 1
                    while j < n:
                        if text[j] == "\\":
                            j += 2
                            continue
                        if text[j] == '"':
                            break
                        j += 1
                    out.append(text[i : j + 1])
                    i = j + 1
                elif text.startswith("//", i):
                    i = text.find("\n", i)
                    if i == -1:
                        break
                elif text.startswith("/*", i):
                    i = text.find("*/", i)
                    i = n if i == -1 else i + 2
                else:
                    out.append(c)
                    i += 1
            import re
            return re.sub(r",(\s*[}\]])", r"\1", "".join(out))

        def patch(path):
            try:
                cfg = json.loads(strip_jsonc(path.read_text()))
            except (ValueError, UnicodeDecodeError) as e:
                print(f"skip {path}: {e}", file=sys.stderr)
                return
            if not isinstance(cfg, dict):
                return
            ws = cfg.get("hyprland/workspaces")
            if isinstance(ws, dict):
                ws["format"] = "{name}"
            # Swap the cpu module for the running cat, keeping its click actions.
            cpu = cfg.pop("cpu", None)
            if isinstance(cpu, dict):
                for v in cfg.values():
                    if isinstance(v, dict) and isinstance(v.get("modules"), list):
                        v["modules"] = ["custom/runcat" if m == "cpu" else m for m in v["modules"]]
                for k in ("modules-left", "modules-center", "modules-right"):
                    if isinstance(cfg.get(k), list):
                        cfg[k] = ["custom/runcat" if m == "cpu" else m for m in cfg[k]]
                cfg["custom/runcat"] = {
                    "exec": "${runcatStream}",
                    "return-type": "json",
                    **{k: v for k, v in cpu.items() if k.startswith("on-")},
                }
                css = path.with_name("style.css")
                if css.exists():
                    css.write_text(css.read_text().replace("#cpu", "#custom-runcat") + "\n" + pathlib.Path("${runcatCss}").read_text())
            # Stream the net-speed meter through the chomper wrapper.
            net = cfg.get("custom/net-speed")
            if isinstance(net, dict) and str(net.get("exec", "")).startswith("dusky-waybar-network-meter"):
                net["exec"] = "${netStream}" + net["exec"][len("dusky-waybar-network-meter"):]
                net.pop("interval", None)
                css = path.with_name("style.css")
                if css.exists():
                    css.write_text(css.read_text() + "\n" + pathlib.Path("${netCss}").read_text())
            path.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")

        for p in pathlib.Path(sys.argv[1]).rglob("config.jsonc"):
            patch(p)
      ''} $out
    '';
  in
    patchedThemes);

  # Override dusky's matugen activation — `matugen image` needs a display/terminal.
  # Fetch a random wallpaper from dusklinux/images, try matugen image, fall back to color hex.
  home.activation.createMatugenGenerated = lib.mkForce (lib.hm.dag.entryAfter ["linkGeneration"] ''
    run mkdir -p "$HOME/.config/matugen/generated"
    run mkdir -p "$HOME/Pictures/wallpapers"
    if [ ! -f "$HOME/.config/matugen/generated/rofi-colors.rasi" ] || [ ! -f "$HOME/.config/matugen/generated/mako-colors" ]; then
      WALLPAPER="$HOME/Pictures/wallpapers/dusk_default.jpg"
      if command -v ${pkgs.curl}/bin/curl >/dev/null 2>&1; then
        TREE_SHA=$(${pkgs.curl}/bin/curl -sf "https://api.github.com/repos/dusklinux/images/git/trees/main" \
          | ${pkgs.jq}/bin/jq -r '.tree[] | select(.path == "dark") | .sha' 2>/dev/null) || true
        if [ -n "$TREE_SHA" ]; then
          PICK=$(${pkgs.curl}/bin/curl -sf "https://api.github.com/repos/dusklinux/images/git/trees/$TREE_SHA" \
            | ${pkgs.jq}/bin/jq -r '.tree[].path' 2>/dev/null | shuf -n 1) || true
          if [ -n "$PICK" ]; then
            FETCHED="$HOME/Pictures/wallpapers/$PICK"
            if [ ! -f "$FETCHED" ]; then
              ${pkgs.curl}/bin/curl -sfL "https://raw.githubusercontent.com/dusklinux/images/main/dark/$PICK" \
                -o "$FETCHED" 2>/dev/null || true
            fi
            [ -f "$FETCHED" ] && WALLPAPER="$FETCHED"
          fi
        fi
      fi
      run ${pkgs.matugen}/bin/matugen \
        -c "$HOME/.config/matugen/config.toml" \
        --mode dark \
        image "$WALLPAPER" 2>/dev/null || \
      run ${pkgs.matugen}/bin/matugen \
        -c "$HOME/.config/matugen/config.toml" \
        --mode dark \
        color hex '6750a4' || true
    fi
  '');

  # Fetch a dusky wallpaper + generate matugen colors on first boot (after network is up)
  systemd.user.services.dusky-wallpaper-fetch = {
    Unit = {
      Description = "Fetch dusky wallpaper and generate matugen colors";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = let
        script = pkgs.writeShellScript "dusky-wallpaper-fetch" ''
          set -euo pipefail
          mkdir -p "$HOME/Pictures/wallpapers" "$HOME/.config/matugen/generated"

          if [ -f "$HOME/.config/matugen/generated/rofi-colors.rasi" ] && [ -f "$HOME/.config/matugen/generated/mako-colors" ]; then
            exit 0
          fi

          WALLPAPER="$HOME/Pictures/wallpapers/dusk_default.jpg"

          # Fetch a random dark wallpaper from dusklinux/images
          TREE_SHA=$(${pkgs.curl}/bin/curl -sf "https://api.github.com/repos/dusklinux/images/git/trees/main" \
            | ${pkgs.jq}/bin/jq -r '.tree[] | select(.path == "dark") | .sha' 2>/dev/null) || true
          if [ -n "''${TREE_SHA:-}" ]; then
            PICK=$(${pkgs.curl}/bin/curl -sf "https://api.github.com/repos/dusklinux/images/git/trees/$TREE_SHA" \
              | ${pkgs.jq}/bin/jq -r '.tree[].path' 2>/dev/null | shuf -n 1) || true
            if [ -n "''${PICK:-}" ]; then
              FETCHED="$HOME/Pictures/wallpapers/$PICK"
              [ -f "$FETCHED" ] || ${pkgs.curl}/bin/curl -sfL \
                "https://raw.githubusercontent.com/dusklinux/images/main/dark/$PICK" \
                -o "$FETCHED" 2>/dev/null || true
              [ -f "$FETCHED" ] && WALLPAPER="$FETCHED"
            fi
          fi

          # Generate matugen colors from wallpaper, fall back to hex color
          ${pkgs.matugen}/bin/matugen \
            -c "$HOME/.config/matugen/config.toml" \
            --mode dark \
            image "$WALLPAPER" 2>/dev/null || \
          ${pkgs.matugen}/bin/matugen \
            -c "$HOME/.config/matugen/config.toml" \
            --mode dark \
            color hex '6750a4' || true
        '';
      in "${script}";
      RemainAfterExit = true;
    };
    Install.WantedBy = ["default.target"];
  };
}
