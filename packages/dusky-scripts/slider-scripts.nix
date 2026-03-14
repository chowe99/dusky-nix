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
  ${builtins.readFile "${toString ../../assets/scripts/sliders}/dusky_sliders.py"}
''
