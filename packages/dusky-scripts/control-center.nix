{ pkgs, dusky }:

# Python GTK control center app
let
  python = pkgs.python3.withPackages (ps: with ps; [
    pygobject3
    pycairo
    pyyaml
  ]);
  scriptDir = "${dusky}/user_scripts/dusky_system/control_center";
in
pkgs.stdenv.mkDerivation {
  pname = "dusky-control-center";
  version = "1.0.0";

  src = scriptDir;

  nativeBuildInputs = with pkgs; [ makeWrapper wrapGAppsHook4 gobject-introspection ];

  buildInputs = with pkgs; [
    gtk4
    libadwaita
    glib
  ];

  dontWrapGApps = true;

  installPhase = ''
    mkdir -p $out/bin $out/lib/dusky-control-center
    cp -r . $out/lib/dusky-control-center/

    makeWrapper ${python}/bin/python3 $out/bin/dusky-control-center \
      --add-flags "$out/lib/dusky-control-center/dusky_control_center.py" \
      "''${gappsWrapperArgs[@]}"
  '';
}
