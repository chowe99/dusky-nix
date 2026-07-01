{ pkgs, dusky }:

# Upstream dusky moved most control-center "settings" screens into a shared
# textual/rich TUI framework at user_scripts/dusky_tui. Leaf schema modules
# (hypr/visual/tui_appearance.py, services/tui_service_toggle.py, ...) are
# rendered by user_scripts/dusky_tui/python/main/main.py, which imports the
# framework as the top-level `python` package and searches ~/user_scripts for
# schemas. We package the dispatcher once (dusky-tui) and let control-center.nix
# rewrite each button's schema argument to its absolute store path.

let
  upstream = "${dusky}/user_scripts";

  # Copy the framework into the store and teach main.py to also find schemas
  # under the store user_scripts (the Arch model assumes ~/user_scripts).
  duskyTui = pkgs.stdenv.mkDerivation {
    name = "dusky-tui-framework";
    src = "${upstream}/dusky_tui";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r . $out/
      substituteInPlace $out/python/main/main.py \
        --replace 'Path("~/user_scripts").expanduser().resolve(),' \
                  'Path("~/user_scripts").expanduser().resolve(), Path("${upstream}").resolve(),'
    '';
  };

  pyTui = pkgs.python3.withPackages (ps: with ps; [ textual rich ]);
in
pkgs.symlinkJoin {
  name = "dusky-tui-scripts";
  paths = [
    # --- The shared TUI dispatcher ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-tui";
      runtimeInputs = [ pyTui ];
      text = ''
        export PYTHONPATH="${duskyTui}''${PYTHONPATH:+:$PYTHONPATH}"
        exec ${pyTui}/bin/python3 ${duskyTui}/python/main/main.py "$@"
      '';
    })

    # --- Standalone utilities the control center invokes directly ---
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-usb-sound";
      runtimeInputs = with pkgs; [ python3 wireplumber ];
      text = ''exec python3 ${upstream}/external/usb_sound_toggle.py "$@"'';
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-window-rules-gen";
      runtimeInputs = with pkgs; [ python3 hyprland ];
      text = ''exec python3 ${upstream}/hypr/rules/window_rules_generator.py "$@"'';
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-locale-tui";
      runtimeInputs = with pkgs; [ gawk gnused systemd ];
      text = builtins.readFile "${upstream}/locale/locale_tui.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-waybar-toggle-time";
      runtimeInputs = with pkgs; [ procps gnused ];
      text = builtins.readFile "${upstream}/waybar/toggle_time.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-wayclick-soundpacks";
      runtimeInputs = with pkgs; [ curl unzip coreutils ];
      text = builtins.readFile "${upstream}/wayclick/sounds/wayclick_soundpacks_download.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-wireguard-new";
      runtimeInputs = with pkgs; [ wireguard-tools systemd coreutils ];
      text = builtins.readFile "${upstream}/networking/dusky_wireguard_new.sh";
    })
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-wireguard-setup";
      runtimeInputs = with pkgs; [ wireguard-tools systemd coreutils ];
      text = builtins.readFile "${upstream}/networking/dusky_wireguard_setup.sh";
    })

    # The mako settings screen has a dedicated desktop-entry launcher, so it
    # needs its own binary (the control center reaches it via dusky-tui). It is
    # a dusky_tui schema, so run it through the framework dispatcher.
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-mako-tui";
      runtimeInputs = [ pyTui ];
      text = ''
        export PYTHONPATH="${duskyTui}''${PYTHONPATH:+:$PYTHONPATH}"
        exec ${pyTui}/bin/python3 ${duskyTui}/python/main/main.py \
          ${upstream}/mako_osd/mako_tui/tui_mako.py "$@"
      '';
    })
  ];
}
