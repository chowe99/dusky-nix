{ config, pkgs, lib, dusky, ... }:

{
  # Deploy yazi configs
  xdg.configFile."yazi/yazi.toml".source = "${dusky}/.config/yazi/yazi.toml";
  xdg.configFile."yazi/keymap.toml".source = "${dusky}/.config/yazi/keymap.toml";
  # theme.toml is a symlink managed by matugen post_hook
}
