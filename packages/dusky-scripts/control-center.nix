{ pkgs }:

# Python GTK control center app
let
  python = pkgs.python3.withPackages (ps: with ps; [
    pygobject3
    pycairo
  ]);
  scriptDir = ../../assets/scripts/control_center;
in
pkgs.stdenv.mkDerivation {
  pname = "dusky-control-center";
  version = "1.0.0";

  src = scriptDir;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/lib/dusky-control-center
    cp -r . $out/lib/dusky-control-center/

    makeWrapper ${python}/bin/python3 $out/bin/dusky-control-center \
      --add-flags "$out/lib/dusky-control-center/dusky_control_center.py" \
      --prefix GI_TYPELIB_PATH : "${pkgs.lib.makeSearchPath "lib/girepository-1.0" (with pkgs; [ gtk4 glib ])}"
  '';
}
