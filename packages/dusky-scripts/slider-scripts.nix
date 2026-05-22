{ pkgs, dusky }:

# Python GTK slider UIs.
# Upstream dusky_sliders_simple.py hard-requires Python 3.14.4+
# (sys.version_info < (3, 14, 4) → sys.exit), same regression as
# dusky_control_center.py — pin to python314.
let
  python = pkgs.python314.withPackages (ps: with ps; [
    pygobject3
    pycairo
  ]);
in
pkgs.writeScriptBin "dusky-sliders" ''
  #!${python}/bin/python3
  ${builtins.readFile "${dusky}/user_scripts/dusky_system/quickpanal/simple_sliders/dusky_sliders_simple.py"}
''
