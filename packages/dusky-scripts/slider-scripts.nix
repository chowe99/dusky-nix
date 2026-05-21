{ pkgs, dusky }:

# Python GTK slider UIs
let
  python = pkgs.python3.withPackages (ps: with ps; [
    pygobject3
    pycairo
  ]);
in
pkgs.writeScriptBin "dusky-sliders" ''
  #!${python}/bin/python3
  ${builtins.readFile "${dusky}/user_scripts/dusky_system/quickpanal/simple_sliders/dusky_sliders_simple.py"}
''
