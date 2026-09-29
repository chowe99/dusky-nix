{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.fzf = {
    enable = true;
    enableZshIntegration = true; # Enables fzf key bindings and completion for zsh
  };
}
