{
  config,
  pkgs,
  lib,
  ...
}: {
  # Zathura config is a symlink managed by matugen post_hook
  # (zathurarc -> ~/.config/matugen/generated/zathura-colors)
  # Create the directory for the symlink
  home.activation.createZathuraDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p "$HOME/.config/zathura"
  '';

  # The app this config is for, unless the user already configures it.
  home.packages = lib.optional (!config.programs.zathura.enable) pkgs.zathura;
}
