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
# So the store copy is never consulted and needs no patching.
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

      runHook postInstall
    '';

    postFixup = ''
      makeWrapper ${python}/bin/python3 $out/bin/dusky-sliders \
        --add-flags "$out/lib/dusky-sliders/dusky_quickpanal.py" \
        "''${gappsWrapperArgs[@]}" \
        --prefix GI_TYPELIB_PATH : "${pkgs.gobject-introspection}/lib/girepository-1.0"
    '';
  }
