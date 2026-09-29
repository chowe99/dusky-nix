{
  config,
  pkgs,
  lib,
  dusky,
  ...
}: {
  # Deploy zed config
  xdg.configFile."zed" = {
    source = "${dusky}/.config/zed";
    recursive = true;
  };

  # Theme dir for matugen
  home.activation.createZedThemes = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p "$HOME/.config/zed/themes"
  '';

  # The app this config is for, unless the user already configures it.
  home.packages = lib.optional (!config.programs.zed-editor.enable) pkgs.zed-editor;
}
