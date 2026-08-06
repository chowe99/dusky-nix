{
  pkgs,
  dusky,
}:
# Python GTK quick-panel app (formerly "simple_sliders").
#
# Upstream rewrote the old single-file dusky_sliders_simple.py into a
# multi-file GTK3 application under dusky_system/quickpanal/:
#   dusky_quickpanal.py  — entrypoint (#!/usr/bin/env python3, tomllib + GTK3)
#   dusky_ui.py          — GTK widgets (imported as `from dusky_ui import ...`)
#   dusky_backend.py     — hardware/IPC helpers (`from dusky_backend import ...`)
#   config.toml          — sample config (NOT read from the store; see below)
#   service/ reload_quickpanal/ instructions/  — copied verbatim
#
# A single-file readFile wrapper no longer works: the entrypoint imports its
# siblings and they must resolve. We copy the whole directory into the store
# and run the entrypoint from there — Python puts the script's own directory on
# sys.path[0], so `import dusky_ui` / `import dusky_backend` resolve.
#
# config.toml is located at runtime via `Path(HOME)/.config/dusky/quickpanal/
# config.toml`; if missing the app writes an embedded DEFAULT_TOML_CONFIG there.
# The store copy is never consulted — but DEFAULT_TOML_CONFIG *is* (it's what
# gets written on first run), so the Arch `~/user_scripts/...` paths inside it
# must be patched here, same as control-center.nix does to dusky_config.toml.
#
# Upstream hard-requires Python 3.14.5+ (sys.version_info < (3,14,5) → exit),
# same regression as dusky_control_center.py — pin to python314.
#
# GTK stack (from gi.require_version across the modules):
#   Gtk 3.0, Gdk 3.0, Pango 1.0  + Gio / GLib / GLibUnix (glib typelibs).
# No cairo/GdkPixbuf imports and no libadwaita, so this is gtk3 + glib + pango.
let
  python = pkgs.python314.withPackages (ps:
    with ps; [
      pygobject3
      pycairo
    ]);

  # [pattern replacement] — same idea as control-center.nix's pathSubstitutions,
  # applied to the quick panel's .py files (its config lives inside the source as
  # DEFAULT_TOML_CONFIG, plus a handful of hardcoded f-strings).
  pathSubstitutions = [
    # Header power button
    ["{HOME}/user_scripts/wlogout/wlogout_scale.sh" "dusky-wlogout-scale"]

    # Toggles (DEFAULT_TOML_CONFIG)
    ["~/user_scripts/waybar/toggle_hypridle.sh" "dusky-toggle-hypridle"]
    ["~/user_scripts/hyprlock/lock.sh" "dusky-lock"]
    ["~/user_scripts/hypr/hypr_blur_opacity_shadow_toggle.sh" "dusky-blur-toggle"]
    ["~/user_scripts/rofi/rofi_mako.sh" "dusky-rofi-mako"]
    ["~/user_scripts/waybar/mako.sh" "dusky-waybar-mako"]
    # Wi-Fi: upstream pipes a TUI schema through dusky_tui's dispatcher in `foot`
    # (not packaged here). dusky-network is the same NetworkManager TUI, standalone.
    ["foot --app-id=dusky_tui python ~/user_scripts/dusky_tui/python/main/main.py ~/user_scripts/network_manager/tui_dusky_network.py" "kitty --class dusky_tui dusky-network"]

    # Status pollers — these go through fetch_json_output (direct exec, no shell)
    ["python3 {HOME}/user_scripts/waybar/weather.py" "dusky-waybar-weather"]
    ["{HOME}/user_scripts/waybar/mako.sh" "dusky-waybar-mako"]
    ["{HOME}/user_scripts/waybar/network/network_meter_calling.sh" "dusky-waybar-network-meter"]

    # No NixOS equivalent → informative no-op via the shim (see control-center.nix)
    ["kitty --class system_update.sh --hold sh -c '~/user_scripts/update_dusky/system_update.sh --all'" "dusky-nixos-ctl na 'Update declaratively: sudo nixos-rebuild switch --flake ~/nix-config'"]
    ["kitty --class update_dusky.sh --hold sh -c '~/user_scripts/update_dusky/update_dusky.sh'" "dusky-nixos-ctl na 'Update: nix flake update dusky-nix then rebuild'"]
    # TLP is not enabled on these hosts (powerManagement.cpuFreqGovernor instead)
    ["~/user_scripts/battery/tlp/tlp_mode_toggle.sh" "dusky-nixos-ctl na 'Power profiles are declarative: powerManagement.cpuFreqGovernor'"]
  ];

  # Single-quoted sed script — a literal ' in either side ends the quote and the
  # substitution silently no-ops. Escape both. (Same trap as control-center.nix.)
  shEsc = builtins.replaceStrings ["'"] ["'\\''"];
  sedCommands = builtins.concatStringsSep "\n" (
    builtins.map (
      pair: let
        pattern = shEsc (builtins.elemAt pair 0);
        replacement = shEsc (builtins.elemAt pair 1);
      in "sed -i 's|${pattern}|${replacement}|g' $out/lib/dusky-sliders/dusky_quickpanal.py"
    )
    pathSubstitutions
  );
in
  pkgs.stdenv.mkDerivation {
    pname = "dusky-slider-scripts";
    version = "1.0.0";

    src = "${dusky}/user_scripts/dusky_system/quickpanal";

    nativeBuildInputs = with pkgs; [makeWrapper wrapGAppsHook3 gobject-introspection];

    buildInputs = with pkgs; [
      gtk3
      glib
      pango
      gdk-pixbuf
    ];

    dontWrapGApps = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/lib/dusky-sliders
      cp -r . $out/lib/dusky-sliders/

      # nix-compat: upstream's 3.14.5 hard floor vs pkgs.python314 3.14.3 (see
      # control-center.nix). Relax to any 3.14.x so Quick Panal starts.
      sed -i 's/sys.version_info < (3, 14, 5)/sys.version_info < (3, 14, 0)/' \
        $out/lib/dusky-sliders/dusky_quickpanal.py

      # THE bug that made every Quick Panal button a no-op on NixOS: upstream
      # spawns commands via a literal /usr/bin/bash, which does not exist here
      # (/usr/bin holds only `env`). execute_cmd() swallows the resulting OSError
      # into LOG.warning, so clicks did nothing at all — silently.
      substituteInPlace $out/lib/dusky-sliders/dusky_backend.py \
        $out/lib/dusky-sliders/dusky_quickpanal.py \
        --replace-quiet '/usr/bin/bash' '${pkgs.bash}/bin/bash' \
        --replace-quiet '/usr/bin/rfkill' '${pkgs.util-linux}/bin/rfkill'

      # Arch `~/user_scripts/...` → packaged binaries. Two spellings reach here:
      # the `~/...` form inside DEFAULT_TOML_CONFIG (run through bash -c, which
      # expands ~) and the `{HOME}/...` form inside Python f-strings — several of
      # those go to fetch_json_output(), which shlex.splits and execs directly
      # (no shell, so no ~ expansion). Both collapse to a bare binary name.
      ${sedCommands}

      runHook postInstall
    '';

    postFixup = ''
      makeWrapper ${python}/bin/python3 $out/bin/dusky-sliders \
        --add-flags "$out/lib/dusky-sliders/dusky_quickpanal.py" \
        "''${gappsWrapperArgs[@]}" \
        --prefix GI_TYPELIB_PATH : "${pkgs.gobject-introspection}/lib/girepository-1.0"
    '';
  }
