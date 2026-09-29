# profiles/home/dusky-extras.nix — Omarchy-style desktop extras for dusky hosts
#
# Ports the pieces of Omarchy that dusky doesn't already have:
#   * dusky-menu         — one searchable "spotlight" menu (SUPER+SPACE)
#   * dusky-screenrecord — gpu-screen-recorder + optional webcam bubble
#   * dusky-qr           — decode a QR code off the screen into the clipboard
#   * dusky-transcode    — shrink a video / make a GIF / convert an image or the clipboard
#   * impala / bluetui / wiremix — the same wifi/bluetooth/audio TUIs Omarchy uses
#
# LocalSend, mosh and the gpu-screen-recorder setcap wrapper are system-level;
# they live in profiles/nixos/desktop-base.nix.
#
# ponytail: everything here is a shell script over tools that already exist.
# No daemons, no state beyond one pidfile.
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}: let
  cfg = config.programs.dusky-extras;

  # lazydocker entries (cfg.docker). Each carries its own leading newline and is
  # spliced onto the END of the line before it, so a disabled entry leaves no
  # blank line behind — a blank line inside the menu's printf `\` continuation
  # would end the command.
  dockerCase = lib.optionalString cfg.docker "\n    *docker*)       run ${term} --class dusky-tui -e lazydocker ;;";
  dockerAction = lib.optionalString cfg.docker "\n    \"  Docker (lazydocker)\" \\";
  dockerBind = lib.optionalString cfg.docker "\nhl.bind(\"SUPER + CTRL + D\",  hl.dsp.exec_cmd(\"uwsm-app -- ${term} --class dusky-tui -e lazydocker\"), { description = \"Docker (lazydocker)\" })";

  # Dusky's configured terminal (edit_here/source/default_apps.lua). Needs
  # --class so the float window rules below can match.
  term = "${pkgs.kitty}/bin/kitty";
  tui = cls: cmd: "${term} --class ${cls} -e ${cmd}";

  bin = pkgs.lib.makeBinPath;

  # ---------------------------------------------------------------------------
  # Screen recording. Adapted from omarchy-capture-screenrecording: same
  # gpu-screen-recorder backend, same slurp-with-frozen-screen picker, same
  # "default_output|default_input" audio merge (separate tracks only play one
  # at a time in most players).
  # gpu-screen-recorder itself comes from programs.gpu-screen-recorder.enable —
  # the /run/wrappers setcap build, which is what makes kms capture work.
  # ---------------------------------------------------------------------------
  screenrecord = pkgs.writeShellScriptBin "dusky-screenrecord" ''
    export PATH="${bin [pkgs.jq pkgs.slurp pkgs.hyprpicker pkgs.libnotify pkgs.ffmpeg-full pkgs.v4l-utils pkgs.procps pkgs.coreutils]}:/run/wrappers/bin:$PATH"
    set -u

    OUTPUT_DIR="''${XDG_VIDEOS_DIR:-$HOME/Videos}"
    PIDFILE="''${XDG_RUNTIME_DIR:-/tmp}/dusky-screenrecord.pid"
    NAMEFILE="''${XDG_RUNTIME_DIR:-/tmp}/dusky-screenrecord.name"

    desktop_audio=false; mic_audio=false; webcam=false; webcam_device=""
    for arg in "$@"; do
      case "$arg" in
        --with-desktop-audio) desktop_audio=true ;;
        --with-microphone-audio) mic_audio=true ;;
        --with-webcam) webcam=true ;;
        --webcam-device=*) webcam_device="''${arg#*=}" ;;
        --stop) : ;;
      esac
    done

    recording() { [ -s "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

    cleanup_webcam() { pkill -f "dusky-webcam-bubble" 2>/dev/null || true; }

    stop_recording() {
      kill -INT "$(cat "$PIDFILE")" 2>/dev/null || true
      for _ in $(seq 50); do recording || break; sleep 0.1; done
      recording && kill -9 "$(cat "$PIDFILE")" 2>/dev/null
      cleanup_webcam
      f="$(cat "$NAMEFILE" 2>/dev/null || true)"
      rm -f "$PIDFILE" "$NAMEFILE"
      notify-send "Screen recording saved" "''${f:-$OUTPUT_DIR}" -t 5000
    }

    if recording; then stop_recording; exit 0; fi
    case " $* " in *" --stop "*) exit 1 ;; esac

    mkdir -p "$OUTPUT_DIR"

    # Monitor + window rectangles on the focused workspace, so a bare click
    # snaps to a whole window/monitor instead of a 2px region.
    rectangles() {
      ws=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .activeWorkspace.id')
      hyprctl monitors -j | jq -r --arg ws "$ws" \
        '.[] | select(.activeWorkspace.id == ($ws|tonumber)) | "\(.x),\(.y) \(.width/.scale|floor)x\(.height/.scale|floor)"'
      hyprctl clients -j | jq -r --arg ws "$ws" \
        '.[] | select(.workspace.id == ($ws|tonumber)) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
    }

    # hyprpicker -r -z freezes the screen so the picker shows a still frame.
    rects=$(rectangles)
    hyprpicker -r -z >/dev/null 2>&1 &
    picker=$!
    sleep 0.1
    sel=$(printf '%s\n' "$rects" | slurp 2>/dev/null || true)
    kill $picker 2>/dev/null || true
    [ -n "$sel" ] || exit 1

    sx=''${sel%%,*}; rest=''${sel#*,}
    sy=''${rest%% *}; wh=''${rest#* }
    sw=''${wh%%x*}; sh=''${wh#*x}

    if [ "$((sw * sh))" -lt 20 ]; then
      while read -r r; do
        [ -n "$r" ] || continue
        rx=''${r%%,*}; rr=''${r#*,}; ry=''${rr%% *}; rwh=''${rr#* }
        rw=''${rwh%%x*}; rh=''${rwh#*x}
        if [ "$sx" -ge "$rx" ] && [ "$sx" -lt "$((rx + rw))" ] &&
           [ "$sy" -ge "$ry" ] && [ "$sy" -lt "$((ry + rh))" ]; then
          sx=$rx; sy=$ry; sw=$rw; sh=$rh; break
        fi
      done <<< "$rects"
    fi

    # An exact monitor match records that output natively (no scaling math).
    monitor=$(hyprctl monitors -j | jq -r --argjson x "$sx" --argjson y "$sy" --argjson w "$sw" --argjson h "$sh" \
      '.[] | select(.x==$x and .y==$y and (.width/.scale|floor)==$w and (.height/.scale|floor)==$h) | .name' | head -1)
    if [ -n "$monitor" ]; then target="$monitor"; else target="''${sw}x''${sh}+''${sx}+''${sy}"; fi

    if [ "$webcam" = true ]; then
      cleanup_webcam
      if [ -z "$webcam_device" ]; then
        webcam_device=$(v4l2-ctl --list-devices 2>/dev/null | grep -m1 '^[[:space:]]*/dev/video' | tr -d '\t')
      fi
      if [ -n "$webcam_device" ]; then
        scale=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .scale')
        width=$(awk "BEGIN {printf \"%.0f\", 360 * $scale}")
        size=""
        formats=$(v4l2-ctl --list-formats-ext -d "$webcam_device" 2>/dev/null || true)
        for r in 640x360 1280x720 1920x1080; do
          case "$formats" in *"$r"*) size="-video_size $r"; break ;; esac
        done
        # shellcheck disable=SC2086
        ffplay -f v4l2 $size -framerate 30 "$webcam_device" \
          -vf "scale=$width:-1" -window_title "dusky-webcam-bubble" -noborder \
          -fflags nobuffer -flags low_delay -probesize 32 -analyzeduration 0 \
          -loglevel quiet >/dev/null 2>&1 &
        sleep 1
      else
        notify-send "No webcam found" -u critical -t 3000
      fi
    fi

    audio=""
    [ "$desktop_audio" = true ] && audio="default_output"
    [ "$mic_audio" = true ] && audio="''${audio:+$audio|}default_input"

    file="$OUTPUT_DIR/screenrecording-$(date +'%Y-%m-%d_%H-%M-%S').mp4"
    if [ -n "$audio" ]; then
      gpu-screen-recorder -w "$target" -k auto -f 60 -fm cfr -fallback-cpu-encoding yes \
        -a "$audio" -ac aac -o "$file" >/dev/null 2>&1 &
    else
      gpu-screen-recorder -w "$target" -k auto -f 60 -fm cfr -fallback-cpu-encoding yes \
        -o "$file" >/dev/null 2>&1 &
    fi
    pid=$!

    while kill -0 $pid 2>/dev/null && [ ! -f "$file" ]; do sleep 0.2; done
    if kill -0 $pid 2>/dev/null; then
      echo "$pid" > "$PIDFILE"; echo "$file" > "$NAMEFILE"
      notify-send "Recording…" "Stop with SUPER+CTRL+R" -t 2500
    else
      cleanup_webcam
      notify-send "Screen recording failed" -u critical -t 4000
    fi
  '';

  # ---------------------------------------------------------------------------
  # QR decode — same shape as the existing OCR bind, zbarimg instead of ocr.
  # -Stest-inverted: also read light-on-dark codes (zbar skips them by default).
  # `$(mktemp).png` because the system mktemp is toybox and has no --suffix.
  # ---------------------------------------------------------------------------
  qr = pkgs.writeShellScriptBin "dusky-qr" ''
    export PATH="${bin [pkgs.slurp pkgs.grim pkgs.zbar pkgs.wl-clipboard pkgs.libnotify pkgs.coreutils]}:$PATH"
    f="$(mktemp).png"
    trap 'rm -f "$f"' EXIT
    slurp | grim -g - "$f" || exit 1
    text=$(zbarimg --raw -q -Stest-inverted "$f" 2>/dev/null || true)
    if [ -z "$text" ]; then
      notify-send "No QR code found" -u critical -t 3000
      exit 1
    fi
    printf '%s' "$text" | wl-copy
    notify-send "QR copied to clipboard" "$text" -t 5000
  '';

  # ---------------------------------------------------------------------------
  # Transcode — shrink a video / turn it into a GIF, or convert an image
  # (file, copied file, or clipboard image) to PNG/JPG/WebP/AVIF. Omarchy's
  # `omarchy transcode` does images too but only from files and only to jpg/png.
  # Whatever came off the clipboard goes back on it: image data as image data,
  # a copied file as a copied file.
  # ---------------------------------------------------------------------------
  transcode = pkgs.writeShellScriptBin "dusky-transcode" ''
    export PATH="${bin [pkgs.ffmpeg-full pkgs.imagemagick pkgs.wl-clipboard pkgs.rofi pkgs.libnotify pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.file pkgs.jq]}:$PATH"
    pick() { rofi -dmenu -i -p "$1"; }
    fail() { notify-send "Transcode failed" "$1" -u critical -t 5000; exit 1; }
    clip_entry="󰅌  Clipboard image"
    clip_prefix="󰅌  Copied: "

    # Files copied in a file manager arrive as a text/uri-list of
    # percent-encoded file:// URIs (CRLF-terminated). Type is sniffed, not
    # taken from the name: browser downloads end up as `x.svg?utm_source=…`.
    clip_files() {
      wl-paste --list-types 2>/dev/null | grep -qx 'text/uri-list' || return
      wl-paste --type text/uri-list 2>/dev/null | tr -d '\r' | while read -r u || [ -n "$u" ]; do
        [[ $u == file://* ]] || continue
        p=''${u#file://}; p=''${p#localhost}; p=''${p//\\/\\\\}
        printf -v p '%b' "''${p//%/\\x}"
        [ -f "$p" ] || continue
        case $(file -b --mime-type "$p") in image/* | video/*) printf '%s\n' "$p" ;; esac
      done
    }

    copy_out() {
      case "$clip" in
        data) wl-copy --type "image/''${fmt/jpg/jpeg}" < "$out" ;;
        file) jq -rn --arg p "$out" '"file://" + ($p | @uri | gsub("%2F"; "/"))' | wl-copy --type text/uri-list ;;
      esac
    }

    # Best image type on the clipboard: vector first, then png, then anything.
    # SVG source copied as plain text (devtools, icon sites) counts as svg.
    clip_type() {
      types=$(wl-paste --list-types 2>/dev/null) || return 1
      for want in '^image/svg+xml$' '^image/png$' '^image/'; do
        t=$(printf '%s\n' "$types" | grep -m1 "$want") && { echo "$t"; return; }
      done
      wl-paste --type text 2>/dev/null | head -c 65536 | grep -q '<svg' && echo text/svg
    }

    image() {
      fmt=$(printf '%s\n' PNG JPG WebP AVIF | pick "Format")
      [ -n "$fmt" ] || exit 0
      fmt=''${fmt,,}
      pre=() post=()
      if [ "$mime" = image/svg+xml ]; then
        # Rasterise at the target size; resizing the default 96-dpi render blurs.
        size=$(printf '%s\n' 1024 2048 512 256 | pick "Size (px, longest side)")
        [[ $size =~ ^[1-9][0-9]*$ ]] || exit 0
        dim=$(magick identify -format '%[fx:max(w,h)]' "$file" 2>/dev/null)
        [[ $dim =~ ^[1-9][0-9]*$ ]] || dim=$size
        pre=(-background none -density $((96 * size / dim)))
        post=(-resize "''${size}x''${size}")
      fi
      case "$fmt" in
        jpg)       post+=(-background white -alpha remove -alpha off -quality 85) ;;
        webp|avif) post+=(-quality 80) ;;
      esac

      out="$base.$fmt"
      # Never clobber the input (png → png) or an earlier conversion.
      [ -e "$out" ] && out="$base-$(date +%Y%m%d-%H%M%S).$fmt"
      magick "''${pre[@]}" "$file" "''${post[@]}" -strip "$out" || fail "$file"
      copy_out
      notify-send "Converted''${clip:+ (copied)}" "$out ($(du -h "$out" | cut -f1))" -t 6000
    }

    file="''${1:-}" clip=""
    if [ -z "$file" ]; then
      # A copied file beats image data: file managers may offer both, and the
      # file is the original (an SVG stays vector).
      mapfile -t cf < <(clip_files)
      [ ''${#cf[@]} -eq 0 ] && ct=$(clip_type)
      list=$(find "$HOME/Videos" "$HOME/Pictures" "$HOME/Downloads" -maxdepth 2 -type f \
        \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.mov' \
        -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \
        -o -iname '*.avif' -o -iname '*.heic' -o -iname '*.svg' \) \
        -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-) # no cap: files keep old mtimes (downloads), type to filter
      [ -n "$ct" ] && list=$(printf '%s\n' "$clip_entry" "$list")
      [ ''${#cf[@]} -gt 0 ] && list=$(printf '%s\n' "''${cf[@]/#/$clip_prefix}" "$list")
      [ -n "$list" ] || { notify-send "Nothing to transcode" -u critical -t 3000; exit 1; }
      file=$(printf '%s\n' "$list" | pick "Transcode")
    fi

    case "$file" in
      "$clip_entry")
        # Saved to ~/Pictures (webp/avif rarely paste anywhere) and copied back.
        ext=''${ct#*/}; ext=''${ext%%+*}
        tmp=$(mktemp); file="$tmp.$ext"; trap 'rm -f "$tmp" "$file"' EXIT
        case "$ct" in text/*) wl-paste --type text ;; *) wl-paste --type "$ct" ;; esac > "$file"
        [ -s "$file" ] || fail "clipboard is empty"
        mkdir -p "$HOME/Pictures"
        base="$HOME/Pictures/clipboard-$(date +%Y%m%d-%H%M%S)" clip=data mime="image/''${ext/svg/svg+xml}"
        image; exit
        ;;
      "$clip_prefix"*) file=''${file#"$clip_prefix"} clip=file ;;
    esac
    [ -n "$file" ] && [ -f "$file" ] || exit 1
    # Drop a download's `?utm_…` tail before the extension, else the output is
    # named `x.svg?utm_source=commons.wikimedia.png`.
    base=''${file%%\?*}; base=''${base%.*}
    mime=$(file -b --mime-type "$file")
    case "$mime" in
      video/*) ;;
      image/*) image; exit ;;
      *) fail "$(basename "$file"): not an image or video ($mime)" ;;
    esac

    choice=$(printf '%s\n' "720p MP4" "1080p MP4" "Small MP4 (crf 30)" "GIF" | pick "Format")
    case "$choice" in
      "720p MP4")   out="$base-720p.mp4";  args=(-vf scale=-2:720 -c:v libx264 -crf 23 -preset veryfast -c:a aac) ;;
      "1080p MP4")  out="$base-1080p.mp4"; args=(-vf scale=-2:1080 -c:v libx264 -crf 23 -preset veryfast -c:a aac) ;;
      "Small MP4"*) out="$base-small.mp4"; args=(-vf scale=-2:720 -c:v libx264 -crf 30 -preset veryfast -c:a aac -b:a 96k) ;;
      "GIF")        out="$base.gif";       args=(-vf "fps=15,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" -loop 0) ;;
      *) exit 0 ;;
    esac

    notify-send "Transcoding…" "$(basename "$out")" -t 3000
    if ffmpeg -y -i "$file" "''${args[@]}" "$out" -loglevel error; then
      copy_out
      notify-send "Transcoded''${clip:+ (copied)}" "$out ($(du -h "$out" | cut -f1))" -t 6000
    else
      notify-send "Transcode failed" "$file" -u critical -t 5000
    fi
  '';

  # ---------------------------------------------------------------------------
  # dusky-menu — Omarchy's menu, flattened.
  #
  # Omarchy nests everything under 10 categories; that means you can't type
  # "screenrecord" at the top level. Here the top level IS the leaf list, so the
  # menu doubles as a search box. Submenus only exist where Omarchy has a real
  # choice to make (screenrecord audio, reminder).
  #
  # `dusky-menu <name>` jumps straight to a submenu, same as omarchy-menu.
  # ---------------------------------------------------------------------------
  # rofi script mode: no args = print the choices, one arg = act on the
  # selection. Kept separate from dusky-menu because dusky-menu's own no-arg
  # behaviour is "open the menu", which is the opposite of what rofi wants.
  # Resolves dusky-menu from PATH rather than the store to avoid a cycle.
  # Disk usage. Omarchy's is one desktop entry —
  #   Exec=xdg-terminal-exec --app-id=TUI.float -e bash -c "dua i /"
  # (omarchy applications/Disk Usage.desktop @ 8e65151f, "Use dua") — a live
  # `dua i /` every time, no cache.
  #
  # That is unusable on a big disk: a full traversal of a multi-TiB / with
  # millions of entries takes minutes. So the live scan is kept (deletion only
  # works against a real filesystem) and a cached snapshot is added in front of
  # it. dua has both halves natively — `interactive --export/--import`.
  #
  # ponytail: no custom cache format, no daemon. A timer writes one snapshot
  # file; the menu opens it.
  # Writing the snapshot is root's job (profiles/nixos/disk-snapshot.nix) — a
  # user-level walk silently under-reports /var. This
  # side only reads it, and shares that module's exclusion list so the live
  # scan skips the same things.
  diskCfg = osConfig.dusky-desktop.diskSnapshot;
  diskIgnore = lib.concatMapStringsSep " " (d: "-i ${lib.escapeShellArg d}") diskCfg.ignoreDirs;

  disk = pkgs.writeShellScriptBin "dusky-disk" ''
    export PATH="${bin [pkgs.dua pkgs.systemd pkgs.coreutils pkgs.libnotify]}:$PATH"
    snap="${diskCfg.path}"

    case "''${1:-}" in
      --refresh)
        systemctl start --no-block dua-snapshot.service &&
          notify-send "Disk snapshot refreshing" "Runs at idle priority; check back in a few minutes" -t 5000
        ;;
      # Omarchy's exact behaviour. Deletion works here and only here — an
      # imported snapshot is a picture of the disk, not the disk.
      # Takes an optional path, because a live scan of / here costs 7 minutes:
      # find the fat directory in the snapshot, then scan just that to delete.
      --live) shift; exec dua interactive -x ${diskIgnore} "''${@:-/}" ;;
      *)
        if [ -r "$snap" ]; then
          exec dua interactive --import "$snap"
        else
          notify-send "No disk snapshot yet" "Run: dusky-disk --refresh" -t 5000
          exec dua interactive -x ${diskIgnore} /
        fi
        ;;
    esac
  '';

  menuActions = pkgs.writeShellScriptBin "dusky-menu-actions" ''
    [ $# -eq 0 ] && exec dusky-menu --list
    setsid dusky-menu "$1" >/dev/null 2>&1 &
  '';

  menu = pkgs.writeShellScriptBin "dusky-menu" ''
    export PATH="${bin [pkgs.rofi pkgs.libnotify pkgs.coreutils pkgs.systemd pkgs.procps pkgs.wl-clipboard pkgs.yazi pkgs.gnugrep]}:$PATH"

    pick() { rofi -dmenu -i -p "$1…" ''${2:-}; }
    ask() { : | rofi -dmenu -p "$1…"; }
    run() { setsid uwsm-app -- "$@" >/dev/null 2>&1 & }
    sh_run() { setsid sh -c "$1" >/dev/null 2>&1 & }

    # dusky-screenshot's own modes. NOTE: no --notify flag exists (only
    # --no-notify); passing it is a fatal "Unknown option" — which is why the
    # menu's screenshot entry did nothing, and why dusky's own SUPER+S is
    # broken upstream. Notifications are on by default.
    screenshot_menu() {
      case $(printf '%s\n' \
        "  Region" \
        "  Window" \
        "  Fullscreen" \
        "  Smart (drag, or click a window)" \
        "  Region + annotate" | pick "Screenshot") in
        *Region\ +*)  sh_run "dusky-screenshot --region --freeze --annotate --tool arrow" ;;
        *Region)      sh_run "dusky-screenshot --region --freeze" ;;
        *Window)      sh_run "dusky-screenshot --window --freeze" ;;
        *Fullscreen)  sh_run "dusky-screenshot --fullscreen" ;;
        *Smart*)      sh_run "dusky-screenshot --smart --freeze" ;;
      esac
    }

    screenrecord_menu() {
      # Already recording? The keybind and the menu both just stop it.
      dusky-screenrecord --stop && exit 0
      case $(printf '%s\n' \
        "  With no audio" \
        "  With desktop audio" \
        "  With desktop + microphone audio" \
        "  With desktop + microphone audio + webcam" | pick "Screenrecord") in
        *"no audio") sh_run "dusky-screenrecord" ;;
        *"desktop audio") sh_run "dusky-screenrecord --with-desktop-audio" ;;
        *"microphone audio") sh_run "dusky-screenrecord --with-desktop-audio --with-microphone-audio" ;;
        *webcam) sh_run "dusky-screenrecord --with-desktop-audio --with-microphone-audio --with-webcam" ;;
      esac
    }

    # Reminders are transient systemd timers named reminder-<epoch-ns>, which is
    # the only reason "show all" and "clear all" can find them again —
    # systemd-run's default run-<hex> names are indistinguishable from any other
    # transient unit on the session bus.
    reminder_units() {
      systemctl --user list-units --all --no-legend --plain 'reminder-*.timer' 2>/dev/null | awk '{print $1}'
    }

    reminder_set() {
      mins=$(ask "Remind in minutes")
      case "$mins" in ""|*[!0-9]*) return ;; esac
      msg=$(ask "Reminder message")
      msg=''${msg:-Time is up}
      if systemd-run --user --unit="reminder-$(date +%s%N)" --description="$msg" \
           --on-active="''${mins}m" --timer-property=AccuracySec=1s \
           ${pkgs.libnotify}/bin/notify-send -u critical "󰔛  Reminder" "$msg" >/dev/null 2>&1; then
        notify-send "Reminder set" "in ''${mins}m — $msg" -t 3000
      else
        notify-send "Could not set reminder" -u critical -t 3000
      fi
    }

    reminder_show() {
      list=""
      for u in $(reminder_units); do
        when=$(systemctl --user show "$u" -p NextElapseUSecRealtime --value 2>/dev/null)
        what=$(systemctl --user show "''${u%.timer}.service" -p Description --value 2>/dev/null)
        list="''${list}󰔛  ''${what:-Reminder} — ''${when:-pending}
    "
      done
      [ -n "$list" ] || list="No reminders set"
      printf '%s\n' "$list" | pick "Reminders" >/dev/null
    }

    reminder_clear() {
      n=$(reminder_units | wc -l)
      for u in $(reminder_units); do
        systemctl --user stop "$u" "''${u%.timer}.service" >/dev/null 2>&1 || true
      done
      notify-send "Reminders cleared" "$n removed" -t 3000
    }

    reminder_menu() {
      case $(printf '%s\n' "󰔛  Set one" "󰔛  Show all" "󰔛  Clear all" | pick "Reminder") in
        *"Set one")   reminder_set ;;
        *"Show all")  reminder_show ;;
        *"Clear all") reminder_clear ;;
      esac
    }

    # LocalSend takes paths on argv (its .desktop is `localsend_app %U`) and
    # stages them for sending. The nixpkgs build has no headless CLI, so
    # Omarchy's `localsend --headless send` is not available here.
    send() { setsid uwsm-app -- localsend_app "$@" >/dev/null 2>&1 & }

    share_menu() {
      case $(printf '%s\n' "  Clipboard" "  File" "  Folder" | pick "Share") in
        *Clipboard*)
          if wl-paste --list-types 2>/dev/null | grep -q '^image/'; then
            f="$(mktemp).png"; wl-paste --type image/png > "$f" 2>/dev/null
          else
            f="$(mktemp).txt"; wl-paste > "$f" 2>/dev/null
          fi
          if [ -s "$f" ]; then send "$f"; else
            rm -f "$f"; notify-send "Clipboard is empty" -u critical -t 3000
          fi
          ;;
        # yazi writes the choice to a file and exits; the terminal is
        # foregrounded on purpose so we can read it back.
        *File*)
          out=$(mktemp)
          ${term} --class dusky-tui -e yazi --chooser-file="$out" >/dev/null 2>&1
          f=$(head -1 "$out" 2>/dev/null); rm -f "$out"
          [ -n "$f" ] && send "$f"
          ;;
        *Folder*)
          out=$(mktemp)
          ${term} --class dusky-tui -e yazi --cwd-file="$out" >/dev/null 2>&1
          f=$(head -1 "$out" 2>/dev/null); rm -f "$out"
          [ -n "$f" ] && send "$f"
          ;;
      esac
    }

    go() {
      case "''${1,,}" in
        apps)           run rofi -show drun -run-command "uwsm app -- {cmd}" ;;
        *screenshot*)   screenshot_menu ;;
        *screenrecord*) screenrecord_menu ;;
        *text*|*ocr*)   sh_run 'f=$(mktemp).png; slurp | grim -g - "$f" && ocr -p "$f" | wl-copy; rm -f "$f"' ;;
        *qr*)           sh_run "dusky-qr" ;;
        *color*)        sh_run "pkill hyprpicker || hyprpicker -a" ;;
        *transcode*)    sh_run "dusky-transcode" ;;
        *share*|*localsend*) share_menu ;;${dockerCase}
        # Live must be matched before the cached entry — both contain "disk".
        *"disk usage (live"*) run ${term} --class dusky-tui -e dusky-disk --live ;;
        *disk*)         run ${term} --class dusky-tui -e dusky-disk ;;
        *wifi*)         sh_run "rfkill unblock wifi; ${tui "dusky-tui" "impala"}" ;;
        *bluetooth*)    run ${term} --class dusky-tui -e bluetui ;;
        *audio*)        run ${term} --class dusky-tui -e wiremix ;;
        *monitor*)      run ${term} --class dusky_monitor -e dusky-monitor ;;
        *power\ profile*|*battery*) run ${term} --class dusky_power -e dusky-power ;;
        *reminder*)     reminder_menu ;;
        *clipboard*)    sh_run 'pkill rofi; rofi -modi "clipboard:dusky-rofi-cliphist" -show clipboard' ;;
        *emoji*)        run dusky-rofi-emoji ;;
        *calc*)         run dusky-rofi-calculator ;;
        *theme*)        run dusky-rofi-theme ;;
        *wallpaper*)    run dusky-rofi-wallpaper ;;
        *keybind*)      run dusky-rofi-keybindings ;;
        *notification*) run dusky-rofi-mako ;;
        *setting*|*control*) sh_run "gdbus call --session --dest com.github.dusky.controlcenter --object-path /com/github/dusky/controlcenter --method org.freedesktop.Application.Activate '{}'" ;;
        *activity*|*btop*) run ${term} --class btop -e btop ;;
        *files*)        run ${term} --class dusky-tui -e yazi ;;
        *lock*)         sh_run "hyprlock --immediate" ;;
        *"power menu"*) run dusky-rofi-powermenu ;;
      esac
    }

    actions() {
      printf '%s\n' \
        "  Screenshot" \
        "  Screenrecord" \
        "󰴑  Text extraction (OCR)" \
        "󰐲  QR code scan" \
        "󰃉  Color picker" \
        "󰧸  Transcode image/video" \
        "󰛡  Share (LocalSend)" \
        "󰖩  Wifi" \
        "󰂯  Bluetooth" \
        "󰕾  Audio" \
        "󰍹  Monitors" \
        "󱐋  Power profile" \
        "󰔛  Reminder" \
        "  Clipboard history" \
        "  Emoji" \
        "  Calculator" \
        "󰸌  Theme" \
        "  Wallpaper" \
        "  Keybindings" \
        "󰎟  Notifications" \
        "  Settings" \
        "  Activity (btop)" \${dockerAction}
        "󰋊  Disk usage" \
        "󰋊  Disk usage (live scan)" \
        "  Files" \
        "  Lock" \
        "󰐥  Power menu"
    }

    # Called by dusky-menu-actions, the rofi script-mode half of the combi list.
    if [ "''${1:-}" = "--list" ]; then actions; exit 0; fi
    if [ $# -gt 0 ]; then go "$1"; exit 0; fi

    # Top level is rofi's combi: drun (real apps, with icons and rofi's own
    # ranking) merged with our actions, so one prompt searches both. There is
    # no separate "Apps" entry any more — the apps are just there.
    # A second SUPER+SPACE closes the menu instead of stacking another. Matched
    # narrowly on our own two rofi invocations — dusky drives its clipboard,
    # emoji and wallpaper pickers through rofi too, and those are not ours to
    # kill.
    if pgrep -f 'rofi -show combi' >/dev/null || pgrep -f 'rofi -dmenu -i -p' >/dev/null; then
      pkill -f 'rofi -show combi'; pkill -f 'rofi -dmenu -i -p'; exit 0
    fi
    exec rofi -show combi \
      -modes "combi,drun,actions:${menuActions}/bin/dusky-menu-actions" \
      -combi-modes "actions:${menuActions}/bin/dusky-menu-actions,drun" \
      -combi-hide-mode-prefix \
      -run-command "uwsm app -- {cmd}" \
      -p "Go"
  '';
in {
  options.programs.dusky-extras.enable =
    lib.mkEnableOption "Omarchy-style menu, screen recording, QR and transcode helpers";
  options.programs.dusky-extras.docker =
    lib.mkEnableOption "lazydocker (package, SUPER+CTRL+D, menu entry)";

  config = lib.mkIf cfg.enable {
    home.packages =
      [
        menu
        menuActions
        screenrecord
        qr
        transcode
        disk
        pkgs.dua
      ]
      ++ lib.optional cfg.docker pkgs.lazydocker
      ++ [
        # Omarchy's wifi/bluetooth/audio TUIs, verbatim.
        pkgs.impala
        pkgs.bluetui
        pkgs.wiremix
        # Used by the scripts above; also handy standalone.
        pkgs.localsend
        pkgs.zbar
        pkgs.hyprpicker
        pkgs.v4l-utils
        pkgs.ffmpeg-full # ffplay for the webcam bubble
        # ponytail: gpu-screen-recorder deliberately NOT here — it must come from
        # programs.gpu-screen-recorder.enable so the setcap wrapper is used.
      ];

    programs.hyprland-keybindings.extraConfig = ''

      -- configs/dusky-extras.nix ------------------------------------------------
      -- SUPER+SPACE becomes the Omarchy-style menu; "Apps" is its first entry,
      -- so the old rofi drun is one keystroke further in, not gone.
      hl.unbind("SUPER + SPACE")
      hl.bind("SUPER + SPACE",     hl.dsp.exec_cmd("dusky-menu"),                { description = "Menu" })
      hl.bind("SUPER + CTRL + R",  hl.dsp.exec_cmd("dusky-menu screenrecord"),   { description = "Screen record (start/stop)" })
      hl.bind("SUPER + CTRL + S",  hl.dsp.exec_cmd("uwsm-app -- localsend_app"), { description = "Share (LocalSend)" })
      hl.bind("SUPER + CTRL + Q",  hl.dsp.exec_cmd("dusky-qr"),                  { description = "Scan QR code on screen" })
      hl.bind("SUPER + CTRL + T",  hl.dsp.exec_cmd("dusky-transcode"),           { description = "Transcode image/video" })${dockerBind}
      hl.bind("SUPER + CTRL + U",  hl.dsp.exec_cmd("uwsm-app -- ${term} --class dusky-tui -e dusky-disk"), { description = "Disk usage (cached)" })

      -- Keybind cheat sheet. Upstream dusky only puts this on
      -- CTRL+SHIFT+code:61 (i.e. CTRL+SHIFT+/), which is easy to forget.
      -- SUPER+K is free for it: focus-up is also on SUPER+Up.
      hl.unbind("SUPER + K")
      hl.bind("SUPER + K", hl.dsp.exec_cmd("pkill rofi; dusky-rofi-keybindings"), { description = "Show Keybinds" })

      -- Upstream dusky binds these with `--notify`, which dusky-screenshot has
      -- never accepted (only --no-notify exists) — it exits "Unknown option"
      -- before capturing anything. Same flags minus the bogus one.
      hl.unbind("SUPER + S")
      hl.bind("SUPER + S",       hl.dsp.exec_cmd("dusky-screenshot --region --freeze"), { description = "Quick Screenshot" })
      hl.unbind("SUPER + ALT + S")
      hl.bind("SUPER + ALT + S", hl.dsp.exec_cmd("dusky-screenshot --region --freeze --annotate --tool arrow"), { description = "Screenshot and Annotation" })

      -- Webcam bubble: floats, pinned, bottom-right, not focusable so it never
      -- steals typing while it's being recorded.
      hl.window_rule({
          name  = "dusky-webcam-bubble",
          match = { title = "^dusky-webcam-bubble$" },
          float      = true,
          pin        = true,
          no_focus   = true,
          no_dim     = true,
          border_size = 0,
          move       = "(monitor_w-window_w-24) (monitor_h-window_h-60)",
      })

      -- Floating terminal for the wifi/bluetooth/audio TUIs.
      hl.window_rule({
          name  = "dusky-tui",
          match = { class = "^dusky-tui$" },
          float  = true,
          size   = "900 600",
          center = true,
      })
    '';
  };
}
