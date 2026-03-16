{ config, pkgs, lib, dusky, ... }:

{
  # Deploy btop config (upstream has truecolor=False; override to True for accurate matugen colors)
  xdg.configFile."btop/btop.conf".text = builtins.replaceStrings
    ["truecolor = False"]
    ["truecolor = True"]
    (builtins.readFile "${dusky}/.config/btop/btop.conf");

  # Theme dir for matugen-generated theme
  home.activation.createBtopThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/btop/themes"
  '';
}
