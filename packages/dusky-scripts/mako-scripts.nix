{ pkgs, dusky }:

let
  upstream = "${dusky}/user_scripts";

  osd-python = pkgs.python3.withPackages (ps: with ps; [
    pyudev
    evdev
  ]);
in
pkgs.symlinkJoin {
  name = "dusky-mako-scripts";
  paths = [
    # OSD Router shell script (volume/brightness/media OSD via mako)
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-osd-router";
      runtimeInputs = with pkgs; [ wireplumber brightnessctl playerctl libnotify coreutils util-linux ];
      text = builtins.readFile "${upstream}/mako_osd/osd_router.sh";
    })

    # OSD Router Python daemon (caps lock, num lock, keyboard backlight events)
    (pkgs.writeScriptBin "dusky-mako-osd-daemon" ''
      #!${osd-python}/bin/python3
      ${builtins.readFile "${upstream}/mako_osd/osd_router.py"}
    '')

    # Mako TUI (terminal-based config editor)
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-mako-tui";
      runtimeInputs = with pkgs; [ mako gawk coreutils ];
      text = builtins.readFile "${upstream}/mako_osd/mako_tui/tui_mako.sh";
    })
  ];
}
