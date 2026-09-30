{
  config,
  pkgs,
  lib,
  ...
}: {
  # Upstream dropped its static fastfetch config for a matugen template
  # (templates/fastfetch.jsonc, themed logo and colours). matugen writes it on
  # each theme change (see home/theming/matugen-config.toml); until the first
  # one, the link dangles and fastfetch falls back to its defaults.
  # mkDefault: a host's own programs.fastfetch.settings wins.
  xdg.configFile."fastfetch/config.jsonc".source =
    lib.mkDefault
    (config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/matugen/generated/fastfetch.jsonc");
}
