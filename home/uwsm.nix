{ config, pkgs, lib, ... }:

{
  # UWSM general environment
  xdg.configFile."uwsm/env".text = ''
    #!/bin/sh
    # Universal Wayland Session Manager (UWSM) - General Environment

    # Dynamic UTF-8 fallback
    case "''${LANG:-}" in
        *[Uu][Tt][Ff]8* | *[Uu][Tt][Ff]-8*)
            ;;
        *)
            export LC_CTYPE="C.UTF-8"
            ;;
    esac

    # CPU Threads
    export OMP_NUM_THREADS=$(nproc)

    # Qt Configuration
    export QT_QPA_PLATFORM="wayland;xcb"
    export QT_QPA_PLATFORMTHEME=qt6ct
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
    export QT_AUTO_SCREEN_SCALE_FACTOR=1
    export QT_QUICK_CONTROLS_STYLE=Fusion

    # GTK Configuration
    export GDK_BACKEND="wayland,x11"

    # Java AWT fix for tiling WMs
    export _JAVA_AWT_WM_NONREPARENTING=1

    # Cursor
    export XCURSOR_THEME=Bibata-Modern-Classic
    export XCURSOR_SIZE=18

    # Default apps
    export TERMINAL=kitty
    export EDITOR=nvim
    export VISUAL=nvim

    # App flags
    export SDL_VIDEODRIVER=wayland
    export CLUTTER_BACKEND=wayland

    # Clipboard (ephemeral - resets on reboot)
    export CLIPHIST_DB_PATH="''${XDG_RUNTIME_DIR}/cliphist.db"

    # Virtualization
    export LIBVIRT_DEFAULT_URI='qemu:///system'
  '';

  # UWSM Hyprland-specific environment
  xdg.configFile."uwsm/env-hyprland".text = ''
    #!/bin/sh
    # UWSM - Hyprland Specifics

    export DESKTOP_SESSION=hyprland-uwsm
    export HYPRCURSOR_SIZE=18

    # PATH
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    # Terminal override for Hyprland
    export TERMINAL=xdg-terminal-exec
  '';
}
