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

    # Adaptive shim so upstream (Arch) Control Center / Quick Panal buttons work
    # on NixOS instead of erroring on missing $HOME/user_scripts paths:
    #   install <attr> [<name>]  → nix profile install nixpkgs#<attr> (imperative
    #                              user package; the nix analogue of `pacman -S`)
    #   service <unit> -- <cmd>  → run <cmd> if <unit> is declaratively present,
    #                              else explain a service must be enabled in config
    #                              (can't be imperatively installed on NixOS)
    #   na [<msg>]               → "managed declaratively / not applicable" note
    (pkgs.writeShellApplication { checkPhase = "";
      name = "dusky-nixos-ctl";
      runtimeInputs = with pkgs; [ nix libnotify systemd coreutils gnugrep ];
      text = ''
        note() { notify-send "$1" "''${2:-}" 2>/dev/null || true; printf '\n  %s\n  %s\n' "$1" "''${2:-}"; }
        action="''${1:-na}"; shift || true
        case "$action" in
          install)
            attr="''${1:-}"; disp="''${2:-$attr}"
            if command -v "$attr" >/dev/null 2>&1 || nix profile list 2>/dev/null | grep -q "nixpkgs#$attr"; then
              note "Already available" "$disp is already installed."
              exit 0
            fi
            note "Installing $disp" "nix profile install nixpkgs#$attr — (tip: add it to your config to make it declarative)"
            if nix --extra-experimental-features "nix-command flakes" profile install "nixpkgs#$attr"; then
              note "Installed" "$disp"
            else
              note "Install failed" "$disp — see output above."
            fi
            ;;
          service)
            unit="''${1:-}"; shift || true
            [ "''${1:-}" = "--" ] && shift || true
            if systemctl cat "$unit" >/dev/null 2>&1; then
              exec "$@"
            else
              note "Not enabled on NixOS" "A system service can't be installed imperatively here. Enable it declaratively (e.g. services.''${unit%.service}.enable = true) and rebuild."
            fi
            ;;
          *)
            note "Not applicable on NixOS" "''${1:-Managed declaratively by your Nix config, or Arch-only.}"
            ;;
        esac
      '';
    })
  ];
}
