{
  config,
  pkgs,
  lib,
  dusky,
  ...
}: {
  # Deploy btop config (upstream has truecolor = false; override to true for accurate matugen colors)
  xdg.configFile."btop/btop.conf".text =
    builtins.replaceStrings
    ["truecolor = false"]
    ["truecolor = true"]
    (builtins.readFile "${dusky}/.config/btop/btop.conf");

  # Theme dir for matugen-generated theme
  home.activation.createBtopThemes = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p "$HOME/.config/btop/themes"
  '';
}
